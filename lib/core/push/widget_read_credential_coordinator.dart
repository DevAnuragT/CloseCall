import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/pairing/presentation/pairing_controller.dart';
import '../../features/widget/presentation/schedule_controller.dart';
import 'push_registration_service.dart';
import 'widget_read_credential.dart';
import 'widget_read_credential_api.dart';
import 'widget_read_credential_store.dart';

typedef _Scope = ({String user, String couple, int authRevision});
typedef _Observation = ({
  String? user,
  String? couple,
  int authRevision,
  bool eligible,
  bool pending,
});

/// Foreground lifecycle foundation only. No background download, user-session
/// refresh, or native photo application is performed by this coordinator.
class WidgetReadCredentialCoordinator {
  WidgetReadCredentialCoordinator({
    required this.pairing,
    required this.schedules,
    required this.api,
    required this.store,
    required this.deviceIdentity,
    bool? isAndroid,
    DateTime Function()? now,
    this.remoteTimeout = const Duration(seconds: 3),
  }) : _isAndroid =
           isAndroid ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
       _now = now ?? DateTime.now;

  final PairingController pairing;
  final ScheduleController schedules;
  final WidgetReadCredentialApi api;
  final WidgetReadCredentialStore store;
  final PushDeviceIdentityStore deviceIdentity;
  final Duration remoteTimeout;
  final bool _isAndroid;
  final DateTime Function() _now;

  Future<void> _tail = Future.value();
  Future<void>? _flight;
  bool _dirty = false;
  bool _started = false;
  bool _disposed = false;
  bool _validated = false;
  bool _storageUnavailable = false;
  int _generation = 0;
  int? _signingOutRevision;
  _Observation? _observed;
  String? _deviceId;
  WidgetReadCredential? _credential;
  _Scope? _remoteScope;
  // A timed-out request can still execute on the server. Never automatically
  // replay it, and never issue a newer credential while an old revoke can land.
  // Failed transport futures also remain uncertain: completion is not proof
  // that the server stopped processing their mutation.
  final _uncertainIssues = <(String, String)>{};
  final _pendingIssues = <(String, String)>{};
  final _pendingRevokes = <(String, String)>{};

  bool get hasCredential =>
      _credential?.validAt(_now().toUtc()) == true &&
      _eligible &&
      _credential!.userId == _scope?.user &&
      _credential!.coupleId == _scope?.couple;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    pairing.addListener(_changed);
    schedules.addListener(_changed);
    pairing.addBeforeSignOutHook(_beforeSignOut);
    _changed();
  }

  _Scope? get _scope {
    final user = pairing.userId;
    final couple = pairing.couple;
    if (!pairing.initialized ||
        !pairing.hasLoadedPairing ||
        user == null ||
        user.isEmpty ||
        couple?.isComplete != true ||
        couple!.id.isEmpty ||
        !couple.memberIds.contains(user)) {
      return null;
    }
    return (user: user, couple: couple.id, authRevision: pairing.authRevision);
  }

  bool get _eligible =>
      _isAndroid &&
      _signingOutRevision != pairing.authRevision &&
      _scope != null &&
      pairing.error == null &&
      schedules.canSchedule &&
      schedules.autoSyncEnabled &&
      schedules.ownTimeline?.autoUpdateEnabled == true &&
      schedules.ownTimeline?.recipientId == _scope!.user &&
      schedules.ownTimeline?.coupleId == _scope!.couple;

  // Preserve a restart's secure record while foreground auth/membership/consent
  // validation is unresolved. This grants no authority and performs no read.
  // Once a scope was validated, invalidation always clears the old record.
  bool get _startupPending =>
      !_validated &&
      _isAndroid &&
      _signingOutRevision != pairing.authRevision &&
      pairing.error == null &&
      ((!pairing.initialized ||
              (pairing.userId != null && !pairing.hasLoadedPairing)) ||
          (_scope != null &&
              (!schedules.partnerPhotoConsentRestored ||
                  schedules.restoringPartnerPhotoConsent)));

  void _observe() {
    final state = (
      user: pairing.userId,
      couple: pairing.couple?.id,
      authRevision: pairing.authRevision,
      eligible: _eligible,
      pending: _startupPending,
    );
    if (state == _observed) return;
    final old = _observed;
    final initialRestoration =
        !_validated && old?.user == null && old?.pending == true;
    _observed = state;
    _generation++;
    _credential = null;
    if (old != null &&
        ((old.user != null && old.user != state.user) ||
            (old.authRevision != state.authRevision && !initialRestoration) ||
            (_validated &&
                (old.couple != state.couple ||
                    (old.eligible && !state.eligible))))) {
      // Remember even a brief pause/scope boundary during an in-flight issue.
      // Coalescing notifications must not restore the pre-pause record.
      unawaited(_enqueue(_clear));
    }
  }

  void _changed() {
    if (!_started || _disposed) return;
    _observe(); // Invalidate before any async work can finish.
    unawaited(reconcile());
  }

  /// Notification storms coalesce, but changes during a flight remain dirty.
  /// Call on resume too, so wall-clock expiry is checked without a background
  /// timer or a background user-session refresh.
  Future<void> reconcile() {
    if (!_started || _disposed) return Future.value();
    _observe();
    _dirty = true;
    return _flight ??= _drain().whenComplete(() {
      _flight = null;
      if (_dirty && _started && !_disposed) unawaited(reconcile());
    });
  }

  Future<void> _drain() async {
    while (_dirty && _started && !_disposed) {
      _dirty = false;
      await _enqueue(_reconcileOnce);
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  bool _current(int generation, _Scope scope) =>
      _started &&
      !_disposed &&
      generation == _generation &&
      scope == _scope &&
      _eligible;

  Future<void> _clear() async {
    _credential = null;
    try {
      await store.delete();
    } catch (_) {
      // A failed secure dependency cannot authorize use or new issuance.
      _storageUnavailable = true;
    }
  }

  Future<void> _reconcileOnce() async {
    if (!_started || _disposed) return;
    if (!_eligible) {
      if (!_startupPending) await _clear();
      return;
    }
    _validated = true;
    final scope = _scope!;
    final generation = _generation;
    if (_storageUnavailable) return;
    try {
      _deviceId ??= await deviceIdentity.deviceId();
      if (!_current(generation, scope)) return;
      final device = _deviceId!;
      if (device.isEmpty || device.trim() != device || device.length > 256) {
        await _clear();
        _storageUnavailable = true;
        return;
      }
      final saved = await store.read();
      if (!_current(generation, scope)) return;
      final now = _now().toUtc();
      if (saved != null &&
          saved.matches(scope.user, scope.couple, device) &&
          saved.validAt(now) &&
          !saved.needsRenewal(now)) {
        _credential = saved;
        _remoteScope = scope;
        return;
      }
      await _clear();
      if (!_current(generation, scope) || _storageUnavailable) return;
      if (!schedules.foreground) return;
      final key = (scope.user, device);
      if (_uncertainIssues.contains(key) || _pendingRevokes.contains(key)) {
        return;
      }
      _remoteScope = scope;
      _pendingIssues.add(key);
      WidgetReadCredential issued;
      try {
        final request = api.issueCredential(deviceId: device);
        // These callbacks only release bookkeeping. They never write/revoke.
        unawaited(
          request.then<void>(
            (_) => _pendingIssues.remove(key),
            onError: (Object _, StackTrace _) {},
          ),
        );
        issued = await request.timeout(remoteTimeout);
      } catch (_) {
        _uncertainIssues.add(key);
        return;
      }
      if (!_current(generation, scope)) return;
      if (!issued.matches(scope.user, scope.couple, device) ||
          !issued.validAt(_now().toUtc()) ||
          issued.needsRenewal(_now().toUtc())) {
        _uncertainIssues.add(key);
        return;
      }
      // One queue orders reads/issues/writes/deletes. A write already in the
      // platform channel cannot be cancelled, so a stale completion is deleted
      // before any new scope's record can be read or written.
      await store.write(issued);
      if (!_current(generation, scope) || !issued.validAt(_now().toUtc())) {
        await _clear();
        return;
      }
      _credential = issued;
    } catch (_) {
      _storageUnavailable = true;
      await _clear();
    }
  }

  Future<void> _beforeSignOut() async {
    final scope = _remoteScope;
    final device = _deviceId;
    _signingOutRevision = pairing.authRevision;
    _generation++;
    _credential = null;
    _dirty = true;
    final cleanup = _enqueue(() async {
      // Local deletion is always first, even offline. No remote request is
      // allowed to delay it or run under a different authenticated revision.
      await _clear();
      if (scope == null ||
          device == null ||
          !_sameAuthenticatedScope(scope) ||
          _pendingIssues.contains((scope.user, device))) {
        return;
      }
      final key = (scope.user, device);
      _pendingRevokes.add(key);
      try {
        final request = api.revokeCredential(deviceId: device);
        unawaited(
          request.then<void>(
            (_) => _pendingRevokes.remove(key),
            onError: (Object _, StackTrace _) {},
          ),
        );
        await request.timeout(remoteTimeout);
      } catch (_) {
        // Keep an unfinished revoke fenced; it may still land on the server.
      }
    });
    try {
      // Also bounds a broken platform channel. The queued cleanup remains in
      // place, so a late write is still followed by deletion, never adoption.
      await cleanup.timeout(remoteTimeout * 2);
    } catch (_) {}
  }

  bool _sameAuthenticatedScope(_Scope scope) =>
      !_disposed &&
      pairing.userId == scope.user &&
      pairing.authRevision == scope.authRevision &&
      pairing.couple?.id == scope.couple;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    _generation++;
    _credential = null;
    pairing.removeListener(_changed);
    schedules.removeListener(_changed);
    pairing.removeBeforeSignOutHook(_beforeSignOut);
    // A settled, fresh record survives process restart. A write still in flight
    // is deleted by its post-write generation check.
  }
}
