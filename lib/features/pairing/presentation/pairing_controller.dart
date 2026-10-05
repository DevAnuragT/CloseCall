import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/data/auth_session.dart';
import '../../couple/data/couple_repository.dart';
import '../../couple/domain/couple.dart';

/// Owns async lifecycle; never uses mocks to mask a backend failure.
class PairingController extends ChangeNotifier {
  PairingController({
    required this.session,
    required this.repository,
    this.allowDevGuest = false,
  }) : _identity = session.userId {
    session.addListener(_authChanged);
  }

  final AuthSession session;
  final bool allowDevGuest;
  final CoupleRepository repository;
  String? _identity;
  int _authRevision = 0;
  bool _disposed = false;
  bool _reloadAfter = false;
  bool initialized = false;
  bool hasLoadedPairing = false;
  bool busy = false;
  Object? error;
  Couple? couple;
  String? inviteCode;
  Future<void> Function()? _retry;

  String? get userId => session.userId;
  int get authRevision => _authRevision;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _authChanged() {
    if (_identity == userId) return; // Token refresh is not an identity change.
    _identity = userId;
    _authRevision++;
    couple = null;
    inviteCode = null;
    hasLoadedPairing = false;
    error = null;
    _retry = null;
    _notify();
    if (!initialized || userId == null) return;
    if (busy) {
      _reloadAfter = true;
    } else {
      unawaited(refresh());
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _retry = action;
    _notify();
    try {
      await action();
      if (error == null) _retry = null;
    } catch (failure) {
      error = failure;
      _retry = action;
    } finally {
      busy = false;
      _notify();
      if (_reloadAfter && !_disposed) {
        _reloadAfter = false;
        unawaited(refresh());
      }
    }
  }

  Future<void> initialize() => _run(() async {
    initialized = false;
    await session.initialize();
    if (_disposed) return;
    initialized = true;
    // Pairing read failures retry only the read, not authentication/rotation.
    _retry = _load;
    try {
      await _load();
    } catch (failure) {
      error = failure;
    }
  });

  Future<void> signIn() => _run(() async {
    if (!allowDevGuest) {
      throw StateError('Development guest sign-in is disabled.');
    }
    // If sign-in succeeded but loading pairing failed, retry only the read;
    // never create a second guest identity as a network recovery mechanism.
    if (userId == null) await session.signInAnonymously();
    await _load();
  });

  Future<void> signOut() => _run(() async {
    try {
      await session.signOut();
    } on LocalSignOutException {
      // Remote revocation may fail after the SDK successfully cleared locally.
      // Never strand that signed-out device on the connection-error screen.
      if (!_disposed && userId == null) initialized = true;
      rethrow;
    }
    if (!_disposed && userId == null) initialized = true;
  });

  Future<void> refresh() => _run(_load);

  Future<void> retry() async {
    final action = _retry;
    if (action != null) await _run(action);
  }

  Future<void> _load() async {
    _reloadAfter = false;
    final id = userId;
    final revision = _authRevision;
    if (id == null) return;
    Couple? result;
    try {
      result = await repository.coupleForUser(id);
    } catch (_) {
      if (_isCurrent(id, revision)) rethrow;
      return;
    }
    if (!_isCurrent(id, revision)) return;
    couple = result;
    hasLoadedPairing = true;
    inviteCode = repository is PairingCodeReader
        ? (repository as PairingCodeReader).currentInviteCode
        : null;
  }

  bool _isCurrent(String id, int revision) =>
      !_disposed && id == userId && revision == _authRevision;

  Future<void> createInvite() => _run(() async {
    final id = userId;
    final revision = _authRevision;
    if (id == null) throw StateError('Sign in before pairing.');
    final result = await repository.createCouple(id);
    if (!_isCurrent(id, revision)) return;
    couple = result.couple;
    inviteCode = result.code;
    hasLoadedPairing = true;
  });

  Future<void> join(String code) => _run(() async {
    final id = userId;
    final revision = _authRevision;
    if (id == null) throw StateError('Sign in before pairing.');
    final result = await repository.joinByCode(id, code);
    if (!_isCurrent(id, revision)) return;
    couple = result;
    inviteCode = null;
    hasLoadedPairing = true;
  });

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_authChanged);
    super.dispose();
  }
}
