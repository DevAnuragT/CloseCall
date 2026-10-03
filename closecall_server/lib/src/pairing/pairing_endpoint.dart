import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'invite_code.dart';

/// Identity comes exclusively from authenticated JWT sessions, never arguments.
class PairingEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<PairingState> createCouple(Session session) async {
    final user = session.authenticated!.userIdentifier;
    return session.db.transaction((transaction) async {
      await _lockUser(session, user, transaction);
      final existing = await _membership(session, user, transaction);
      if (existing != null) {
        // Serialize an idempotent owner read with a partner redeeming the code,
        // so a response cannot combine an old invite with new membership IDs.
        await session.db.unsafeQuery(
          'SELECT id FROM closecall_couple WHERE id = CAST(@id AS uuid) FOR UPDATE',
          parameters: QueryParameters.named({
            'id': existing.coupleId.toString(),
          }),
          transaction: transaction,
        );
        final couple = await _couple(session, existing.coupleId, transaction);
        if (existing.creatorSlot && couple.pairingCode != null) {
          return _state(session, couple, transaction);
        }
        throw PairingFailure(code: 'already_paired');
      }

      final couple = await _createWithUniqueCode(session, transaction);
      await CoupleMember.db.insertRow(
        session,
        CoupleMember(
          coupleId: couple.id!,
          userIdentifier: user,
          creatorSlot: true,
        ),
        transaction: transaction,
      );
      return _state(session, couple, transaction);
    });
  }

  Future<PairingState> joinByCode(Session session, String code) async {
    final user = session.authenticated!.userIdentifier;
    final normalized = InviteCode.normalize(code);
    if (!InviteCode.isValid(normalized)) {
      throw PairingFailure(code: 'invalid_code');
    }

    return session.db.transaction((transaction) async {
      await _lockUser(session, user, transaction);
      final existing = await _membership(session, user, transaction);
      if (existing != null) {
        final couple = await _couple(session, existing.coupleId, transaction);
        if (existing.creatorSlot && couple.pairingCode == normalized) {
          throw PairingFailure(code: 'cannot_pair_with_self');
        }
        throw PairingFailure(code: 'already_paired');
      }

      // PostgreSQL row locking serializes code redemption across server instances.
      // At READ COMMITTED, a waiter rechecks the predicate after the first join
      // commits, so a consumed (now NULL) invite cannot be redeemed again.
      final rows = await session.db.unsafeQuery(
        'SELECT id::text FROM closecall_couple '
        'WHERE "pairingCode" = @code FOR UPDATE',
        parameters: QueryParameters.named({'code': normalized}),
        transaction: transaction,
      );
      if (rows.isEmpty) throw PairingFailure(code: 'code_not_found');

      final couple = await _couple(
        session,
        UuidValue.fromString(rows.first.first as String),
        transaction,
      );
      await CoupleMember.db.insertRow(
        session,
        CoupleMember(
          coupleId: couple.id!,
          userIdentifier: user,
          creatorSlot: false,
        ),
        transaction: transaction,
      );
      couple.pairingCode = null;
      await Couple.db.updateRow(session, couple, transaction: transaction);
      return _state(session, couple, transaction);
    });
  }

  Future<PairingState?> currentCouple(Session session) async {
    final user = session.authenticated!.userIdentifier;
    // A consistent snapshot avoids returning an old code with newly joined IDs.
    return session.db.transaction(
      (transaction) async {
        final member = await _membership(session, user, transaction);
        if (member == null) return null;
        return _state(
          session,
          await _couple(session, member.coupleId, transaction),
          transaction,
        );
      },
      settings: const TransactionSettings(
        isolationLevel: IsolationLevel.repeatableRead,
      ),
    );
  }

  Future<void> _lockUser(
    Session session,
    String user,
    Transaction transaction,
  ) async {
    // Unlike process-local locks, transaction-scoped advisory locks cover every
    // server instance sharing PostgreSQL. Hash collisions only over-serialize.
    await session.db.unsafeQuery(
      'SELECT pg_advisory_xact_lock(hashtextextended(@identity, 0))',
      parameters: QueryParameters.named({
        'identity': 'closecall/pairing/$user',
      }),
      transaction: transaction,
    );
  }

  Future<CoupleMember?> _membership(
    Session session,
    String user,
    Transaction transaction,
  ) => CoupleMember.db.findFirstRow(
    session,
    where: (t) => t.userIdentifier.equals(user),
    transaction: transaction,
  );

  Future<Couple> _couple(
    Session session,
    UuidValue id,
    Transaction transaction,
  ) async => (await Couple.db.findById(session, id, transaction: transaction))!;

  Future<Couple> _createWithUniqueCode(
    Session session,
    Transaction transaction,
  ) async {
    for (var attempt = 0; attempt < 32; attempt++) {
      final savepoint = await transaction.createSavepoint();
      try {
        final couple = await Couple.db.insertRow(
          session,
          Couple(pairingCode: InviteCode.generate()),
          transaction: transaction,
        );
        await savepoint.release();
        return couple;
      } on DatabaseUniqueViolationException catch (error) {
        if (error.constraintName != 'closecall_couple_pairing_code_unique') {
          rethrow;
        }
        await savepoint.rollback();
        await savepoint.release();
      }
    }
    throw StateError('Could not allocate a unique invite code.');
  }

  Future<PairingState> _state(
    Session session,
    Couple couple,
    Transaction transaction,
  ) async {
    final members = await CoupleMember.db.find(
      session,
      where: (t) => t.coupleId.equals(couple.id!),
      transaction: transaction,
    );
    members.sort(
      (a, b) => a.creatorSlot == b.creatorSlot ? 0 : (a.creatorSlot ? -1 : 1),
    );
    return PairingState(
      coupleId: couple.id!.toString(),
      memberIds: members.map((member) => member.userIdentifier).toList(),
      partnerNickname: couple.partnerNickname,
      anniversary: couple.anniversary,
      themeKey: couple.themeKey,
      pairingCode: couple.pairingCode,
    );
  }
}
