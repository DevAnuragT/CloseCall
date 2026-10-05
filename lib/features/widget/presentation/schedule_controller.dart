import 'dart:async';
import 'dart:convert';
import 'package:closecall_client/closecall_client.dart' hide Uuid;
import 'package:closecall_shared/closecall_shared.dart' as shared;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../media/data/media_repository.dart';
import '../../media/data/photo_preparation.dart';
import '../../pairing/presentation/pairing_controller.dart';
import '../data/local_widget_writer.dart';
import '../data/schedule_repository.dart';
import '../data/widget_consent_store.dart';

Duration Function() _monotonicClock() {
  final stopwatch = Stopwatch()..start();
  return () => stopwatch.elapsed;
}

/// Immutable command, not a second copy of a generated backend DTO.
class PendingScheduleRequest {
  PendingScheduleRequest(
    this.assetId,
    DateTime from,
    DateTime until,
    this.requestId,
  ) : activeFrom = from.toUtc(),
      activeUntil = until.toUtc();
  final String assetId;
  final DateTime activeFrom;
  final DateTime activeUntil;
  final String requestId;
}

class _ClockAnchor {
  _ClockAnchor(this.serverTime, this.elapsedAtReceipt);
  final DateTime serverTime;
  final Duration elapsedAtReceipt;
  DateTime now(Duration elapsed) => serverTime.add(
    elapsed < elapsedAtReceipt ? Duration.zero : elapsed - elapsedAtReceipt,
  );
}

/// Streams and timers resolve only this identity's own recipient timeline.
/// Wall-clock/time-zone changes cannot shift an already received UTC timeline:
/// serverTime is anchored to monotonic elapsed time, not DateTime.now().
class ScheduleController extends ChangeNotifier {
  ScheduleController({
    required this.pairing,
    required this.repository,
    required this.mediaRepository,
    required this.localWriter,
    WidgetConsentStore? consentStore,
    DateTime Function()? now,
    Duration Function()? elapsed,
    String Function()? requestId,
  }) : consentStore = consentStore ?? MemoryWidgetConsentStore(),
       _now = now ?? DateTime.now,
       _elapsed = elapsed ?? _monotonicClock(),
       _requestId = requestId ?? const Uuid().v4 {
    pairing.addListener(_scopeChanged);
    pairing.session.addListener(_scopeChanged);
    _scopeChanged();
  }

  final PairingController pairing;
  final ScheduleRepository repository;
  final MediaRepository mediaRepository;
  final LocalWidgetWriter localWriter;
  final WidgetConsentStore consentStore;
  final DateTime Function() _now;
  final Duration Function() _elapsed;
  final String Function() _requestId;
  String? _scope;
  int _scopeVersion = 0;
  int _operationVersion = 0;
  int _syncVersion = 0;
  bool _disposed = false;
  bool foreground = true;
  bool autoSyncEnabled = false;
  bool get partnerUpdatesEnabled => autoSyncEnabled;
  bool partnerUpdatesBusy = false;
  Object? partnerUpdatesError;
  bool _deviceConsentManaged = false;
  int _consentVersion = 0;
  int _restoreScope = -1;
  String? _observedUser;
  bool _clearedSignedOutConsent = false;
  String? _validatedConsentScope;
  Future<void> _consentTail = Future.value();
  Future<void> _deliveryTail = Future.value();
  bool busy = false;
  bool syncing = false;
  Object? error;
  Object? streamError;
  Object? syncError;
  String? status;
  WidgetTimeline? ownTimeline;
  WidgetTimeline? partnerTimeline;
  WidgetTimeline? _nativeCachedTimeline;
  WidgetTimeline? _lastSyncedTimeline;
  String? _lastSyncedAsset;
  shared.WidgetResolution? ownResolution;
  shared.WidgetResolution? partnerResolution;
  PendingScheduleRequest? pendingCreate;
  _ClockAnchor? _ownClock;
  _ClockAnchor? _partnerClock;
  StreamSubscription<WidgetTimeline>? _subscription;
  Timer? _timer;
  Timer? _reconnectTimer;
  int _reconnectFailures = 0;
  bool _streamBlocked = false;
  final _cache = <String, Uint8List>{};
  String? _appliedAsset;
  bool _appliedEmpty = false;
  Future<void> Function()? _retry;
  Future<void>? _syncFuture;
  int _syncFlightVersion = -1;
  int _syncFlightTicket = 0;
  static const maxCachedAssets = 12;
  static const maxCachedSchedules = 100;
  static const nativeCacheTtl = Duration(hours: 24);
  bool _scopeInitialized = false;
  bool get backgroundCacheSupported => localWriter.timeline.supported;
  int get cachedAssetCount => _cache.length;
  Uint8List? get currentPhoto => _cache[ownCurrentAssetId];
  String? get ownCurrentAssetId => _asset(ownResolution);
  String? get partnerCurrentAssetId => _asset(partnerResolution);
  DateTime get serverNow => _ownClock?.now(_elapsed()) ?? _now().toUtc();
  bool get canSchedule =>
      !_disposed &&
      pairing.userId != null &&
      pairing.initialized &&
      pairing.hasLoadedPairing &&
      pairing.couple?.isComplete == true &&
      pairing.couple!.memberIds.contains(pairing.userId);
  String? get _currentScope => pairing.userId == null
      ? null
      : '${pairing.userId}:${pairing.authRevision}/${pairing.couple?.id ?? 'unpaired'}/'
            '${pairing.couple?.isComplete == true && pairing.hasLoadedPairing ? 'paired' : 'waiting'}';
  String? _asset(shared.WidgetResolution? result) =>
      result == null || result.assetId.isEmpty ? null : result.assetId;
  bool _current(int version) =>
      !_disposed && version == _scopeVersion && _scope == _currentScope;
  bool _operationCurrent(int scope, int operation) =>
      _current(scope) && operation == _operationVersion;
  bool _syncCurrent(int scope, int sync) =>
      _current(scope) &&
      sync == _syncVersion &&
      autoSyncEnabled &&
      (!_deviceConsentManaged || ownTimeline?.autoUpdateEnabled == true) &&
      foreground &&
      canSchedule;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _scopeChanged() {
    if (_disposed) return;
    _observeConsentIdentity();
    if (_scopeInitialized && _scope == _currentScope) {
      _maybeRestoreConsent();
      return;
    }
    _scopeInitialized = true;
    _scope = _currentScope;
    final scope = ++_scopeVersion;
    _operationVersion++;
    _syncVersion++;
    _consentVersion++;
    partnerUpdatesBusy = false;
    partnerUpdatesError = null;
    _deviceConsentManaged = false;
    _streamBlocked = false;
    _reconnectFailures = 0;
    _stopListening();
    autoSyncEnabled = false;
    busy = false;
    syncing = false;
    error = streamError = syncError = null;
    status = null;
    ownTimeline = partnerTimeline = null;
    _nativeCachedTimeline = null;
    _lastSyncedTimeline = null;
    _lastSyncedAsset = null;
    ownResolution = partnerResolution = null;
    _ownClock = _partnerClock = null;
    _cache.clear();
    _appliedAsset = null;
    _appliedEmpty = false;
    pendingCreate = null;
    _retry = null;
    unawaited(
      localWriter.setScope(_scope).catchError((Object failure) {
        if (_current(scope)) {
          syncError = failure;
          _notify();
        }
      }),
    );
    _notify();
    if (canSchedule && foreground) {
      _subscribe();
      unawaited(refresh());
    }
    _maybeRestoreConsent();
  }

  String? get _stableConsentScope =>
      canSchedule ? '${pairing.userId}/${pairing.couple!.id}' : null;

  // Do not erase persisted consent while secure startup is still signed out.
  // Once an identity was observed, sign-out/switch/re-pair invalidates it.
  void _observeConsentIdentity() {
    final user = pairing.userId;
    final stable = _stableConsentScope;
    final authRevision = pairing.authRevision;
    if (user != null) _clearedSignedOutConsent = false;
    final changedUser = _observedUser != null && _observedUser != user;
    final changedPair =
        _validatedConsentScope != null &&
        ((stable != null && stable != _validatedConsentScope) ||
            (pairing.initialized && pairing.hasLoadedPairing && !canSchedule));
    if (changedUser ||
        changedPair ||
        (user == null && pairing.initialized && !_clearedSignedOutConsent)) {
      _validatedConsentScope = null;
      _clearedSignedOutConsent = user == null;
      unawaited(
        _enqueueConsent(() => consentStore.write(null)).catchError((
          Object failure,
        ) {
          if (!_disposed &&
              pairing.userId == user &&
              pairing.authRevision == authRevision &&
              _stableConsentScope == stable) {
            partnerUpdatesError = failure;
            _notify();
          }
        }),
      );
    }
    _observedUser = user;
    if (stable != null) _validatedConsentScope = stable;
  }

  Future<T> _enqueueConsent<T>(Future<T> Function() operation) {
    final result = _consentTail.then((_) => operation());
    _consentTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  bool _consentCurrent(int scope, int version) =>
      _current(scope) && version == _consentVersion && canSchedule;

  Future<void> _persistConsent(bool enabled, int scope, int version) {
    final consent = canSchedule
        ? WidgetDeviceConsent(
            userId: pairing.userId!,
            coupleId: pairing.couple!.id,
            enabled: enabled,
          )
        : null;
    return _enqueueConsent(() async {
      // A requested pause must survive an immediate Flutter shutdown. Dispose
      // invalidates native work, not this already scoped durable preference.
      final disposedSameScope =
          _disposed && _scopeVersion == scope + 1 && _scope == _currentScope;
      if ((!_current(scope) && !disposedSameScope) ||
          version != _consentVersion) {
        return;
      }
      await consentStore.write(consent);
    });
  }

  DeliveryConsentRepository get _deliveryRepository {
    final repo = repository;
    if (repo is DeliveryConsentRepository) {
      return repo as DeliveryConsentRepository;
    }
    throw UnsupportedError('Partner delivery consent is unavailable.');
  }

  void _validateDelivery(WidgetDeliveryState state) {
    if (!canSchedule ||
        state.coupleId != pairing.couple!.id ||
        state.recipientId != pairing.userId) {
      throw StateError(
        'Delivery consent does not belong to this account and couple.',
      );
    }
  }

  void _maybeRestoreConsent() {
    if (!canSchedule || _restoreScope == _scopeVersion) return;
    _restoreScope = _scopeVersion;
    unawaited(_restoreConsent(_scopeVersion, _consentVersion));
  }

  Future<void> _restoreConsent(int scope, int version) async {
    try {
      final saved = await _enqueueConsent(consentStore.read);
      if (!_consentCurrent(scope, version) || saved == null) return;
      if (!saved.matches(pairing.userId!, pairing.couple!.id)) {
        await _persistConsent(false, scope, version);
        return;
      }
      _deviceConsentManaged = true;
      if (!saved.enabled) return;
      final remote = await _deliveryRepository.getDeliveryState();
      if (!_consentCurrent(scope, version)) return;
      _validateDelivery(remote);
      if (!remote.autoUpdateEnabled) {
        await _persistConsent(false, scope, version);
        return;
      }
      // Fetch fresh truth after validated restoration; never apply startup cache.
      final timeline = await repository.currentTimeline();
      if (!_consentCurrent(scope, version)) return;
      _accept(timeline, own: true);
      if (!ownTimeline!.autoUpdateEnabled) {
        await _persistConsent(false, scope, version);
        return;
      }
      await setAutoSync(true);
    } catch (failure) {
      if (_consentCurrent(scope, version)) {
        partnerUpdatesError = failure;
        _notify();
      }
    }
  }

  Future<WidgetDeliveryState?> _setRemoteConsent(bool enabled, int scope) {
    final result = _deliveryTail.then((_) async {
      if (!_current(scope) || !canSchedule) return null;
      return _deliveryRepository.setDeliveryConsent(enabled);
    });
    _deliveryTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  /// Explicit opt-in affects this account on the server and this device locally.
  /// Off always pauses the device immediately, even if server opt-out fails.
  Future<void> setPartnerUpdates(bool enabled) async {
    if (_disposed) return;
    final scope = _scopeVersion;
    final version = ++_consentVersion;
    partnerUpdatesBusy = true;
    partnerUpdatesError = null;
    _deviceConsentManaged = true;
    _notify();
    try {
      if (!enabled) {
        // Synchronously invalidates downloads before storage/network awaits.
        final pause = setAutoSync(false);
        final persist = _persistConsent(false, scope, version);
        final optOut = _setRemoteConsent(false, scope);
        // Start the opt-out regardless of storage/native failure; await all so
        // no delayed error escapes, and leave local pause in effect.
        final results = await Future.wait<Object?>([pause, persist, optOut]);
        if (!_current(scope) || version != _consentVersion) return;
        final state = results.last as WidgetDeliveryState?;
        if (state != null) _validateDelivery(state);
        if (syncError != null) throw syncError!;
        status =
            'Partner updates paused on this device; account delivery consent is off. The current photo is unchanged.';
        return;
      }
      if (!canSchedule) {
        throw StateError('Complete pairing before enabling partner updates.');
      }
      final state = await _setRemoteConsent(true, scope);
      if (!_consentCurrent(scope, version) || state == null) return;
      _validateDelivery(state);
      if (!state.autoUpdateEnabled) {
        throw StateError('Partner delivery consent was not enabled.');
      }
      await _persistConsent(true, scope, version);
      if (!_consentCurrent(scope, version)) return;
      final timeline = await repository.currentTimeline();
      if (!_consentCurrent(scope, version)) return;
      _accept(timeline, own: true);
      if (!ownTimeline!.autoUpdateEnabled) {
        await _persistConsent(false, scope, version);
        throw StateError(
          'Account delivery consent is off. Enable partner updates again to retry.',
        );
      }
      await setAutoSync(true);
    } catch (failure) {
      if (_current(scope) && version == _consentVersion) {
        partnerUpdatesError = failure;
        if (!enabled) {
          status =
              'Paused on this device. Account-level opt-out could not be confirmed; other opted-in devices may still update.';
        }
      }
    } finally {
      if (_current(scope) && version == _consentVersion) {
        partnerUpdatesBusy = false;
        _notify();
      }
    }
  }

  void _stopListening() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final old = _subscription;
    _subscription = null;
    if (old != null) unawaited(old.cancel().catchError((Object _) {}));
    _timer?.cancel();
    _timer = null;
  }

  void _subscribe() {
    if (_subscription != null ||
        !canSchedule ||
        !foreground ||
        _streamBlocked) {
      return;
    }
    final scope = _scopeVersion;
    try {
      _subscription = repository.watchTimeline().listen(
        (timeline) {
          if (!_current(scope) || !foreground) return;
          _reconnectFailures = 0;
          try {
            _accept(timeline, own: true);
          } catch (failure) {
            streamError = failure;
            _notify();
          }
        },
        onError: (Object failure) {
          if (_current(scope)) {
            _streamFailed(failure, scope);
          }
        },
        onDone: () {
          if (!_current(scope) || !foreground) return;
          _subscription = null;
          _streamFailed(StateError('Timeline stream disconnected.'), scope);
        },
      );
    } catch (failure) {
      _streamFailed(failure, scope);
    }
  }

  bool _privateFailure(Object failure) =>
      (failure is ServerpodClientHttpException &&
          (failure.statusCode == 401 || failure.statusCode == 403)) ||
      (failure is ScheduleFailure &&
          [
            'not_paired',
            'not_authenticated',
            'unauthorized',
            'asset_not_found',
          ].contains(failure.code));

  void _streamFailed(Object failure, int scope) {
    if (!_current(scope)) return;
    final old = _subscription;
    _subscription = null;
    if (old != null) unawaited(old.cancel().catchError((Object _) {}));
    streamError = failure;
    _streamBlocked = _privateFailure(failure);
    _scheduleReconnect();
    _notify();
  }

  void _scheduleReconnect() {
    if (_disposed ||
        !autoSyncEnabled ||
        !foreground ||
        !canSchedule ||
        _streamBlocked ||
        _reconnectTimer != null) {
      return;
    }
    final scope = _scopeVersion;
    final seconds = (1 << _reconnectFailures.clamp(0, 5)).clamp(1, 30);
    _reconnectFailures = (_reconnectFailures + 1).clamp(0, 5);
    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      _reconnectTimer = null;
      if (!_current(scope) || !autoSyncEnabled || !foreground) return;
      try {
        final timeline = await repository.currentTimeline();
        if (!_current(scope) || !autoSyncEnabled || !foreground) return;
        _accept(timeline, own: true);
        streamError = null;
        _subscribe();
      } catch (failure) {
        _streamFailed(failure, scope);
      }
    });
  }

  void setForeground(bool value) {
    if (_disposed || foreground == value) return;
    foreground = value;
    _syncVersion++;
    syncing = false;
    if (!value) {
      _stopListening();
    } else if (canSchedule) {
      _subscribe();
      resolveNow(sync: false);
      unawaited(_refresh(retryPrivate: false));
    }
    _notify();
  }

  Future<void> _run(
    Future<void> Function(int, int) action,
    Future<void> Function() retry,
  ) async {
    if (_disposed || busy) return;
    if (!canSchedule) {
      error = StateError('Complete pairing before scheduling.');
      _notify();
      return;
    }
    final scope = _scopeVersion;
    final operation = ++_operationVersion;
    busy = true;
    error = null;
    _retry = retry;
    _notify();
    try {
      await action(scope, operation);
      if (_current(scope) && operation == _operationVersion) _retry = null;
    } catch (failure) {
      if (_current(scope) && operation == _operationVersion) error = failure;
    } finally {
      if (_current(scope) && operation == _operationVersion) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> refresh() => _refresh(retryPrivate: true);

  Future<void> _refresh({required bool retryPrivate}) {
    if (_streamBlocked && !retryPrivate) return Future.value();
    return _run((scope, operation) async {
      if (streamError != null) _stopListening();
      _streamBlocked =
          false; // Only an explicit refresh/scope change retries auth.
      _subscribe();
      final timelines = await Future.wait([
        repository.currentTimeline(),
        repository.partnerTimeline(),
      ]);
      if (!_operationCurrent(scope, operation)) return;
      _accept(timelines[0], own: true);
      _accept(timelines[1], own: false);
      streamError = null;
    }, refresh);
  }

  void _accept(WidgetTimeline timeline, {required bool own}) {
    if (!canSchedule) return;
    // Generated wire models are mutable; retain a detached scope snapshot.
    timeline = timeline.copyWith(
      schedules: List.unmodifiable(
        timeline.schedules.map((entry) => entry.copyWith()),
      ),
    );
    final expected = own
        ? pairing.userId
        : pairing.couple!.partnerOf(pairing.userId!);
    if (timeline.coupleId != pairing.couple!.id ||
        timeline.recipientId != expected ||
        timeline.schedules.any(
          (s) =>
              s.recipientId != expected ||
              !pairing.couple!.memberIds.contains(s.senderId),
        )) {
      throw StateError(
        'Timeline does not belong to this current couple and recipient.',
      );
    }
    final previous = own ? ownTimeline : partnerTimeline;
    if (previous != null &&
        (timeline.serverTime.toUtc().isBefore(previous.serverTime.toUtc()) ||
            timeline.deliveryVersion < previous.deliveryVersion ||
            (timeline.deliveryVersion == previous.deliveryVersion &&
                timeline.latestAssetId != previous.latestAssetId))) {
      return;
    }
    // Consent may change without incrementing deliveryVersion. Compare actual
    // content, not just version, while timestamps remain monotonic anchors.
    final unchanged = previous != null && _sameTimeline(previous, timeline);
    final previousClock = own ? _ownClock : _partnerClock;
    final received = timeline.serverTime.toUtc();
    final anchoredNow = previousClock?.now(_elapsed());
    // Equal-time duplicate events must not rewind elapsed foreground time.
    final anchor = _ClockAnchor(
      anchoredNow != null && anchoredNow.isAfter(received)
          ? anchoredNow
          : received,
      _elapsed(),
    );
    if (own) {
      ownTimeline = timeline;
      _ownClock = anchor;
      if (unchanged) {
        if (identical(_nativeCachedTimeline, previous)) {
          _nativeCachedTimeline = timeline;
        }
        if (identical(_lastSyncedTimeline, previous)) {
          _lastSyncedTimeline = timeline;
        }
      } else {
        _syncVersion++;
      }
      if (_deviceConsentManaged &&
          !timeline.autoUpdateEnabled &&
          autoSyncEnabled) {
        final scope = _scopeVersion;
        final version = ++_consentVersion;
        unawaited(setAutoSync(false));
        unawaited(
          _persistConsent(false, scope, version).catchError((Object failure) {
            if (_consentCurrent(scope, version)) {
              partnerUpdatesError = failure;
              _notify();
            }
          }),
        );
        status =
            'Account delivery consent is off. Partner updates are paused on this device.';
      }
      if (!unchanged && autoSyncEnabled) {
        final scope = _scopeVersion;
        final sync = _syncVersion;
        // Stop outdated alarms immediately, even if downloading replacement
        // photos fails. The visible photo is intentionally not cleared.
        unawaited(
          localWriter
              .disableTimeline(
                isCurrent: () => _current(scope) && autoSyncEnabled,
              )
              .catchError((Object failure) {
                if (_syncCurrent(scope, sync)) {
                  syncError = failure;
                  _notify();
                }
                return false;
              }),
        );
      }
    } else {
      partnerTimeline = timeline;
      _partnerClock = anchor;
    }
    resolveNow(sync: own);
  }

  bool _sameTimeline(WidgetTimeline a, WidgetTimeline b) {
    final left = a.toJson()..remove('serverTime');
    final right = b.toJson()..remove('serverTime');
    return jsonEncode(left) == jsonEncode(right);
  }

  String? _baseline(WidgetTimeline timeline) =>
      timeline.latestAssetId ?? timeline.fallbackAssetId;

  shared.WidgetResolution _resolve(WidgetTimeline timeline, DateTime now) =>
      shared.WidgetScheduleResolver.resolve(
        now: now,
        fallbackAssetId: _baseline(timeline) ?? '',
        schedules: timeline.schedules
            .map(
              (entry) => shared.WidgetSchedule(
                id: entry.scheduleId,
                assetId: entry.assetId,
                activeFrom: entry.activeFrom,
                activeUntil: entry.activeUntil,
                createdAt: entry.createdAt,
              ),
            )
            .toList(),
      );

  /// Also exposed for fake-clock tests; production calls it from the boundary timer.
  void resolveNow({bool sync = true}) {
    if (_disposed) return;
    final old = ownCurrentAssetId;
    if (ownTimeline != null) ownResolution = _resolve(ownTimeline!, serverNow);
    if (partnerTimeline != null) {
      partnerResolution = _resolve(
        partnerTimeline!,
        _partnerClock?.now(_elapsed()) ?? serverNow,
      );
    }
    if (old != ownCurrentAssetId) {
      _syncVersion++;
      _appliedEmpty = false;
    }
    _armTimer();
    _notify();
    if (sync && autoSyncEnabled && foreground) unawaited(syncNow());
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = null;
    if (!canSchedule || !foreground) return;
    Duration? next;
    void consider(WidgetTimeline? timeline, DateTime now) {
      if (timeline == null) return;
      for (final entry in timeline.schedules) {
        for (final time in [entry.activeFrom, entry.activeUntil]) {
          final difference = time.toUtc().difference(now);
          if (difference > Duration.zero &&
              (next == null || difference < next!)) {
            next = difference;
          }
        }
      }
    }

    consider(ownTimeline, serverNow);
    consider(partnerTimeline, _partnerClock?.now(_elapsed()) ?? serverNow);
    if (next != null) {
      final delay = next! > const Duration(minutes: 1)
          ? const Duration(minutes: 1)
          : next!;
      _timer = Timer(delay, resolveNow);
    }
  }

  Future<void> setAutoSync(bool enabled) async {
    if (_disposed) return;
    if (enabled && !canSchedule) {
      error = StateError('Complete pairing before enabling auto-sync.');
      _notify();
      return;
    }
    autoSyncEnabled = enabled;
    _syncVersion++;
    syncing = false;
    syncError = null;
    _appliedAsset = null;
    _appliedEmpty = false;
    status = enabled
        ? (backgroundCacheSupported
              ? 'Auto-sync enabled for this account and couple: foreground sync and cached Android transitions.'
              : 'Foreground auto-sync enabled. Background cache is unavailable on this platform.')
        : 'Auto-sync off. The current local photo is left unchanged.';
    _notify();
    if (!enabled) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      final scope = _scopeVersion;
      final sync = _syncVersion;
      try {
        await localWriter.disableTimeline(
          isCurrent: () => _current(scope) && sync == _syncVersion,
        );
      } catch (failure) {
        if (_current(scope) && sync == _syncVersion) {
          syncError = failure;
          _notify();
        }
        return;
      }
    }
    if (enabled && foreground) {
      _subscribe();
      if (streamError != null) _scheduleReconnect();
      if (ownTimeline == null) await refresh();
      await syncNow();
    }
  }

  Future<void> applyManualPhoto(Uint8List photo) async {
    if (_disposed) return;
    final scope = _scopeVersion;
    final consentVersion = ++_consentVersion;
    partnerUpdatesBusy = false;
    partnerUpdatesError = null;
    // Manual choice explicitly pauses auto-sync, preventing a later stream
    // event or already queued automatic write from overwriting that choice.
    final pause = setAutoSync(false);
    final persist = _persistConsent(false, scope, consentVersion);
    await Future.wait([pause, persist]);
    if (!_current(scope) ||
        consentVersion != _consentVersion ||
        autoSyncEnabled) {
      return;
    }
    if (syncError != null) throw syncError!;
    final sync = _syncVersion;
    await localWriter.write(
      photo,
      isCurrent: () =>
          _current(scope) &&
          consentVersion == _consentVersion &&
          sync == _syncVersion &&
          !autoSyncEnabled,
    );
  }

  Future<void> syncNow() {
    if (!autoSyncEnabled ||
        !foreground ||
        ownTimeline == null ||
        !canSchedule ||
        _disposed) {
      return Future.value();
    }
    final resolved = _resolve(ownTimeline!, serverNow);
    if (_asset(resolved) != ownCurrentAssetId) {
      ownResolution = resolved;
      _syncVersion++;
      _armTimer();
    }
    if (_syncFlightVersion == _syncVersion && _syncFuture != null) {
      return _syncFuture!;
    }
    if (identical(_lastSyncedTimeline, ownTimeline) &&
        _lastSyncedAsset == ownCurrentAssetId &&
        (ownCurrentAssetId == null
            ? _appliedEmpty
            : _appliedAsset == ownCurrentAssetId)) {
      return Future.value();
    }
    final ticket = ++_syncFlightTicket;
    _syncFlightVersion = _syncVersion;
    final future = _syncOnce();
    _syncFuture = future;
    unawaited(
      future.whenComplete(() {
        if (_syncFlightTicket == ticket) _syncFuture = null;
      }),
    );
    return future;
  }

  Future<void> _syncOnce() async {
    final scope = _scopeVersion;
    final sync = _syncVersion;
    final timeline = ownTimeline!;
    final currentAsset = ownCurrentAssetId;
    syncing = true;
    syncError = null;
    _notify();
    try {
      if (currentAsset == null) {
        if (!_appliedEmpty) {
          final applied = await localWriter.clear(
            isCurrent: () => _syncCurrent(scope, sync),
          );
          if (!_syncCurrent(scope, sync)) return;
          _appliedEmpty = applied;
          _appliedAsset = null;
        }
      } else {
        final photo = await _download(currentAsset, scope, sync);
        if (!_syncCurrent(scope, sync) || photo == null) return;
        if (_appliedAsset != currentAsset) {
          final applied = await localWriter.write(
            photo,
            isCurrent: () =>
                _syncCurrent(scope, sync) &&
                _asset(_resolve(ownTimeline!, serverNow)) == currentAsset,
          );
          if (!_syncCurrent(scope, sync)) return;
          if (applied) {
            _appliedAsset = currentAsset;
            _appliedEmpty = false;
          } else {
            resolveNow();
            return;
          }
        }
      }
      // Only own recipient truth is cached. The native TTL is measured from
      // this exact server-adjusted epoch anchor, not the device wall clock.
      final cacheNow = serverNow;
      final horizon = cacheNow.add(nativeCacheTtl);
      final upcoming =
          timeline.schedules
              .where(
                (s) =>
                    s.activeUntil.toUtc().isAfter(cacheNow) &&
                    s.activeFrom.toUtc().isBefore(horizon),
              )
              .toList()
            ..sort((a, b) => a.activeFrom.compareTo(b.activeFrom));
      final needed = <String>{
        ?currentAsset,
        if (_baseline(timeline)?.isNotEmpty == true) _baseline(timeline)!,
        ...upcoming.map((s) => s.assetId),
      };
      final ids = needed.take(maxCachedAssets).toList();
      _cache.removeWhere((key, _) => !ids.contains(key));
      for (final id in ids) {
        if (!_syncCurrent(scope, sync)) return;
        await _download(id, scope, sync);
      }
      if (_syncCurrent(scope, sync)) {
        if (backgroundCacheSupported) {
          final publicationNow = serverNow;
          final publicationHorizon = publicationNow.add(nativeCacheTtl);
          final cachedSchedules = timeline.schedules
              .where(
                (s) =>
                    s.activeUntil.toUtc().isAfter(publicationNow) &&
                    s.activeFrom.toUtc().isBefore(publicationHorizon),
              )
              .toList();
          final requiredPhotos = <String>{
            ?ownCurrentAssetId,
            if (_baseline(timeline)?.isNotEmpty == true) _baseline(timeline)!,
            ...cachedSchedules.map((s) => s.assetId),
          };
          // Never truncate competing windows into incorrect cached truth. If
          // the complete 24h horizon cannot fit, keep foreground-only sync.
          if (requiredPhotos.length > maxCachedAssets ||
              cachedSchedules.length > maxCachedSchedules ||
              !requiredPhotos.every(_cache.containsKey)) {
            await localWriter.disableTimeline(
              isCurrent: () => _syncCurrent(scope, sync),
            );
            if (!_syncCurrent(scope, sync)) return;
            status =
                'Foreground sync only: the next 24h timeline exceeds the Android cache bounds (12 photos / 100 schedules).';
          } else {
            final applied = await localWriter.cacheTimeline(
              {
                'scope': _scope!,
                'serverTimeMs': publicationNow.millisecondsSinceEpoch,
                'fallbackAssetId': _baseline(timeline),
                'schedules': [
                  for (final entry in cachedSchedules)
                    {
                      'scheduleId': entry.scheduleId,
                      'assetId': entry.assetId,
                      'activeFromMs': entry.activeFrom.millisecondsSinceEpoch,
                      'activeUntilMs': entry.activeUntil.millisecondsSinceEpoch,
                      'createdAtMs': entry.createdAt.millisecondsSinceEpoch,
                      'createdAtUs': entry.createdAt.microsecondsSinceEpoch,
                    },
                ],
                'photos': {for (final id in requiredPhotos) id: _cache[id]!},
              },
              serverNow: () => serverNow,
              isCurrent: () {
                if (!_syncCurrent(scope, sync)) return false;
                final now = serverNow;
                return _asset(_resolve(timeline, now)) == currentAsset &&
                    timeline.schedules
                        .where(
                          (entry) =>
                              entry.activeUntil.toUtc().isAfter(now) &&
                              entry.activeFrom.toUtc().isBefore(
                                now.add(nativeCacheTtl),
                              ),
                        )
                        .every(
                          (entry) => cachedSchedules.any(
                            (cached) => cached.scheduleId == entry.scheduleId,
                          ),
                        );
              },
            );
            if (!_syncCurrent(scope, sync)) return;
            if (applied) {
              _nativeCachedTimeline = ownTimeline;
              status =
                  'Own Android timeline cached for up to 24h. OS may delay transitions; reconnect for new, changed or cancelled schedules.';
            }
          }
        } else {
          status =
              'Own timeline applied locally while the app is open. Background cache is unavailable on this platform.';
        }
        if (_syncCurrent(scope, sync)) {
          _lastSyncedTimeline = ownTimeline;
          _lastSyncedAsset = currentAsset;
        }
      }
    } catch (failure) {
      if (_syncCurrent(scope, sync)) syncError = failure;
    } finally {
      if (_syncCurrent(scope, sync)) {
        syncing = false;
        _notify();
      }
    }
  }

  Future<Uint8List?> _download(String assetId, int scope, int sync) async {
    final cached = _cache[assetId];
    if (cached != null) return cached;
    final photo = await mediaRepository.downloadPhoto(assetId);
    if (!_syncCurrent(scope, sync)) return null;
    validateUploadPng(photo);
    if (_cache.length >= maxCachedAssets) _cache.remove(_cache.keys.first);
    return _cache[assetId] = Uint8List.fromList(photo);
  }

  Future<void> createPartnerSchedule(
    String assetId,
    DateTime from,
    DateTime until,
  ) async {
    if (_disposed || busy) return;
    if (!canSchedule) {
      error = StateError('Complete pairing before scheduling.');
      _notify();
      return;
    }
    if (pendingCreate != null) {
      error = StateError('Retry or discard the pending schedule first.');
      _notify();
      return;
    }
    if (assetId.isEmpty ||
        !until.toUtc().isAfter(from.toUtc()) ||
        !until.toUtc().isAfter(serverNow)) {
      error = const FormatException(
        'Choose an uploaded photo and an end after both start and current server time.',
      );
      _notify();
      return;
    }
    pendingCreate = PendingScheduleRequest(assetId, from, until, _requestId());
    await retryCreate();
  }

  Future<void> retryCreate() => _run((scope, operation) async {
    final request = pendingCreate;
    if (request == null) return;
    final result = await repository.createSchedule(
      request.assetId,
      request.activeFrom,
      request.activeUntil,
      request.requestId,
    );
    if (!_operationCurrent(scope, operation)) return;
    if (result.senderId != pairing.userId ||
        result.recipientId != pairing.couple!.partnerOf(pairing.userId!)) {
      throw StateError(
        'Created schedule has an unexpected sender or recipient.',
      );
    }
    pendingCreate = null;
    status =
        'Scheduled for your partner. Their device needs its own auto-sync opt-in and reconnect to receive changes.';
    final timeline = await repository.partnerTimeline();
    if (_operationCurrent(scope, operation)) _accept(timeline, own: false);
  }, () => pendingCreate == null ? refresh() : retryCreate());

  Future<void> setOwnFallback(String assetId) => _run((scope, operation) async {
    final timeline = await repository.setFallback(assetId);
    if (!_operationCurrent(scope, operation)) return;
    _accept(timeline, own: true);
    status =
        'Saved your own fallback. Local changes require auto-sync and reconnect.';
  }, () => setOwnFallback(assetId));

  bool canCancel(WidgetScheduleEntry entry) =>
      canSchedule &&
      (entry.senderId == pairing.userId ||
          entry.recipientId == pairing.userId) &&
      [
        ...?ownTimeline?.schedules,
        ...?partnerTimeline?.schedules,
      ].any((s) => s.scheduleId == entry.scheduleId);
  Future<void> cancelSchedule(WidgetScheduleEntry entry) =>
      _run((scope, operation) async {
        if (!canCancel(entry)) {
          throw StateError('This account cannot cancel that schedule.');
        }
        await repository.cancelSchedule(entry.scheduleId);
        if (!_operationCurrent(scope, operation)) return;
        final timelines = await Future.wait([
          repository.currentTimeline(),
          repository.partnerTimeline(),
        ]);
        if (!_operationCurrent(scope, operation)) return;
        _accept(timelines[0], own: true);
        _accept(timelines[1], own: false);
        status = 'Schedule cancelled. Foreground timelines refreshed.';
      }, () => cancelSchedule(entry));

  Future<void> retry() async {
    final action = _retry;
    if (action != null) await action();
  }

  void discardPendingCreate() {
    if (_disposed) return;
    _operationVersion++;
    busy = false;
    pendingCreate = null;
    _retry = null;
    error = null;
    status =
        'Stopped waiting. A submitted schedule may still exist on the server; refresh to check.';
    _notify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    // A validated opted-in native cache survives Flutter shutdown. Identity
    // changes clear through the writer queue; native TTL bounds offline life.
    final leaveCached =
        autoSyncEnabled &&
        canSchedule &&
        _scope == _currentScope &&
        identical(_nativeCachedTimeline, ownTimeline);
    _disposed = true;
    _scopeVersion++;
    _syncVersion++;
    _operationVersion++;
    _stopListening();
    _cache.clear();
    ownTimeline = partnerTimeline = null;
    ownResolution = partnerResolution = null;
    pendingCreate = null;
    pairing.removeListener(_scopeChanged);
    pairing.session.removeListener(_scopeChanged);
    localWriter.dispose(disable: !leaveCached);
    super.dispose();
  }
}
