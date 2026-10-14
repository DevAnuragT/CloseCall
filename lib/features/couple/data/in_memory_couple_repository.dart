import 'dart:math';

import '../domain/couple.dart';
import '../../pairing/domain/pairing_code.dart';
import 'couple_repository.dart';

/// In-memory [CoupleRepository] for tests and offline demos. Not persistent.
class InMemoryCoupleRepository implements CoupleRepository, UnpairRepository {
  InMemoryCoupleRepository({Random? random}) : this._(random);

  InMemoryCoupleRepository._(this._random);

  final Random? _random;

  int _seq = 0;
  final Map<String, Couple> _couples = {}; // coupleId -> couple
  final Map<String, String> _pendingCodes = {}; // code -> coupleId

  @override
  Future<PairingResult> createCouple(String userId) async {
    final existing = _pendingCoupleForUser(userId);
    if (existing != null) {
      final code = _codeFor(existing.id);
      if (code != null) return PairingResult(couple: existing, code: code);
    }

    final complete = await coupleForUser(userId);
    if (complete != null && complete.isComplete) {
      throw const PairingException(PairingError.alreadyPaired);
    }

    final id = 'couple-${_seq++}';
    final code = _uniqueCode();
    final couple = Couple(id: id, memberIds: [userId]);
    _couples[id] = couple;
    _pendingCodes[code] = id;
    return PairingResult(couple: couple, code: code);
  }

  @override
  Future<Couple> joinByCode(String userId, String code) async {
    if (!PairingCode.isValid(code)) {
      throw const PairingException(PairingError.invalidCode);
    }
    final normalized = PairingCode.normalize(code);
    final coupleId = _pendingCodes[normalized];
    if (coupleId == null) {
      throw const PairingException(PairingError.codeNotFound);
    }
    final couple = _couples[coupleId]!;
    if (couple.memberIds.contains(userId)) {
      throw const PairingException(PairingError.cannotPairWithSelf);
    }
    final updated = couple.copyWith(memberIds: [...couple.memberIds, userId]);
    _couples[coupleId] = updated;
    _pendingCodes.remove(normalized);
    return updated;
  }

  @override
  Future<Couple?> coupleForUser(String userId) async {
    for (final couple in _couples.values) {
      if (couple.memberIds.contains(userId)) return couple;
    }
    return null;
  }

  @override
  Future<void> unpair(String userId, String coupleId) async {
    final couple = _couples[coupleId];
    if (couple == null || !couple.memberIds.contains(userId)) {
      throw const PairingException(PairingError.alreadyPaired);
    }
    final members = couple.memberIds.where((id) => id != userId).toList();
    _pendingCodes.removeWhere((_, id) => id == coupleId);
    if (members.isEmpty) {
      _couples.remove(coupleId);
      return;
    }
    _couples[coupleId] = couple.copyWith(memberIds: members);
    _pendingCodes[_uniqueCode()] = coupleId;
  }

  Couple? _pendingCoupleForUser(String userId) {
    for (final couple in _couples.values) {
      if (couple.memberIds.contains(userId) && !couple.isComplete) {
        return couple;
      }
    }
    return null;
  }

  String? _codeFor(String coupleId) {
    for (final entry in _pendingCodes.entries) {
      if (entry.value == coupleId) return entry.key;
    }
    return null;
  }

  String _uniqueCode() {
    var code = PairingCode.generate(random: _random);
    while (_pendingCodes.containsKey(code)) {
      code = PairingCode.generate(random: _random);
    }
    return code;
  }
}
