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
  Future<void> Function()? _retry;

  String? get userId => session.userId;
  int get authRevision => _authRevision;

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

  // First-load failures and failed writes remain owned by explicit Retry.
  // A failed re-read may heal quietly only when a valid snapshot already exists.
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
    if (!_canPoll || busy) return;
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
    if (!_canPoll || busy || _quietFlight != null) return;
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
        _isCurrent(id, revision) && _canPoll && !busy && sync == _syncVersion;
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
    final changed = !hasLoadedPairing || couple != result || inviteCode != code;
    if (couple != result) couple = result;
    inviteCode = code;
    hasLoadedPairing = true;
    return changed;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _authChanged() {
    if (_identity == userId) return; // Token refresh is not an identity change.
    _identity = userId;
    _authRevision++;
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
    if (!initialized || userId == null) return;
    if (busy) {
      _reloadAfter = true;
    } else {
      unawaited(refresh());
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool readOnly = false,
  }) async {
    if (busy || _disposed) return;
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
    await session.initialize();
    if (_disposed ||
        (id != null && userId != null && !_isCurrent(id, revision))) {
      return;
    }
    // Validation may intentionally clear revoked credentials. That is a
    // completed signed-out initialization, not an unauthorized cached session.
    initialized = true;
    // Pairing read failures retry only the read, not authentication/rotation.
    await _load();
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

  Future<void> refresh() => _run(_load, readOnly: true);

  Future<void> retry() async {
    final action = _retry;
    if (action != null) await _run(action, readOnly: _retryIsRead);
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
      result = await repository.coupleForUser(id);
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
