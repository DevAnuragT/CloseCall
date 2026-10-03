import 'dart:async';
import 'package:closecall_client/closecall_client.dart' hide Uuid;
import 'package:closecall_shared/closecall_shared.dart' as shared;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../media/data/media_repository.dart';
import '../../media/data/photo_preparation.dart';
import '../../pairing/presentation/pairing_controller.dart';
import '../data/local_widget_writer.dart';
import '../data/schedule_repository.dart';

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
    DateTime Function()? now,
    Duration Function()? elapsed,
    String Function()? requestId,
  }) : _now = now ?? DateTime.now,
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
  bool busy = false;
  bool syncing = false;
  Object? error;
  Object? streamError;
  Object? syncError;
  String? status;
  WidgetTimeline? ownTimeline;
  WidgetTimeline? partnerTimeline;
  shared.WidgetResolution? ownResolution;
  shared.WidgetResolution? partnerResolution;
  PendingScheduleRequest? pendingCreate;
  _ClockAnchor? _ownClock;
  _ClockAnchor? _partnerClock;
  StreamSubscription<WidgetTimeline>? _subscription;
  Timer? _timer;
  final _cache = <String, Uint8List>{};
  String? _appliedAsset;
  bool _appliedEmpty = false;
  Future<void> Function()? _retry;
  Future<void>? _syncFuture;
  int _syncFlightVersion = -1;
  int _syncFlightTicket = 0;
  static const maxCachedAssets = 12;
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
      foreground &&
      canSchedule;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _scopeChanged() {
    if (_disposed || _scope == _currentScope) return;
    _scope = _currentScope;
    final scope = ++_scopeVersion;
    _operationVersion++;
    _syncVersion++;
    _stopListening();
    autoSyncEnabled = false;
    busy = false;
    syncing = false;
    error = streamError = syncError = null;
    status = null;
    ownTimeline = partnerTimeline = null;
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
  }

  void _stopListening() {
    final old = _subscription;
    _subscription = null;
    if (old != null) unawaited(old.cancel().catchError((Object _) {}));
    _timer?.cancel();
    _timer = null;
  }

  void _subscribe() {
    if (_subscription != null || !canSchedule || !foreground) return;
    final scope = _scopeVersion;
    try {
      _subscription = repository.watchTimeline().listen(
        (timeline) {
          if (!_current(scope) || !foreground) return;
          try {
            _accept(timeline, own: true);
          } catch (failure) {
            streamError = failure;
            _notify();
          }
        },
        onError: (Object failure) {
          if (_current(scope)) {
            streamError = failure;
            _notify();
          }
        },
        onDone: () {
          if (!_current(scope) || !foreground) return;
          _subscription = null;
          streamError = StateError(
            'Timeline stream disconnected. Refresh to reconnect.',
          );
          _notify();
        },
      );
    } catch (failure) {
      streamError = failure;
      _notify();
    }
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
      unawaited(refresh());
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

  Future<void> refresh() => _run((scope, operation) async {
    if (streamError != null) _stopListening();
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

  void _accept(WidgetTimeline timeline, {required bool own}) {
    if (!canSchedule) return;
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
        timeline.serverTime.toUtc().isBefore(previous.serverTime.toUtc())) {
      return;
    }
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
      _syncVersion++;
    } else {
      partnerTimeline = timeline;
      _partnerClock = anchor;
    }
    resolveNow(sync: own);
  }

  shared.WidgetResolution _resolve(WidgetTimeline timeline, DateTime now) =>
      shared.WidgetScheduleResolver.resolve(
        now: now,
        fallbackAssetId: timeline.fallbackAssetId ?? '',
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
        ? 'Foreground auto-sync enabled for this account and couple only.'
        : 'Auto-sync off. The current local photo is left unchanged.';
    _notify();
    if (enabled && foreground) {
      if (ownTimeline == null) await refresh();
      await syncNow();
    }
  }

  Future<void> applyManualPhoto(Uint8List photo) async {
    if (_disposed) return;
    final scope = _scopeVersion;
    // Manual choice explicitly pauses auto-sync, preventing a later stream
    // event or already queued automatic write from overwriting that choice.
    await setAutoSync(false);
    await localWriter.write(photo, isCurrent: () => _current(scope));
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
      // Bounded, authorized foreground prefetch: current + fallback + the next
      // ten distinct upcoming assets (at most 24 MiB of validated PNGs).
      final upcoming =
          timeline.schedules
              .where((s) => s.activeUntil.toUtc().isAfter(serverNow))
              .toList()
            ..sort((a, b) => a.activeFrom.compareTo(b.activeFrom));
      final ids = <String>{
        ?currentAsset,
        if (timeline.fallbackAssetId != null) timeline.fallbackAssetId!,
        ...upcoming.map((s) => s.assetId),
      }.take(maxCachedAssets).toList();
      _cache.removeWhere((key, _) => !ids.contains(key));
      for (final id in ids) {
        if (!_syncCurrent(scope, sync)) return;
        await _download(id, scope, sync);
      }
      if (_syncCurrent(scope, sync)) {
        status =
            'Own current timeline applied locally while the app is open. No background delivery.';
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
        'Scheduled for your partner. Their device needs its own foreground auto-sync opt-in.';
    final timeline = await repository.partnerTimeline();
    if (_operationCurrent(scope, operation)) _accept(timeline, own: false);
  }, () => pendingCreate == null ? refresh() : retryCreate());

  Future<void> setOwnFallback(String assetId) => _run((scope, operation) async {
    final timeline = await repository.setFallback(assetId);
    if (!_operationCurrent(scope, operation)) return;
    _accept(timeline, own: true);
    status =
        'Saved your own fallback. Local changes require foreground auto-sync.';
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
    final clearNative = autoSyncEnabled;
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
    localWriter.dispose(clear: clearNative);
    super.dispose();
  }
}
