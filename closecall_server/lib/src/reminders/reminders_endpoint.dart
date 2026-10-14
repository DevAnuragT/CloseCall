import 'dart:async';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'reminder_event_dispatcher.dart';

class RemindersEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  @override
  bool get logSessions => false;

  static const _kinds = {
    'call',
    'dateNight',
    'birthday',
    'anniversary',
    'event',
  };

  Future<List<ReminderEntry>> listReminders(Session session) async {
    return _run(session, (transaction, member) async {
      final rows = await ReminderRecord.db.find(
        session,
        where: (t) => t.coupleId.equals(member.coupleId),
        orderBy: (t) => t.remindAt,
        transaction: transaction,
      );
      return rows.map(_entry).toList(growable: false);
    });
  }

  Future<ReminderEntry> createReminder(
    Session session, {
    required String requestId,
    required String title,
    required String kind,
    required DateTime remindAt,
  }) async {
    final normalizedRequest = requestId.trim().toLowerCase();
    final normalizedTitle = title.trim();
    final normalizedKind = kind.trim();
    if (!_isUuid(normalizedRequest)) {
      throw ReminderFailure(code: 'invalid_request_id');
    }
    if (normalizedTitle.isEmpty ||
        normalizedTitle.runes.length > 120 ||
        normalizedTitle.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw ReminderFailure(code: 'invalid_title');
    }
    if (!_kinds.contains(normalizedKind)) {
      throw ReminderFailure(code: 'invalid_kind');
    }
    final instant = remindAt.toUtc();
    final now = DateTime.now().toUtc();
    if (!instant.isAfter(now.add(const Duration(minutes: 1))) ||
        instant.isAfter(now.add(const Duration(days: 366)))) {
      throw ReminderFailure(code: 'invalid_time');
    }
    final result = await _run(session, (transaction, member) async {
      // Serialize retries for one couple/request across pods so the unique
      // request index is a final invariant rather than the normal idempotency
      // path. The lock key contains only opaque identity values.
      await session.db.unsafeQuery(
        'SELECT pg_advisory_xact_lock(hashtextextended(@identity, 0))',
        parameters: QueryParameters.named({
          'identity':
              'closecall/reminder/${member.coupleId}/$normalizedRequest',
        }),
        transaction: transaction,
      );
      final existing = await ReminderRecord.db.findFirstRow(
        session,
        where: (t) =>
            t.coupleId.equals(member.coupleId) &
            t.requestId.equals(normalizedRequest),
        transaction: transaction,
      );
      if (existing != null) {
        if (existing.creatorId != session.authenticated!.userIdentifier ||
            existing.title != normalizedTitle ||
            existing.kind != normalizedKind ||
            existing.remindAt.toUtc() != instant) {
          throw ReminderFailure(code: 'request_conflict');
        }
        return _entry(existing);
      }
      final count = await ReminderRecord.db.count(
        session,
        where: (t) =>
            t.coupleId.equals(member.coupleId) & t.completedAt.equals(null),
        transaction: transaction,
      );
      if (count >= 100) throw ReminderFailure(code: 'quota_exceeded');
      final row = await ReminderRecord.db.insertRow(
        session,
        ReminderRecord(
          coupleId: member.coupleId,
          creatorMemberId: member.id!,
          creatorId: session.authenticated!.userIdentifier,
          title: normalizedTitle,
          kind: normalizedKind,
          remindAt: instant,
          requestId: normalizedRequest,
        ),
        transaction: transaction,
      );
      final members = await CoupleMember.db.find(
        session,
        where: (t) => t.coupleId.equals(member.coupleId),
        transaction: transaction,
      );
      final recipient = members.singleWhere(
        (candidate) => candidate.id != member.id,
      );
      await ReminderEventOutbox.db.insertRow(
        session,
        ReminderEventOutbox(
          coupleId: member.coupleId,
          reminderId: row.id!,
          recipientMemberId: recipient.id!,
          eventType: 'reminder_created',
          expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        ),
        transaction: transaction,
      );
      return _entry(row);
    });
    // The durable row is authoritative; this is only a bounded wake-up. A
    // duplicate request returns the existing reminder and cannot enqueue a
    // second event because insertion is limited to the first transaction.
    unawaited(ReminderEventOutboxRuntime.kick(session.serverpod));
    return result;
  }

  Future<void> completeReminder(
    Session session, {
    required String reminderId,
  }) async {
    final id = _parseId(reminderId);
    await _run(session, (transaction, member) async {
      final row = await _find(session, id, member.coupleId, transaction);
      if (row.completedAt == null) {
        row.completedAt = DateTime.now().toUtc();
        await ReminderRecord.db.updateRow(
          session,
          row,
          transaction: transaction,
        );
      }
    });
  }

  Future<void> deleteReminder(
    Session session, {
    required String reminderId,
  }) async {
    final id = _parseId(reminderId);
    await _run(session, (transaction, member) async {
      final row = await _find(session, id, member.coupleId, transaction);
      await ReminderRecord.db.deleteRow(session, row, transaction: transaction);
    });
  }

  Future<T> _run<T>(
    Session session,
    Future<T> Function(Transaction, CoupleMember) action,
  ) async {
    return session.db.transaction((transaction) async {
      final member = await CoupleMember.db.findFirstRow(
        session,
        where: (t) =>
            t.userIdentifier.equals(session.authenticated!.userIdentifier),
        transaction: transaction,
      );
      if (member == null) throw ReminderFailure(code: 'not_paired');
      final count = await CoupleMember.db.count(
        session,
        where: (t) => t.coupleId.equals(member.coupleId),
        transaction: transaction,
      );
      if (count != 2) throw ReminderFailure(code: 'not_paired');
      return action(transaction, member);
    });
  }

  Future<ReminderRecord> _find(
    Session session,
    UuidValue id,
    UuidValue coupleId,
    Transaction transaction,
  ) async {
    final row = await ReminderRecord.db.findById(
      session,
      id,
      transaction: transaction,
    );
    if (row == null || row.coupleId != coupleId) {
      throw ReminderFailure(code: 'reminder_not_found');
    }
    return row;
  }

  ReminderEntry _entry(ReminderRecord row) => ReminderEntry(
    id: row.id!,
    title: row.title,
    kind: row.kind,
    remindAt: row.remindAt.toUtc(),
    completedAt: row.completedAt?.toUtc(),
    createdAt: row.createdAt.toUtc(),
  );

  UuidValue _parseId(String value) {
    try {
      return UuidValue.fromString(value);
    } catch (_) {
      throw ReminderFailure(code: 'invalid_request');
    }
  }

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(value);
}
