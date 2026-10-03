import 'dart:async';
import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/foundation.dart';
import '../data/auth_session.dart';

/// Account status is authoritative only for the identity that requested it.
class AccountController extends ChangeNotifier {
  AccountController(this.session) : _identity = session.userId {
    session.addListener(_changed);
    if (_identity != null) unawaited(refresh());
  }
  final AuthSession session;
  String? _identity;
  int _revision = 0;
  bool _disposed = false;
  bool busy = false;
  AccountState? account;
  Object? error;
  bool get guestOrUnknown => account?.isGuest != false;

  void _changed() {
    if (_identity == session.userId) return;
    _identity = session.userId;
    _revision++;
    account = null;
    error = null;
    busy = false;
    notifyListeners();
    if (_identity != null) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_disposed || session.userId == null) return;
    final revision = ++_revision;
    final id = session.userId;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await session.currentAccount();
      if (!_current(revision, id)) return;
      if (result != null && result.userId != id) {
        throw StateError('Account identity does not match the signed-in user.');
      }
      account = result;
    } catch (failure) {
      if (_current(revision, id)) error = failure;
    } finally {
      if (_current(revision, id)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  bool _current(int revision, String? id) =>
      !_disposed && _revision == revision && session.userId == id;
  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_changed);
    super.dispose();
  }
}
