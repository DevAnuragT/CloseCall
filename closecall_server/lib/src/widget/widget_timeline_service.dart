import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:closecall_shared/closecall_shared.dart';
import 'package:crypto/crypto.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod/protocol.dart' show FutureCallEntry;

import '../generated/future_calls.dart';
import '../generated/future_calls_generated_models/widget_timeline_future_call_wake_model.dart';
import '../generated/protocol.dart';

UuidValue? parseScheduleUuid(String value) {
  if (!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(value)) {
    return null;
  }
  return UuidValue.fromString(value.toLowerCase());
}

String timelineChannel(String user) => 'closecall/widget/timeline/$user';

Future<void> notifyTimeline(Session session, String recipient) async {
  // Notifications contain no timeline/photo data. Subscribers independently
  // authorize and read committed database truth. DB polling covers other pods.
  await session.messages.postMessage(timelineChannel(recipient),
    TimelineNotice(recipientId: recipient), scope: MessageScope.local);
}

class WidgetTimelineService {
  static const _noFallback = '\u0000closecall/no-widget-fallback';

  Future<WidgetTimeline> timeline(Session session, String user, {bool partner = false}) =>
    session.db.transaction((transaction) async {
      final pair = await _pair(session, user, transaction);
      final recipient = partner ? pair.partner : pair.current;
      return _timeline(session, pair.coupleId, recipient, transaction);
    }, settings: const TransactionSettings(isolationLevel: IsolationLevel.repeatableRead));

  Future<WidgetScheduleEntry> create(Session session, String user, String assetId,
    DateTime activeFrom, DateTime activeUntil, String requestId) async {
    if (parseScheduleUuid(requestId) == null) {
      throw ScheduleFailure(code: 'invalid_request_id');
    }
    requestId = requestId.toLowerCase();
    final from = activeFrom.toUtc();
    final until = activeUntil.toUtc();
    // Timestamp precision is part of the exact payload fingerprint. PostgreSQL
    // stores microseconds, so no millisecond truncation or lossy ISO conversion.
    final fingerprint = sha256.convert(utf8.encode(jsonEncode([
      assetId.toLowerCase(), from.microsecondsSinceEpoch, until.microsecondsSinceEpoch,
    ]))).toString();
    final result = await session.db.transaction((transaction) async {
      final pair = await _pair(session, user, transaction);
      await _lock(session, 'couple/${pair.coupleId}', transaction);
      await _lock(session, 'user/$user', transaction);
      final existing = await WidgetScheduleRecord.db.findFirstRow(session,
        where: (t) => t.senderMemberId.equals(pair.current.id!) & t.requestId.equals(requestId),
        transaction: transaction);
      if (existing != null) {
        if (existing.payloadHash != fingerprint) throw ScheduleFailure(code: 'request_conflict');
        return _entry(existing, pair.current, pair.partner);
      }
      final now = clock.now().toUtc();
      if (!until.isAfter(from) || until.difference(from) > const Duration(days: 7) ||
          from.isAfter(now.add(const Duration(days: 30))) || !until.isAfter(now)) {
        throw ScheduleFailure(code: 'invalid_window');
      }
      final asset = await _asset(session, pair.coupleId, assetId, transaction);
      final count = await WidgetScheduleRecord.db.count(session,
        where: (t) => t.coupleId.equals(pair.coupleId) & t.cancelledAt.equals(null) & (t.activeUntil > now),
        transaction: transaction);
      if (count >= 100) throw ScheduleFailure(code: 'quota_exceeded');
      final row = await WidgetScheduleRecord.db.insertRow(session,
        WidgetScheduleRecord(coupleId: pair.coupleId, assetId: asset.id!,
          senderMemberId: pair.current.id!, recipientMemberId: pair.partner.id!,
          activeFrom: from, activeUntil: until, createdAt: now,
          requestId: requestId, payloadHash: fingerprint), transaction: transaction);
      await _enqueueWake(session, row, from.isBefore(now) ? now : from, 'start', transaction);
      await _enqueueWake(session, row, until, 'end', transaction);
      return _entry(row, pair.current, pair.partner);
    });
    await _bestEffortNotice(session, result.recipientId);
    return result;
  }

  Future<WidgetTimeline> fallback(Session session, String user, String assetId) async {
    final result = await session.db.transaction((transaction) async {
      final pair = await _pair(session, user, transaction);
      await _lock(session, 'couple/${pair.coupleId}', transaction);
      await _lock(session, 'user/$user', transaction);
      final asset = await _asset(session, pair.coupleId, assetId, transaction);
      final previous = await WidgetFallbackRecord.db.findFirstRow(session,
        where: (t) => t.recipientMemberId.equals(pair.current.id!), transaction: transaction);
      if (previous == null) {
        await WidgetFallbackRecord.db.insertRow(session,
          WidgetFallbackRecord(coupleId: pair.coupleId, recipientMemberId: pair.current.id!, assetId: asset.id!),
          transaction: transaction);
      } else {
        previous.assetId = asset.id!;
        await WidgetFallbackRecord.db.updateRow(session, previous, transaction: transaction);
      }
      return _timeline(session, pair.coupleId, pair.current, transaction);
    });
    await _bestEffortNotice(session, user);
    return result;
  }

  Future<void> cancel(Session session, String user, String scheduleId) async {
    final recipient = await session.db.transaction((transaction) async {
      final pair = await _pair(session, user, transaction);
      await _lock(session, 'couple/${pair.coupleId}', transaction);
      await _lock(session, 'user/$user', transaction);
      final id = parseScheduleUuid(scheduleId);
      if (id == null) throw ScheduleFailure(code: 'schedule_not_found');
      final row = await WidgetScheduleRecord.db.findFirstRow(session,
        where: (t) => t.id.equals(id) & t.coupleId.equals(pair.coupleId) &
          (t.senderMemberId.equals(pair.current.id!) | t.recipientMemberId.equals(pair.current.id!)),
        transaction: transaction);
      if (row == null) throw ScheduleFailure(code: 'schedule_not_found');
      if (row.cancelledAt == null) {
        row.cancelledAt = clock.now().toUtc();
        await WidgetScheduleRecord.db.updateRow(session, row, transaction: transaction);
      }
      // Keep the row for exact idempotency after cancellation/expiry. Pending
      // wakeups are harmless and intentionally retained for at-least-once safety.
      return row.recipientMemberId == pair.current.id! ? user : pair.partner.userIdentifier;
    });
    await _bestEffortNotice(session, recipient);
  }

  Future<void> _bestEffortNotice(Session session, String recipient) async {
    try { await notifyTimeline(session, recipient); }
    catch (_) {
      // The mutation has committed. Never tell a client to repeat a committed
      // mutation because an optimization failed; watchers reconcile from DB.
      session.log('Widget notification deferred to database reconciliation.', level: LogLevel.warning);
    }
  }

  Future<void> _enqueueWake(Session session, WidgetScheduleRecord row, DateTime at,
    String boundary, Transaction transaction) async {
    // Serverpod 4's generated typed dispatcher schedules on its internal
    // connection without a transaction option. Persist the SAME generated
    // typed envelope through the official repository in our transaction so
    // schedule + both durable wakeups commit or roll back together.
    final payload = WidgetTimelineFutureCallWakeModel(scheduleId: row.id!.toString());
    final handler = WidgetTimelineWakeFutureCall();
    await FutureCallEntry.db.insertRow(session,
      FutureCallEntry(name: handler.runtimeType.toString(),
        serializedObject: SerializationManager.encode(payload.toJson()),
        time: at, serverId: session.serverpod.serverId,
        identifier: 'closecall/widget/${row.id}/$boundary'), transaction: transaction);
  }

  Future<void> _lock(Session session, String key, Transaction transaction) =>
    session.db.unsafeQuery('SELECT pg_advisory_xact_lock(hashtextextended(@identity, 0))',
      parameters: QueryParameters.named({'identity': 'closecall/widget/$key'}),
      transaction: transaction).then((_) {});

  Future<({UuidValue coupleId, CoupleMember current, CoupleMember partner})> _pair(
    Session session, String user, Transaction transaction) async {
    final current = await CoupleMember.db.findFirstRow(session,
      where: (t) => t.userIdentifier.equals(user), transaction: transaction);
    if (current == null) throw ScheduleFailure(code: 'not_paired');
    final couple = await Couple.db.findById(session, current.coupleId, transaction: transaction);
    final members = await CoupleMember.db.find(session,
      where: (t) => t.coupleId.equals(current.coupleId), transaction: transaction);
    if (couple == null || couple.pairingCode != null || members.length != 2) {
      throw ScheduleFailure(code: 'not_paired');
    }
    return (coupleId: current.coupleId, current: current,
      partner: members.singleWhere((m) => m.id != current.id));
  }

  Future<MediaRecord> _asset(Session session, UuidValue coupleId, String assetId,
    Transaction transaction) async {
    final id = parseScheduleUuid(assetId);
    if (id == null) throw ScheduleFailure(code: 'asset_not_found');
    final row = await MediaRecord.db.findFirstRow(session,
      where: (t) => t.id.equals(id) & t.coupleId.equals(coupleId), transaction: transaction);
    if (row == null) throw ScheduleFailure(code: 'asset_not_found');
    return row;
  }

  Future<WidgetTimeline> _timeline(Session session, UuidValue coupleId,
    CoupleMember recipient, Transaction transaction) async {
    final now = clock.now().toUtc();
    final fallback = await WidgetFallbackRecord.db.findFirstRow(session,
      where: (t) => t.coupleId.equals(coupleId) & t.recipientMemberId.equals(recipient.id!),
      transaction: transaction);
    final rows = await WidgetScheduleRecord.db.find(session,
      where: (t) => t.coupleId.equals(coupleId) & t.recipientMemberId.equals(recipient.id!) &
        t.cancelledAt.equals(null) & (t.activeUntil > now), transaction: transaction);
    rows.sort((a, b) {
      final time = a.createdAt.compareTo(b.createdAt);
      return time == 0 ? a.id!.toString().compareTo(b.id!.toString()) : time;
    });
    final members = await CoupleMember.db.find(session,
      where: (t) => t.coupleId.equals(coupleId), transaction: transaction);
    final entries = rows.map((row) => _entry(row,
      members.singleWhere((m) => m.id == row.senderMemberId), recipient)).toList();
    final fallbackId = fallback?.assetId.toString();
    final resolution = WidgetScheduleResolver.resolve(now: now,
      schedules: entries.map((entry) => WidgetSchedule(id: entry.scheduleId,
        assetId: entry.assetId, activeFrom: entry.activeFrom,
        activeUntil: entry.activeUntil, createdAt: entry.createdAt)).toList(),
      fallbackAssetId: fallbackId ?? _noFallback);
    return WidgetTimeline(coupleId: coupleId.toString(), recipientId: recipient.userIdentifier,
      fallbackAssetId: fallbackId,
      currentAssetId: resolution.assetId == _noFallback ? null : resolution.assetId,
      nextTransition: resolution.nextTransition, schedules: entries, serverTime: now);
  }

  WidgetScheduleEntry _entry(WidgetScheduleRecord row, CoupleMember sender,
    CoupleMember recipient) => WidgetScheduleEntry(scheduleId: row.id!.toString(),
      assetId: row.assetId.toString(), senderId: sender.userIdentifier,
      recipientId: recipient.userIdentifier, activeFrom: row.activeFrom.toUtc(),
      activeUntil: row.activeUntil.toUtc(), createdAt: row.createdAt.toUtc());
}
