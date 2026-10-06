import 'dart:typed_data';
import 'native_widget_timeline.dart';

/// One native-write queue shared by manual media/editor updates and auto-sync.
/// A started platform write cannot be cancelled; scope cleanup is queued after
/// it, before any new identity's writes. Queued stale writes never start.
class LocalWidgetWriter {
  LocalWidgetWriter({
    required this.applyPhoto,
    required this.clearPhoto,
    this.timeline = const ForegroundWidgetTimeline(),
  });
  final Future<void> Function(Uint8List) applyPhoto;
  final Future<void> Function() clearPhoto;
  final NativeWidgetTimeline timeline;
  Future<void> _tail = Future.value();
  String? _scope;
  int _revision = 0;
  bool _disposed = false;
  bool _scopeInitialized = false;
  bool _needsCleanup = true;
  bool _startupSuspended = false;
  bool get supportsRestoration =>
      timeline is ScopedWidgetRestoration && timeline.supported;

  /// Pause old alarms while secure auth and membership are unresolved. This
  /// does not authorize reuse or new writes; native code rejects unowned data.
  Future<void> suspendForStartup() {
    if (_disposed || _startupSuspended || !supportsRestoration) {
      return Future.value();
    }
    _startupSuspended = true;
    final result = _tail.then(
      (_) => (timeline as ScopedWidgetRestoration).suspendForStartup(),
    );
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<RestoredWidgetPhoto?> restoreValidatedScope(
    String scope, {
    required bool allowPartnerPhoto,
  }) {
    if (_disposed) return Future.value();
    if (_scopeInitialized || !supportsRestoration) {
      return setScope(scope).then((_) => null);
    }
    _scopeInitialized = true;
    _scope = scope;
    final revision = ++_revision;
    final result = _tail.then((_) async {
      if (_disposed || revision != _revision) return null;
      final restored = await (timeline as ScopedWidgetRestoration).restoreScope(
        scope,
        allowPartnerPhoto: allowPartnerPhoto,
      );
      if (_disposed || revision != _revision) return null;
      // The native operation has either verified ownership or cleared it.
      _needsCleanup = false;
      return restored;
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> setScope(String? scope) {
    if (_disposed || (_scopeInitialized && _scope == scope)) {
      return Future.value();
    }
    _scopeInitialized = true;
    _scope = scope;
    _revision++;
    _needsCleanup = true;
    // Also clear on first bootstrap: persisted cache may belong to an account
    // from a previous process, before Flutter knows the restored identity.
    return _enqueueClear();
  }

  Future<void> _enqueueClear() {
    final revision = _revision;
    final result = _tail.then((_) => _cleanup(revision));
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> _cleanup(int revision) async {
    await timeline.clearTimeline();
    await clearPhoto();
    if (revision == _revision) _needsCleanup = false;
  }

  Future<bool> write(
    Uint8List photo, {
    required bool Function() isCurrent,
    String? assetId,
  }) {
    final revision = _revision;
    final ownerScope = _scope;
    final copy = Uint8List.fromList(photo);
    final result = _tail.then((_) async {
      if (_disposed || revision != _revision || !isCurrent()) return false;
      if (_needsCleanup) await _cleanup(revision);
      if (_disposed || revision != _revision || !isCurrent()) return false;
      await applyPhoto(copy);
      if (supportsRestoration && ownerScope != null) {
        // Queue ordering ensures an explicit identity change clears this write
        // afterwards, even when the platform write had already started.
        await (timeline as ScopedWidgetRestoration).recordPhotoOwner(
          ownerScope,
          assetId: assetId,
        );
      }
      return !_disposed && revision == _revision && isCurrent();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> clear({required bool Function() isCurrent}) {
    final revision = _revision;
    final result = _tail.then((_) async {
      if (_disposed || revision != _revision || !isCurrent()) return false;
      if (_needsCleanup) await _cleanup(revision);
      if (_disposed || revision != _revision || !isCurrent()) return false;
      await clearPhoto();
      return !_disposed && revision == _revision && isCurrent();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> cacheTimeline(
    Map<String, Object?> payload, {
    required bool Function() isCurrent,
    DateTime Function()? serverNow,
  }) {
    final snapshot = copyTimelinePayload(payload);
    return _nativeOperation(() {
      if (serverNow != null) {
        snapshot['serverTimeMs'] = serverNow().millisecondsSinceEpoch;
      }
      if (supportsRestoration) snapshot['scope'] = _scope;
      return timeline.cacheTimeline(snapshot);
    }, isCurrent: isCurrent);
  }

  Future<bool> disableTimeline({required bool Function() isCurrent}) =>
      _nativeOperation(timeline.disableTimeline, isCurrent: isCurrent);

  Future<bool> _nativeOperation(
    Future<void> Function() operation, {
    required bool Function() isCurrent,
  }) {
    final revision = _revision;
    final result = _tail.then((_) async {
      if (_disposed || revision != _revision || !isCurrent()) return false;
      if (_needsCleanup) await _cleanup(revision);
      if (_disposed || revision != _revision || !isCurrent()) return false;
      await operation();
      return !_disposed && revision == _revision && isCurrent();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void dispose({bool clear = false, bool disable = false}) {
    if (_disposed) return;
    _disposed = true;
    _revision++;
    if (clear) _enqueueClear().catchError((Object _) {});
    if (!clear && disable) {
      final result = _tail.then((_) => timeline.disableTimeline());
      _tail = result.catchError((Object _) {});
    }
  }
}
