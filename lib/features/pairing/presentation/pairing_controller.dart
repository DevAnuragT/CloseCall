import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/async/bounded_retry.dart';
import '../../auth/data/auth_session.dart';
import '../../couple/data/couple_repository.dart';
import '../../couple/domain/couple.dart';
import '../../couple/domain/nickname.dart';
import '../data/pairing_cache.dart';

/// Owns async lifecycle; never uses mocks to mask a backend failure.
class PairingController extends ChangeNotifier {
  PairingController({
    required this.session,
    required this.repository,
    this.allowDevGuest = false,
    this.cache,
  }) : _identity = session.userId {
    session.addListener(_authChanged);
    if (_identity != null && cache != null) {
      unawaited(_restoreCachedPairing(_identity!));
    }
  }

  final AuthSession session;
  final bool allowDevGuest;
  final CoupleRepository repository;
  final PairingCache? cache;
  String? _identity;
  int _authRevision = 0;
  bool _disposed = false;
  bool _reloadAfter = false;
  bool _syncEnabled = false;
  bool _foreground = false;
  bool _refreshOnResume = false;
  int _syncVersion = 0;
  int _quietFailures = 0;
  Timer? _pollTimer;
  Future<void>? _quietFlight;
  final List<Future<void> Function()> _beforeSignOutHooks = [];
  bool _retryIsRead = false;
  bool _errorIsRead = false;
  int _retryRevision = 0;
  bool initialized = false;
  bool hasLoadedPairing = false;
  bool busy = false;
  Object? error;
  Couple? couple;
  String? inviteCode;
  bool nicknameSaving = false;
  Object? nicknameError;
  Future<bool> Function()? _nicknameRetry;
  int _pairingRevision = 0;
  Future<void> Function()? _retry;
  bool _cacheRestored = false;

  /// Whether the last failed operation is a user-confirmed mutation. Read
  /// failures recover in the controller and do not need an inline retry link.
  bool get hasExplicitRetry => _retry != null && !_retryIsRead;

  String? get userId => session.userId;
  int get authRevision => _authRevision;
  bool get canSaveNicknames =>
      !_disposed &&
      initialized &&
      hasLoadedPairing &&
      userId != null &&
      couple?.isComplete == true &&
      couple!.memberIds.contains(userId) &&
      repository is NicknameRepository;

  bool get canUnpair =>
      !_disposed &&
      initialized &&
      hasLoadedPairing &&
      userId != null &&
      couple != null &&
      repository is UnpairRepository;

  /// Opt-in for the live app only. Demo/fake controllers never start timers.
  void enableForegroundSync({bool foreground = true}) {
    if (_disposed) return;
    final wasEnabled = _syncEnabled;
    _syncEnabled = true;
    if (!wasEnabled && _foreground == foreground) {
      _schedulePoll(immediate: foreground);
    }
    setForeground(foreground);
  }

  void setForeground(bool value) {
    if (_disposed || _foreground == value) return;
    _foreground = value;
    _syncVersion++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _refreshOnResume = value && _syncEnabled && hasLoadedPairing;
    if (value) _schedulePoll(immediate: true);
  }

  // After bounded first-load retries, a failed re-read may heal quietly when a
  // valid snapshot already exists. Writes retain explicit recovery.
  bool get _canPoll =>
      !_disposed &&
      _syncEnabled &&
      _foreground &&
      initialized &&
      userId != null &&
      hasLoadedPairing &&
      (error == null || _errorIsRead);

  void _schedulePoll({bool immediate = false}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_canPoll || busy || nicknameSaving) return;
    if (_quietFlight != null) {
      _refreshOnResume |= immediate;
      return;
    }
    immediate |= _refreshOnResume;
    _refreshOnResume = false;
    final seconds = couple?.isComplete == true ? 15 : 5;
    final delay = Duration(
      seconds: (seconds * (1 << _quietFailures)).clamp(seconds, 60),
    );
    if (immediate) {
      _poll();
    } else {
      _pollTimer = Timer(delay, _poll);
    }
  }

  void _poll() {
    _pollTimer = null;
    if (!_canPoll || busy || nicknameSaving || _quietFlight != null) return;
    _quietFlight = _readQuiet().whenComplete(() {
      _quietFlight = null;
      _schedulePoll();
    });
  }

  Future<void> _readQuiet() async {
    final id = userId!;
    final revision = _authRevision;
    final sync = _syncVersion;
    bool current() =>
        _isCurrent(id, revision) &&
        _canPoll &&
        !busy &&
        !nicknameSaving &&
        sync == _syncVersion;
    try {
      final result = await repository.coupleForUser(id);
      if (!current()) return;
      _quietFailures = 0;
      final changed = _accept(result, _readInviteCode());
      final healed = error != null && _errorIsRead;
      if (healed) {
        error = null;
        _retry = null;
        _errorIsRead = false;
      }
      if (changed || healed) _notify();
    } catch (_) {
      if (current()) _quietFailures = (_quietFailures + 1).clamp(0, 4);
      // A background transport failure must not replace the last valid shell,
      // set busy, or steal an explicit mutation/retry's error and action.
    }
  }

  String? _readInviteCode() => repository is PairingCodeReader
      ? (repository as PairingCodeReader).currentInviteCode
      : null;

  bool _accept(Couple? result, String? code) {
    if (couple?.id != result?.id ||
        !listEquals(couple?.memberIds, result?.memberIds)) {
      _pairingRevision++;
      nicknameError = null;
      _nicknameRetry = null;
    }
    final changed = !hasLoadedPairing || couple != result || inviteCode != code;
    if (couple != result) couple = result;
    inviteCode = code;
    hasLoadedPairing = true;
    final id = userId;
    final pairingCache = cache;
    if (id != null && pairingCache != null) {
      if (result?.isComplete == true) {
        unawaited(pairingCache.write(id, result!, code));
      } else {
        unawaited(pairingCache.clear(id));
      }
    }
    return changed;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _authChanged() {
    if (_identity == userId) return; // Token refresh is not an identity change.
    final oldIdentity = _identity;
    _identity = userId;
    _cacheRestored = false;
    _authRevision++;
    _pairingRevision++;
    nicknameError = null;
    _nicknameRetry = null;
    _syncVersion++;
    _quietFailures = 0;
    _pollTimer?.cancel();
    _pollTimer = null;
    couple = null;
    inviteCode = null;
    hasLoadedPairing = false;
    error = null;
    _errorIsRead = false;
    _retry = null;
    _notify();
    if (oldIdentity != null && userId == null && cache != null) {
      unawaited(cache!.clear(oldIdentity));
    }
    if (userId != null && cache != null) {
      unawaited(_restoreCachedPairing(userId!));
    }
    if (!initialized || userId == null) return;
    if (busy || nicknameSaving) {
      _reloadAfter = true;
    } else {
      unawaited(refresh());
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool readOnly = false,
  }) async {
    if (busy || nicknameSaving || _disposed) return;
    _syncVersion++; // A late quiet read cannot overwrite this operation.
    _pollTimer?.cancel();
    _pollTimer = null;
    busy = true;
    error = null;
    _errorIsRead = false;
    _retry = action;
    _retryIsRead = readOnly;
    _retryRevision = _authRevision;
    _notify();
    try {
      await action();
      if (error == null) _retry = null;
    } catch (failure) {
      if (!_disposed &&
          ((_retry != null && _retryRevision == _authRevision) ||
              (failure is LocalSignOutException && userId == null))) {
        error = failure;
        _errorIsRead = _retryIsRead;
        _retry ??= action;
      }
    } finally {
      busy = false;
      _notify();
      if (_reloadAfter && !_disposed) {
        _reloadAfter = false;
        unawaited(refresh());
      } else {
        _schedulePoll();
      }
    }
  }

  Future<void> initialize() => _run(() async {
    final id = userId;
    final revision = _authRevision;
    initialized = false;
    await retryWithBackoff(
      operation: session.initialize,
      isCurrent: () => !_disposed && revision == _authRevision,
    );
    if (_disposed ||
        (id != null && userId != null && !_isCurrent(id, revision))) {
      return;
    }
    // Validation may intentionally clear revoked credentials. That is a
    // completed signed-out initialization, not an unauthorized cached session.
    initialized = true;
    // Pairing read failures retry only the read, not authentication/rotation.
    await _load();
  }, readOnly: true);

  Future<void> signIn() => _run(() async {
    if (!allowDevGuest) {
      throw StateError('Development guest sign-in is disabled.');
    }
    // If sign-in succeeded but loading pairing failed, retry only the read;
    // never create a second guest identity as a network recovery mechanism.
    if (userId == null) await session.signInAnonymously();
    await _load();
  });

  Future<void> _restoreCachedPairing(String id) async {
    final stored = await cache?.read(id);
    if (_disposed || id != userId || stored == null || _cacheRestored) return;
    _cacheRestored = true;
    couple = stored.couple;
    inviteCode = stored.inviteCode;
    hasLoadedPairing = true;
    _notify();
  }

  Future<void> signOut() => _run(() async {
    for (final hook in List<Future<void> Function()>.of(_beforeSignOutHooks)) {
      await hook();
    }
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

  Future<void> refresh() {
    if (error != null && hasExplicitRetry) return Future.value();
    return _run(_load, readOnly: true);
  }

  Future<void> unpair() async {
    final repository = this.repository;
    final unpairRepository = repository is UnpairRepository ? repository : null;
    final id = userId;
    final current = couple;
    final revision = _authRevision;
    if (unpairRepository == null ||
        id == null ||
        current == null ||
        !canUnpair) {
      throw StateError('Unpairing is unavailable for this account.');
    }
    final unpairCall = (unpairRepository as UnpairRepository).unpair;
    final coupleId = current.id;
    await _run(() async {
      if (!_isCurrent(id, revision) || couple?.id != coupleId) {
        throw StateError('Pairing changed. Open Profile again.');
      }
      await unpairCall(id, coupleId);
      if (!_isCurrent(id, revision)) return;
      await _load();
    });
  }

  Future<void> retry() async {
    final action = _retry;
    if (action != null) await _run(action, readOnly: _retryIsRead);
  }

  Future<bool> saveNicknames({
    required String ownNickname,
    required String partnerNickname,
  }) async {
    final repository = this.repository;
    if (repository is! NicknameRepository) {
      throw UnsupportedError('Nickname editing is unavailable.');
    }
    final nicknameRepository = repository as NicknameRepository;
    final id = userId;
    final current = couple;
    final revision = _authRevision;
    if (!canSaveNicknames || id == null || current == null) {
      throw const NicknameScopeException();
    }
    final own = normalizeNickname(ownNickname);
    final partner = normalizeNickname(partnerNickname);
    final pairRevision = _pairingRevision;
    bool valid() =>
        _isCurrent(id, revision) &&
        canSaveNicknames &&
        couple?.id == current.id &&
        pairRevision == _pairingRevision;
    Future<bool> action() async {
      // Retry must validate BEFORE sending the exact original payload, not only
      // after receiving a result. Never replay into a new account/couple.
      if (!valid()) throw const NicknameScopeException();
      final updated = await nicknameRepository.saveNicknames(
        id,
        current.id,
        ownNickname: own,
        partnerNickname: partner,
      );
      if (!valid()) return false;
      if (updated.id != current.id ||
          !updated.isComplete ||
          !listEquals(updated.memberIds, current.memberIds)) {
        throw const NicknameScopeException();
      }
      _accept(updated, inviteCode);
      return true;
    }

    return _runNicknames(action);
  }

  Future<bool> retryNicknames() async {
    final action = _nicknameRetry;
    return action == null ? false : _runNicknames(action);
  }

  Future<bool> _runNicknames(Future<bool> Function() action) async {
    if (_disposed || busy || nicknameSaving) return false;
    final revision = _authRevision;
    final pairRevision = _pairingRevision;
    _syncVersion++;
    _pollTimer?.cancel();
    _pollTimer = null;
    nicknameSaving = true;
    nicknameError = null;
    _nicknameRetry = action;
    _notify();
    try {
      final confirmed = await action();
      if (confirmed) _nicknameRetry = null;
      return confirmed;
    } catch (failure) {
      if (!_disposed &&
          revision == _authRevision &&
          pairRevision == _pairingRevision) {
        nicknameError = failure;
        if (failure is NicknameScopeException) _nicknameRetry = null;
      }
      return false;
    } finally {
      nicknameSaving = false;
      _notify();
      if (_reloadAfter && !_disposed) {
        _reloadAfter = false;
        unawaited(refresh());
      } else {
        _schedulePoll();
      }
    }
  }

  /// Allows scoped services to revoke authenticated device state before the
  /// auth session is cleared. Hooks must be best-effort and must not strand a
  /// sign-out; callers should swallow remote transport failures.
  void addBeforeSignOutHook(Future<void> Function() hook) {
    if (!_beforeSignOutHooks.contains(hook)) _beforeSignOutHooks.add(hook);
  }

  void removeBeforeSignOutHook(Future<void> Function() hook) {
    _beforeSignOutHooks.remove(hook);
  }

  Future<void> _load() async {
    // Explicit reads serialize behind any quiet read. Writes need not wait;
    // their operation version invalidates that read instead.
    if (_quietFlight != null) await _quietFlight;
    if (_disposed) return;
    _reloadAfter = false;
    final id = userId;
    final revision = _authRevision;
    if (id == null) return;
    _retry = _load;
    _retryIsRead = true;
    _retryRevision = revision;
    Couple? result;
    try {
      result = await retryWithBackoff(
        operation: () => repository.coupleForUser(id),
        isCurrent: () => _isCurrent(id, revision),
        shouldRetry: (failure) => failure is! PairingException,
      );
    } catch (_) {
      if (_isCurrent(id, revision)) rethrow;
      return;
    }
    if (!_isCurrent(id, revision)) return;
    _quietFailures = 0;
    _accept(result, _readInviteCode());
  }

  bool _isCurrent(String id, int revision) =>
      !_disposed && id == userId && revision == _authRevision;

  Future<void> createInvite() => _run(() async {
    final id = userId;
    final revision = _authRevision;
    if (id == null) throw StateError('Sign in before pairing.');
    final result = await repository.createCouple(id);
    if (!_isCurrent(id, revision)) return;
    _quietFailures = 0;
    _accept(result.couple, result.code);
  });

  Future<void> join(String code) => _run(() async {
    final id = userId;
    final revision = _authRevision;
    if (id == null) throw StateError('Sign in before pairing.');
    final result = await repository.joinByCode(id, code);
    if (!_isCurrent(id, revision)) return;
    _quietFailures = 0;
    _accept(result, null);
  });

  @override
  void dispose() {
    _disposed = true;
    _syncVersion++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _beforeSignOutHooks.clear();
    session.removeListener(_authChanged);
    super.dispose();
  }
}
