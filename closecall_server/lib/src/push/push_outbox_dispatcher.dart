import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'fcm_sender.dart';

/// A bounded, PostgreSQL-leased reconciler. Rows remain durable when a pod is
/// restarted or FCM is unavailable; a later runner tick or send-triggered kick
/// can claim them again.
class PushOutboxDispatcher {
  PushOutboxDispatcher({
    required this.sender,
    this.maxAttempts = 8,
    this.batchSize = 10,
    this.leaseDuration = const Duration(seconds: 30),
    this.baseBackoff = const Duration(seconds: 5),
    this.maxBackoff = const Duration(minutes: 10),
    String? owner,
  }) : _owner = owner ?? const Uuid().v4();

  final FcmSender sender;
  final int maxAttempts;
  final int batchSize;
  final Duration leaseDuration;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final String _owner;

  /// Processes at most [maxRows] events in this invocation. This bound is
  /// intentional for Cloud Starter request/resource limits.
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
          // A lease must never strand a row. The error category is deliberately
          // fixed so secrets, tokens, and response bytes cannot reach logs.
          await _retryOrComplete(session, row, 'dispatcher_error');
        }
      }
      return processed;
    }, enableLogging: false);
  }

  Future<PushOutbox?> _claim(Session session) async {
    return session.db.transaction((transaction) async {
      final rows = await session.db.unsafeQuery(
        'SELECT "id"::text FROM closecall_push_outbox '
        'WHERE "completedAt" IS NULL '
        'AND "availableAt" <= CURRENT_TIMESTAMP '
        'AND ("leasedUntil" IS NULL OR "leasedUntil" < CURRENT_TIMESTAMP) '
        'AND "attempts" < @maxAttempts '
        'ORDER BY "createdAt", "id" '
        'FOR UPDATE SKIP LOCKED LIMIT 1',
        parameters: QueryParameters.named({'maxAttempts': maxAttempts}),
        transaction: transaction,
      );
      if (rows.isEmpty) return null;
      final id = UuidValue.fromString(rows.first.first as String);
      final row = (await PushOutbox.db.findById(
        session,
        id,
        transaction: transaction,
      ))!;
      row.attempts += 1;
      row.leasedUntil = clock.now().toUtc().add(leaseDuration);
      row.leaseOwner = _owner;
      await PushOutbox.db.updateRow(session, row, transaction: transaction);
      return row;
    });
  }

  Future<void> _dispatch(Session session, PushOutbox row) async {
    final delivery = await WidgetDeliveryRecord.db.findFirstRow(
      session,
      where: (t) =>
          t.coupleId.equals(row.coupleId) &
          t.recipientMemberId.equals(row.recipientMemberId),
    );
    if (delivery == null ||
        !delivery.autoUpdateEnabled ||
        delivery.version > row.version) {
      await _complete(
        session,
        row,
        delivery == null
            ? 'consent_missing'
            : delivery.autoUpdateEnabled
            ? 'obsolete'
            : 'consent_revoked',
      );
      return;
    }

    final registrations = await PushDeviceRegistration.db.find(
      session,
      where: (t) =>
          t.coupleId.equals(row.coupleId) &
          t.memberId.equals(row.recipientMemberId) &
          t.revokedAt.equals(null),
    );
    // No installed device is not a delivery failure. The recipient's next
    // foreground reconciliation reads current truth instead of replaying this
    // old hint if a device registers later.
    if (registrations.isEmpty) {
      await _complete(session, row, 'no_active_registration');
      return;
    }

    var transient = false;
    for (final registration in registrations) {
      final result = await sender.send(
        token: registration.token,
        version: row.version,
      );
      switch (result.status) {
        case FcmSendStatus.sent:
          break;
        case FcmSendStatus.invalidToken:
          await _revoke(session, registration);
        case FcmSendStatus.transientFailure:
          transient = true;
        case FcmSendStatus.permanentFailure:
          // Keep attempting other devices, then terminally retain a bounded
          // diagnostic category rather than response content.
          transient = true;
      }
    }
    if (transient) {
      await _retryOrComplete(session, row, 'fcm_retry');
    } else {
      await _complete(session, row, 'sent');
    }
  }

  Future<void> _revoke(Session session, PushDeviceRegistration registration) {
    return session.db.unsafeQuery(
      'UPDATE closecall_push_device_registration '
      'SET "revokedAt" = CURRENT_TIMESTAMP, "updatedAt" = CURRENT_TIMESTAMP '
      'WHERE "id" = @id AND "token" = @token AND "revokedAt" IS NULL',
      parameters: QueryParameters.named({
        'id': registration.id!,
        'token': registration.token,
      }),
    );
  }

  Future<void> _complete(Session session, PushOutbox row, String reason) async {
    await session.db.unsafeQuery(
      'UPDATE closecall_push_outbox SET '
      '"completedAt" = CURRENT_TIMESTAMP, "leasedUntil" = NULL, '
      '"leaseOwner" = NULL, "lastError" = @reason '
      'WHERE "id" = CAST(@id AS uuid) AND "leaseOwner" = @owner',
      parameters: QueryParameters.named({
        'id': row.id!.toString(),
        'owner': _owner,
        'reason': reason,
      }),
    );
  }

  Future<void> _retryOrComplete(
    Session session,
    PushOutbox row,
    String reason,
  ) async {
    if (row.attempts >= maxAttempts) {
      await _complete(session, row, 'max_attempts');
      return;
    }
    final multiplier = 1 << min(row.attempts - 1, 10);
    final seconds = min(
      baseBackoff.inSeconds * multiplier,
      maxBackoff.inSeconds,
    );
    await session.db.unsafeQuery(
      'UPDATE closecall_push_outbox SET '
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

/// Owns the best-effort in-process trigger. Durable rows and PostgreSQL leases
/// are the source of truth; this timer is only a bounded wake-up mechanism.
class PushOutboxRunner {
  PushOutboxRunner(
    this.dispatcher, {
    this.interval = const Duration(seconds: 15),
  });

  final PushOutboxDispatcher dispatcher;
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
      // The next bounded tick will retry persisted rows.
    } finally {
      _running = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Runtime hook used by committed send requests. It is intentionally not an
/// endpoint: no public or unauthenticated trigger can cause FCM dispatch.
abstract final class PushOutboxRuntime {
  static PushOutboxDispatcher? dispatcher;

  static Future<void> kick(Serverpod pod) async {
    final current = dispatcher;
    if (current == null) return;
    try {
      await current.reconcile(pod, maxRows: 1);
    } catch (_) {
      // Persistence and the periodic runner provide recovery.
    }
  }
}
