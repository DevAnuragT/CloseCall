import 'package:closecall_client/closecall_client.dart' as api;

import '../domain/couple.dart';
import '../domain/nickname.dart';
import 'couple_repository.dart';

/// The server derives identity from the session: userId is never sent over RPC.
class ServerpodCoupleRepository
    implements CoupleRepository, PairingCodeReader, NicknameRepository {
  ServerpodCoupleRepository(
    api.Client client, {
    required String? Function() userId,
  }) : this.withCalls(
         userId: userId,
         create: client.pairing.createCouple,
         join: client.pairing.joinByCode,
         current: client.pairing.currentCouple,
         updateNicknames: client.pairing.updateNicknames,
       );

  /// Injectable typed RPC boundaries, without fabricating a generated client.
  ServerpodCoupleRepository.withCalls({
    required String? Function() userId,
    required Future<api.PairingState> Function() create,
    required Future<api.PairingState> Function(String) join,
    required Future<api.PairingState?> Function() current,
    Future<api.PairingState> Function(String, String?, String?)?
    updateNicknames,
  }) : this._(userId, create, join, current, updateNicknames);

  ServerpodCoupleRepository._(
    this._userId,
    this._create,
    this._join,
    this._current,
    this._updateNicknames,
  );

  final String? Function() _userId;
  final Future<api.PairingState> Function() _create;
  final Future<api.PairingState> Function(String) _join;
  final Future<api.PairingState?> Function() _current;
  final Future<api.PairingState> Function(String, String?, String?)?
  _updateNicknames;

  @override
  String? currentInviteCode;

  void _checkIdentity(String userId) {
    if (_userId() == null || userId != _userId()) {
      throw StateError('Pairing requires the current authenticated user.');
    }
  }

  static Couple toCouple(api.PairingState state) => Couple(
    id: state.coupleId,
    memberIds: List<String>.unmodifiable(state.memberIds),
    ownNickname: state.ownNickname,
    partnerNickname: state.partnerNickname,
    anniversary: state.anniversary,
    themeKey: state.themeKey,
  );

  Future<T> _translate<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on api.PairingFailure catch (failure) {
      final error = switch (failure.code) {
        'invalid_code' => PairingError.invalidCode,
        'code_not_found' => PairingError.codeNotFound,
        'already_paired' => PairingError.alreadyPaired,
        'cannot_pair_with_self' => PairingError.cannotPairWithSelf,
        _ => null,
      };
      // Unknown server errors and transport failures retain their identity.
      if (error == null) rethrow;
      throw PairingException(error);
    }
  }

  @override
  Future<PairingResult> createCouple(String userId) async {
    _checkIdentity(userId);
    final state = await _translate(_create);
    final code = state.pairingCode;
    if (code == null || code.isEmpty) {
      throw StateError('The server did not return a pending invite code.');
    }
    currentInviteCode = code;
    return PairingResult(couple: toCouple(state), code: code);
  }

  @override
  Future<Couple> joinByCode(String userId, String code) async {
    _checkIdentity(userId);
    final state = await _translate(() => _join(code));
    currentInviteCode = state.pairingCode;
    return toCouple(state);
  }

  @override
  Future<Couple?> coupleForUser(String userId) async {
    _checkIdentity(userId);
    final state = await _translate(_current);
    currentInviteCode = state?.pairingCode;
    return state == null ? null : toCouple(state);
  }

  @override
  Future<Couple> saveNicknames(
    String userId,
    String coupleId, {
    String? ownNickname,
    String? partnerNickname,
  }) async {
    _checkIdentity(userId);
    final call = _updateNicknames;
    if (call == null) throw UnsupportedError('Nickname editing unavailable.');
    try {
      final state = await call(coupleId, ownNickname, partnerNickname);
      _checkIdentity(userId);
      if (state.coupleId != coupleId || !state.memberIds.contains(userId)) {
        throw const NicknameScopeException();
      }
      return toCouple(state);
    } on api.PairingFailure catch (failure) {
      if (failure.code == 'invalid_nickname') {
        throw const NicknameValidationException();
      }
      if (failure.code == 'not_paired') throw const NicknameScopeException();
      rethrow;
    }
  }
}
