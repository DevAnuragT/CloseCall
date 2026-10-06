import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/pairing/presentation/pairing_controller.dart';
import 'notification_permission_service.dart';

/// Read-only readiness checks never request permission or grant widget consent.
/// The only OS prompts are the explicit requestNotifications/addWidget actions.
class WidgetReadinessController extends ChangeNotifier {
  WidgetReadinessController({
    required this.service,
    PermissionPromptStore? promptStore,
  }) : promptStore = promptStore ?? MemoryPermissionPromptStore();

  final WidgetPermissionService service;
  final PermissionPromptStore promptStore;

  NotificationAccess _notificationAccess = NotificationAccess.unknown;
  bool _widgetInstalled = false;
  bool _pinSupported = false;
  bool _initialised = false;
  bool _started = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _handled = false;
  bool _promptKnown = false;
  Object? _error;
  int _pending = 0;
  int _scopeRevision = 0;
  PairingController? _pairing;
  String? _userId;
  int? _authRevision;
  String? _completeCoupleId;
  Future<void> _tail = Future<void>.value();
  Future<void>? _refreshFlight;
  int? _refreshRevision;
  Future<void>? _requestFlight;

  NotificationAccess get notificationAccess => _notificationAccess;
  bool get widgetInstalled => _widgetInstalled;
  bool get pinSupported => _pinSupported;
  bool get busy => _pending != 0;
  bool get initialised => _initialised;
  Object? get error => _error;
  bool get notificationPromptHandled => _handled;

  /// Explicit Settings action may retry a denial; automatic onboarding may
  /// not, because it is gated separately by [shouldPrompt].
  bool get canRequestNotifications =>
      _notificationAccess == NotificationAccess.denied;

  bool get shouldPrompt =>
      !_disposed &&
      _foreground &&
      _initialised &&
      !busy &&
      _promptKnown &&
      !_handled &&
      (_notificationAccess == NotificationAccess.denied ||
          _notificationAccess == NotificationAccess.permanentlyDenied);

  bool _current(int revision) => !_disposed && revision == _scopeRevision;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // All plugin calls share a queue. A resume during an OS dialog queues a fresh
  // read behind the request, instead of overlapping it or losing its result.
  Future<void> _enqueue(Future<void> Function(int revision) action) {
    if (_disposed) return Future<void>.value();
    final revision = _scopeRevision;
    _pending++;
    final operation = _tail.then((_) async {
      try {
        if (!_current(revision)) return;
        _error = null;
        await action(revision);
      } catch (_) {
        if (_current(revision)) {
          // Platform/transport exception text may contain native paths or IDs.
          _error = 'Could not update device readiness. Please try again.';
        }
      } finally {
        _pending--;
        _notify();
      }
    });
    _tail = operation;
    _notify();
    return operation;
  }

  Future<void> initialize() {
    if (_disposed) return Future<void>.value();
    if (_started) return _refreshFlight ?? Future<void>.value();
    _started = true;
    return refresh();
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh({bool force = false}) {
    if (_disposed) return Future<void>.value();
    if (!force &&
        _refreshFlight != null &&
        _refreshRevision == _scopeRevision) {
      return _refreshFlight!;
    }
    _started = true;
    _refreshRevision = _scopeRevision;
    late final Future<void> flight;
    flight = _enqueue(_read).whenComplete(() {
      if (identical(_refreshFlight, flight)) _refreshFlight = null;
    });
    _refreshFlight = flight;
    return flight;
  }

  Future<void> _read(int revision, {bool notifications = true}) async {
    bool failed = false;
    try {
      final handled = await promptStore.wasHandled();
      if (!_current(revision)) return;
      // A handled prompt cannot become unhandled during this controller's life.
      _handled |= handled;
      _promptKnown = true;
    } catch (_) {
      if (!_current(revision)) return;
      _promptKnown = false;
      failed = true;
    }
    if (notifications) {
      try {
        final access = await service.notificationStatus();
        if (!_current(revision)) return;
        _notificationAccess = access;
      } catch (_) {
        if (!_current(revision)) return;
        _notificationAccess = NotificationAccess.unknown;
        failed = true;
      }
    }
    // Only a verified, loaded pair for the current identity can show badges.
    // Pending/unresolved sessions deliberately leave both widget values false.
    if (_completeCoupleId != null) {
      try {
        final installed = await service.hasInstalledWidget();
        if (!_current(revision)) return;
        _widgetInstalled = installed;
      } catch (_) {
        if (!_current(revision)) return;
        _widgetInstalled = false;
        failed = true;
      }
      try {
        final supported = await service.canPinWidget();
        if (!_current(revision)) return;
        _pinSupported = supported;
      } catch (_) {
        if (!_current(revision)) return;
        _pinSupported = false;
        failed = true;
      }
    }
    if (!_current(revision)) return;
    _initialised = true;
    _error = failed
        ? 'Could not check device readiness. Please try again.'
        : null;
  }

  Future<void> requestNotifications() {
    if (_disposed) return Future<void>.value();
    if (_requestFlight != null) return _requestFlight!;
    late final Future<void> flight;
    flight =
        _enqueue((revision) async {
          // Persist before opening the OS dialog, including denial or process exit.
          // If persistence fails, do not open a prompt that could recur next launch.
          await promptStore.markHandled();
          _handled = true;
          _promptKnown = true;
          if (!_current(revision)) return;
          final access = await service.requestNotifications();
          if (!_current(revision)) return;
          _notificationAccess = access;
          await _read(revision, notifications: false);
        }).whenComplete(() {
          if (identical(_requestFlight, flight)) _requestFlight = null;
        });
    _requestFlight = flight;
    return flight;
  }

  Future<void> deferPrompt() => _enqueue((revision) async {
    await promptStore.markHandled();
    _handled = true;
    _promptKnown = true;
  });

  Future<void> openSettings() => _enqueue((revision) async {
    if (!await service.openSettings() && _current(revision)) {
      _error = 'Could not open app settings. Please try again.';
    }
    // Opening settings is not evidence that a permission was granted.
    // The lifecycle resume performs the read when the user returns.
  });

  Future<void> addWidget() => _enqueue((revision) async {
    if (_completeCoupleId == null) return;
    final supported = await service.canPinWidget();
    if (!_current(revision)) return;
    _pinSupported = supported;
    if (!supported) return;
    await service.requestPinWidget();
    if (!_current(revision)) return;
    // A pin request is not proof of installation (the launcher can cancel it).
    await _read(revision);
  });

  void bindPairing(PairingController? pairing) {
    if (_disposed || identical(pairing, _pairing)) return;
    _pairing?.removeListener(_pairingChanged);
    _pairing = pairing;
    _pairing?.addListener(_pairingChanged);
    _scopeRevision++;
    _userId = null;
    _authRevision = null;
    _completeCoupleId = null;
    _widgetInstalled = false;
    _pinSupported = false;
    _notificationAccess = NotificationAccess.unknown;
    _pairingChanged(binding: true);
  }

  void _pairingChanged({bool binding = false}) {
    if (_disposed) return;
    final pairing = _pairing;
    final user = pairing?.userId;
    final authRevision = pairing?.authRevision;
    final couple = pairing?.couple;
    final complete =
        pairing?.initialized == true &&
        pairing?.hasLoadedPairing == true &&
        user != null &&
        user.isNotEmpty &&
        couple != null &&
        couple.id.isNotEmpty &&
        couple.isComplete &&
        couple.memberIds.toSet().length == 2 &&
        couple.memberIds.every((member) => member.isNotEmpty) &&
        couple.memberIds.contains(user);
    final coupleId = complete ? couple.id : null;
    final identityChanged = user != _userId || authRevision != _authRevision;
    if (!binding && !identityChanged && coupleId == _completeCoupleId) return;
    _userId = user;
    _authRevision = authRevision;
    _completeCoupleId = coupleId;
    _scopeRevision++;
    _widgetInstalled = false;
    _pinSupported = false;
    if (identityChanged) _notificationAccess = NotificationAccess.unknown;
    _notify();
    if (_started && (binding || identityChanged || coupleId != null)) {
      unawaited(refresh());
    }
  }

  void setForeground(bool value) {
    if (_disposed || value == _foreground) return;
    _foreground = value;
    _notify();
    if (value && _started) unawaited(_refresh(force: true));
  }

  @override
  void dispose() {
    _disposed = true;
    _scopeRevision++;
    _pairing?.removeListener(_pairingChanged);
    _pairing = null;
    super.dispose();
  }
}
