import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../push/fcm_sender.dart';

/// Durable, independent delivery pipeline for partner Moment events. It never
/// consults WidgetDeliveryRecord or PushOutbox, so widget consent cannot gate
/// or authorize Moment notifications.
class MomentEventOutboxDispatcher {
  MomentEventOutboxDispatcher({
    required this.sender,
    this.maxAttempts = 8,
    this.batchSize = 10,
    this.leaseDuration = const Duration(seconds: 30),
    this.baseBackoff = const Duration(seconds: 5),
    this.maxBackoff = const Duration(minutes: 10),
    String? owner,
  }) : _owner = owner ?? const Uuid().v4();

  final MomentFcmSender sender;
  final int maxAttempts;
  final int batchSize;
  final Duration leaseDuration;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final String _owner;

  Future<int> reconcile(Serverpod pod, {int? maxRows}) async {
    final limit = min(maxRows ?? batchSize, batchSize);
    if (limit <= 0) return 0;
    return pod.withSession((session) async {
      var processed = 0;
      for (var i = 0; i < limit; i++) {
        final row = await _claim(session);
        if (row == null) break;
        processed++;
        try {
          await _dispatch(session, row);
        } catch (_) {
          await _retryOrComplete(session, row, 'dispatcher_error');
        }
      }
      return processed;
    }, enableLogging: false);
  }

  Future<MomentEventOutbox?> _claim(Session session) async {
    return session.db.transaction((transaction) async {
      final rows = await session.db.unsafeQuery(
        'SELECT "id"::text FROM closecall_moment_event_outbox '
        'WHERE "completedAt" IS NULL AND "expiresAt" > CURRENT_TIMESTAMP '
        'AND "availableAt" <= CURRENT_TIMESTAMP '
        'AND ("leasedUntil" IS NULL OR "leasedUntil" < CURRENT_TIMESTAMP) '
        'AND "attempts" < @maxAttempts '
        'ORDER BY "createdAt", "id" FOR UPDATE SKIP LOCKED LIMIT 1',
        parameters: QueryParameters.named({'maxAttempts': maxAttempts}),
        transaction: transaction,
      );
      if (rows.isEmpty) return null;
      final row = (await MomentEventOutbox.db.findById(
        session,
        UuidValue.fromString(rows.first.first as String),
        transaction: transaction,
      ))!;
      row.attempts += 1;
      row.leasedUntil = clock.now().toUtc().add(leaseDuration);
      row.leaseOwner = _owner;
      await MomentEventOutbox.db.updateRow(session, row, transaction: transaction);
      return row;
    });
  }

  Future<void> _dispatch(Session session, MomentEventOutbox row) async {
    if (row.expiresAt.isBefore(clock.now().toUtc())) {
      await _complete(session, row, 'expired');
      return;
    }
    final moment = await MomentRecord.db.findFirstRow(
      session,
      where: (t) =>
          t.id.equals(row.momentId) &
          t.coupleId.equals(row.coupleId) &
          t.deletedAt.equals(null),
    );
    if (moment == null || !(await _completeMembership(session, row))) {
      await _complete(session, row, moment == null ? 'moment_missing' : 'membership_lost');
      return;
    }
    final registrations = await PushDeviceRegistration.db.find(
      session,
      where: (t) =>
          t.coupleId.equals(row.coupleId) &
          t.memberId.equals(row.recipientMemberId) &
          t.revokedAt.equals(null),
    );
    if (registrations.isEmpty) {
      await _complete(session, row, 'no_active_registration');
      return;
    }
    var transient = false;
    for (final registration in registrations) {
      final result = await sender.sendMoment(
        token: registration.token,
        momentId: row.momentId.toString(),
        eventType: row.eventType,
      );
      switch (result.status) {
        case FcmSendStatus.sent:
          break;
        case FcmSendStatus.invalidToken:
          await _revoke(session, registration);
        case FcmSendStatus.transientFailure:
        case FcmSendStatus.permanentFailure:
          transient = true;
      }
    }
    if (transient) {
      await _retryOrComplete(session, row, 'fcm_retry');
    } else {
      await _complete(session, row, 'sent');
    }
  }

  Future<bool> _completeMembership(Session session, MomentEventOutbox row) async {
    final result = await session.db.unsafeQuery(
      'SELECT 1 FROM closecall_couple c '
      'JOIN closecall_couple_member recipient '
      'ON recipient."coupleId" = c.id AND recipient.id = @recipient '
      'JOIN closecall_couple_member author '
      'ON author."coupleId" = c.id AND author.id = '
      '(SELECT "authorMemberId" FROM closecall_moment '
      'WHERE id = CAST(@moment AS uuid)) '
      'WHERE c.id = CAST(@couple AS uuid) AND c."pairingCode" IS NULL '
      'AND (SELECT count(*) FROM closecall_couple_member WHERE "coupleId" = c.id) = 2',
      parameters: QueryParameters.named({
        'recipient': row.recipientMemberId,
        'moment': row.momentId.toString(),
        'couple': row.coupleId.toString(),
      }),
    );
    return result.isNotEmpty;
  }

  Future<void> _revoke(Session session, PushDeviceRegistration registration) =>
      session.db.unsafeQuery(
        'UPDATE closecall_push_device_registration SET "revokedAt" = CURRENT_TIMESTAMP, '
        '"updatedAt" = CURRENT_TIMESTAMP WHERE "id" = @id AND "token" = @token '
        'AND "revokedAt" IS NULL',
        parameters: QueryParameters.named({
          'id': registration.id!,
          'token': registration.token,
        }),
      );

  Future<void> _complete(Session session, MomentEventOutbox row, String reason) =>
      session.db.unsafeQuery(
        'UPDATE closecall_moment_event_outbox SET "completedAt" = CURRENT_TIMESTAMP, '
        '"leasedUntil" = NULL, "leaseOwner" = NULL, "lastError" = @reason '
        'WHERE "id" = CAST(@id AS uuid) AND "leaseOwner" = @owner',
        parameters: QueryParameters.named({
          'id': row.id!.toString(),
          'owner': _owner,
          'reason': reason,
        }),
      );

  Future<void> _retryOrComplete(
    Session session,
    MomentEventOutbox row,
    String reason,
  ) async {
    if (row.attempts >= maxAttempts) {
      await _complete(session, row, 'max_attempts');
      return;
    }
    final seconds = min(
      baseBackoff.inSeconds * (1 << min(row.attempts - 1, 10)),
      maxBackoff.inSeconds,
    );
    await session.db.unsafeQuery(
      'UPDATE closecall_moment_event_outbox SET '
      '"availableAt" = CURRENT_TIMESTAMP + (@seconds * INTERVAL \'1 second\'), '
      '"leasedUntil" = NULL, "leaseOwner" = NULL, "lastError" = @reason '
      'WHERE "id" = CAST(@id AS uuid) AND "leaseOwner" = @owner',
      parameters: QueryParameters.named({
        'id': row.id!.toString(),
        'owner': _owner,
        'seconds': seconds,
        'reason': reason,
      }),
    );
  }
}

class MomentEventOutboxRunner {
  MomentEventOutboxRunner(this.dispatcher, {this.interval = const Duration(seconds: 15)});
  final MomentEventOutboxDispatcher dispatcher;
  final Duration interval;
  Timer? _timer;
  bool _running = false;

  void start(Serverpod pod) {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => _tick(pod));
    unawaited(_tick(pod));
  }

  Future<void> _tick(Serverpod pod) async {
    if (_running) return;
    _running = true;
    try {
      await dispatcher.reconcile(pod);
    } catch (_) {
      // Persisted rows remain available for the next bounded tick.
    } finally {
      _running = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

abstract final class MomentEventOutboxRuntime {
  static MomentEventOutboxDispatcher? dispatcher;

  static Future<void> kick(Serverpod pod) async {
    final current = dispatcher;
    if (current == null) return;
    try {
      await current.reconcile(pod, maxRows: 1);
    } catch (_) {}
  }
}
