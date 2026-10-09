import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Couple-scoped current mood. The authenticated session is the only source
/// of identity; callers never choose a user or couple.
class MoodEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  static const _allowedMoods = {
    'happy',
    'tired',
    'busy',
    'stressed',
    'missingYou',
    'excited',
  };

  Future<MoodState> current(Session session) async {
    final user = session.authenticated!.userIdentifier;
    return session.db.transaction(
      (transaction) => _state(session, user, transaction),
      settings: const TransactionSettings(
        isolationLevel: IsolationLevel.repeatableRead,
      ),
    );
  }

  Future<MoodState> setMood(Session session, String mood) async {
    final normalized = mood.trim();
    if (!_allowedMoods.contains(normalized)) {
      throw MoodFailure(code: 'invalid_mood');
    }
    final user = session.authenticated!.userIdentifier;
    return session.db.transaction((transaction) async {
      final member = await _pairedMember(session, user, transaction);
      member.currentMood = normalized;
      member.moodUpdatedAt = DateTime.now().toUtc();
      await CoupleMember.db.updateRow(
        session,
        member,
        transaction: transaction,
      );
      return _state(session, user, transaction);
    });
  }

  Future<CoupleMember> _pairedMember(
    Session session,
    String user,
    Transaction transaction,
  ) async {
    final member = await CoupleMember.db.findFirstRow(
      session,
      where: (t) => t.userIdentifier.equals(user),
      transaction: transaction,
    );
    if (member == null) throw MoodFailure(code: 'not_paired');
    final count = await CoupleMember.db.count(
      session,
      where: (t) => t.coupleId.equals(member.coupleId),
      transaction: transaction,
    );
    if (count != 2) throw MoodFailure(code: 'not_paired');
    return member;
  }

  Future<MoodState> _state(
    Session session,
    String user,
    Transaction transaction,
  ) async {
    final own = await _pairedMember(session, user, transaction);
    final members = await CoupleMember.db.find(
      session,
      where: (t) => t.coupleId.equals(own.coupleId),
      transaction: transaction,
    );
    final partner = members.firstWhere(
      (member) => member.userIdentifier != user,
      orElse: () => throw MoodFailure(code: 'not_paired'),
    );
    return MoodState(
      ownMood: own.currentMood,
      ownUpdatedAt: own.moodUpdatedAt,
      partnerUserId: partner.userIdentifier,
      partnerMood: partner.currentMood,
      partnerUpdatedAt: partner.moodUpdatedAt,
    );
  }
}
