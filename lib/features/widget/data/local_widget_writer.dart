import 'dart:typed_data';

/// One native-write queue shared by manual media/editor updates and auto-sync.
/// A started platform write cannot be cancelled; scope cleanup is queued after
/// it, before any new identity's writes. Queued stale writes never start.
class LocalWidgetWriter {
  LocalWidgetWriter({required this.applyPhoto, required this.clearPhoto});
  final Future<void> Function(Uint8List) applyPhoto;
  final Future<void> Function() clearPhoto;
  Future<void> _tail = Future.value();
  String? _scope;
  int _revision = 0;
  bool _disposed = false;

  Future<void> setScope(String? scope) {
    if (_disposed || _scope == scope) return Future.value();
    final previous = _scope;
    _scope = scope;
    _revision++;
    return previous == null ? Future.value() : _enqueueClear();
  }

  Future<void> _enqueueClear() {
    final result = _tail.then((_) => clearPhoto());
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<bool> write(Uint8List photo, {required bool Function() isCurrent}) {
    final revision = _revision;
    final copy = Uint8List.fromList(photo);
    final result = _tail.then((_) async {
      if (_disposed || revision != _revision || !isCurrent()) return false;
      await applyPhoto(copy);
      return !_disposed && revision == _revision && isCurrent();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> clear({required bool Function() isCurrent}) {
    final revision = _revision;
    final result = _tail.then((_) async {
      if (_disposed || revision != _revision || !isCurrent()) return false;
      await clearPhoto();
      return !_disposed && revision == _revision && isCurrent();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void dispose({bool clear = false}) {
    if (_disposed) return;
    _disposed = true;
    _revision++;
    if (clear) _enqueueClear().catchError((Object _) {});
  }
}
