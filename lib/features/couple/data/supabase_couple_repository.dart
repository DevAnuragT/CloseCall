import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/couple.dart';
import '../../pairing/domain/pairing_code.dart';
import 'couple_repository.dart';

/// Legacy Supabase-backed pairing, not selected by app startup.
/// Tables and RLS live in `supabase/migrations`.
///
/// The `couples` row carries `member_ids uuid[]` and a nullable, unique
/// `pairing_code` that is set while the couple is pending and cleared once the
/// second partner joins.
class SupabaseCoupleRepository implements CoupleRepository {
  SupabaseCoupleRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'couples';
  static const _uniqueViolation = '23505';

  @override
  Future<PairingResult> createCouple(String userId) async {
    final existing = await coupleForUser(userId);
    if (existing != null) {
      if (existing.isComplete) {
        throw const PairingException(PairingError.alreadyPaired);
      }
      final code = await _codeFor(existing.id);
      if (code != null) return PairingResult(couple: existing, code: code);
    }

    // Retry on the rare pairing-code collision.
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = PairingCode.generate();
      try {
        final row = await _client
            .from(_table)
            .insert({
              'member_ids': [userId],
              'pairing_code': code,
            })
            .select()
            .single();
        return PairingResult(couple: Couple.fromJson(row), code: code);
      } on PostgrestException catch (e) {
        if (e.code == _uniqueViolation) continue;
        rethrow;
      }
    }
    throw const PairingException(PairingError.invalidCode);
  }

  @override
  Future<Couple> joinByCode(String userId, String code) async {
    if (!PairingCode.isValid(code)) {
      throw const PairingException(PairingError.invalidCode);
    }
    final normalized = PairingCode.normalize(code);

    // Joining mutates a couple the caller isn't a member of yet, which strict
    // RLS forbids. The `join_couple` SECURITY DEFINER function does the
    // validation + append server-side; see supabase/migrations.
    try {
      final row = await _client.rpc(
        'join_couple',
        params: {'p_code': normalized},
      );
      // The function returns the couple row (as a single-object json).
      final map = row is List ? row.first : row;
      return Couple.fromJson(Map<String, dynamic>.from(map as Map));
    } on PostgrestException catch (e) {
      throw PairingException(_mapRpcError(e.message));
    }
  }

  PairingError _mapRpcError(String message) {
    if (message.contains('code_not_found')) return PairingError.codeNotFound;
    if (message.contains('cannot_pair_with_self')) {
      return PairingError.cannotPairWithSelf;
    }
    if (message.contains('already_paired')) return PairingError.alreadyPaired;
    return PairingError.invalidCode;
  }

  @override
  Future<Couple?> coupleForUser(String userId) async {
    final row = await _client.from(_table).select().contains('member_ids', [
      userId,
    ]).maybeSingle();
    return row == null ? null : Couple.fromJson(row);
  }

  Future<String?> _codeFor(String coupleId) async {
    final row = await _client
        .from(_table)
        .select('pairing_code')
        .eq('id', coupleId)
        .maybeSingle();
    return row?['pairing_code'] as String?;
  }
}
