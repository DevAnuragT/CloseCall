import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:closecall_shared/closecall_shared.dart';
import 'package:crypto/crypto.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'widget_timeline_service.dart' show parseScheduleUuid;

PushFailure _denied() => PushFailure(code: 'unauthorized_widget_device');

class WidgetDeviceService {
  static const lifetime = Duration(hours: 24);
  static const maxPhotos = 12;
  static const maxSchedules = 100;
  static const _empty = '\u0000closecall/no-widget-fallback';
  static const _readCommitted = TransactionSettings(
    isolationLevel: IsolationLevel.readCommitted,
  );

  void _validateDevice(String device) {
    if (device.isEmpty ||
        device.length > 128 ||
        RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(device)) {
      throw PushFailure(code: 'invalid_device');
    }
  }

  Future<void> _deviceLock(
    Session session,
    String user,
    String device,
    Transaction transaction, {
    bool shared = false,
  }) async {
    await session.db.unsafeQuery(
      'SELECT ${shared ? 'pg_advisory_xact_lock_shared' : 'pg_advisory_xact_lock'}'
      '(hashtextextended(@identity, 0))',
      parameters: QueryParameters.named({
        'identity': 'closecall/widget-device/${jsonEncode([user, device])}',
      }),
      transaction: transaction,
    );
  }

  Future<WidgetDeviceCredential> issue(
    Session session,
    String user,
    String device,
  ) async {
    _validateDevice(device);
    return session.db.transaction((transaction) async {
      await _deviceLock(session, user, device, transaction);
      final member = await CoupleMember.db.findFirstRow(
        session,
        where: (t) => t.userIdentifier.equals(user),
        transaction: transaction,
      );
      if (member == null) throw _denied();
      await _scope(session, member.coupleId, member.id!, user, transaction);
      final random = Random.secure();
      final secret = base64Url
          .encode(List<int>.generate(32, (_) => random.nextInt(256)))
          .replaceAll('=', '');
      final now = clock.now().toUtc();
      await WidgetDeviceCredentialRecord.db.deleteWhere(
        session,
        where: (t) => t.userIdentifier.equals(user) & t.deviceId.equals(device),
        transaction: transaction,
      );
      final expires = now.add(lifetime);
      await WidgetDeviceCredentialRecord.db.insertRow(
        session,
        WidgetDeviceCredentialRecord(
          coupleId: member.coupleId,
          memberId: member.id!,
          userIdentifier: user,
          deviceId: device,
          credentialHash: _hash(secret),
          createdAt: now,
          expiresAt: expires,
        ),
        transaction: transaction,
      );
      return WidgetDeviceCredential(
        credential: secret,
        deviceId: device,
        userId: user,
        coupleId: member.coupleId.toString(),
        expiresAt: expires,
      );
    }, settings: _readCommitted);
  }

  Future<void> revoke(Session session, String user, String device) async {
    _validateDevice(device);
    await session.db.transaction(
      (transaction) => revokeInTransaction(session, user, device, transaction),
      settings: _readCommitted,
    );
  }

  // No consent or completed-pair requirement: opt-out must never prevent
  // explicit widget-read revocation. FCM transport has an independent lifecycle.
  Future<void> revokeInTransaction(
    Session session,
    String user,
    String device,
    Transaction transaction,
  ) async {
    await _deviceLock(session, user, device, transaction);
    await WidgetDeviceCredentialRecord.db.deleteWhere(
      session,
      where: (t) => t.userIdentifier.equals(user) & t.deviceId.equals(device),
      transaction: transaction,
    );
  }

  String _hash(String secret) => sha256.convert(utf8.encode(secret)).toString();

  Future<WidgetDeviceCredentialRecord> _authorize(
    Session session,
    String secret,
    Transaction transaction,
  ) async {
    // Enforce canonical encoding and bounded input before any database lookup.
    if (!RegExp(r'^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$').hasMatch(secret)) {
      throw _denied();
    }
    final hash = _hash(secret);
    final found = await WidgetDeviceCredentialRecord.db.findFirstRow(
      session,
      where: (t) => t.credentialHash.equals(hash),
      transaction: transaction,
    );
    if (found == null) throw _denied();
    // Use READ COMMITTED, not a stale repeatable-read snapshot after waiting for
    // a concurrent rotation. Every lookup below sees the latest commit.
    await _deviceLock(
      session,
      found.userIdentifier,
      found.deviceId,
      transaction,
      shared: true,
    );
    // Lock membership before the credential row, matching cascade deletion's
    // parent-before-child order and avoiding a membership-delete deadlock.
    await _scope(
      session,
      found.coupleId,
      found.memberId,
      found.userIdentifier,
      transaction,
    );
    await session.db.unsafeQuery(
      'SELECT "id" FROM closecall_widget_device_credential '
      'WHERE "credentialHash" = @hash FOR SHARE',
      parameters: QueryParameters.named({'hash': hash}),
      transaction: transaction,
    );
    final current = await WidgetDeviceCredentialRecord.db.findFirstRow(
      session,
      where: (t) => t.credentialHash.equals(hash),
      transaction: transaction,
    );
    if (current == null || !current.expiresAt.isAfter(clock.now().toUtc())) {
      throw _denied();
    }
    await _scope(
      session,
      current.coupleId,
      current.memberId,
      current.userIdentifier,
      transaction,
    );
    return current;
  }

  Future<
    ({CoupleMember member, CoupleMember partner, WidgetDeliveryRecord delivery})
  >
  _scope(
    Session session,
    UuidValue coupleId,
    int memberId,
    String user,
    Transaction transaction,
  ) async {
    // Scheduling, sends, fallback and consent mutations all take the exclusive
    // version of this same lock. Share it for the entire read/retrieval.
    await session.db.unsafeQuery(
      'SELECT pg_advisory_xact_lock_shared(hashtextextended(@identity, 0))',
      parameters: QueryParameters.named({
        'identity': 'closecall/widget/couple/$coupleId',
      }),
      transaction: transaction,
    );
    // Row locks additionally protect membership/couple changes and direct
    // consent updates, including cascading deletes, until the result commits.
    for (final sql in [
      'SELECT "id" FROM closecall_couple WHERE "id" = CAST(@couple AS uuid) FOR SHARE',
      'SELECT "id" FROM closecall_couple_member WHERE "coupleId" = CAST(@couple AS uuid) ORDER BY "id" FOR SHARE',
      'SELECT "id" FROM closecall_widget_delivery WHERE "coupleId" = CAST(@couple AS uuid) FOR SHARE',
    ]) {
      await session.db.unsafeQuery(
        sql,
        parameters: QueryParameters.named({'couple': coupleId.toString()}),
        transaction: transaction,
      );
    }
    final couple = await Couple.db.findById(
      session,
      coupleId,
      transaction: transaction,
    );
    final members = await CoupleMember.db.find(
      session,
      where: (t) => t.coupleId.equals(coupleId),
      transaction: transaction,
    );
    final current = members.where(
      (m) => m.id == memberId && m.userIdentifier == user,
    );
    if (couple == null ||
        couple.pairingCode != null ||
        members.length != 2 ||
        current.length != 1) {
      throw _denied();
    }
    final delivery = await WidgetDeliveryRecord.db.findFirstRow(
      session,
      where: (t) =>
          t.coupleId.equals(coupleId) & t.recipientMemberId.equals(memberId),
      transaction: transaction,
    );
    if (delivery == null || !delivery.autoUpdateEnabled) throw _denied();
    return (
      member: current.single,
      partner: members.singleWhere((m) => m.id != memberId),
      delivery: delivery,
    );
  }

  Future<WidgetTimeline> timeline(Session session, String secret) =>
      session.db.transaction((transaction) async {
        final credential = await _authorize(session, secret, transaction);
        final result = await _timeline(session, credential, transaction);
        if (!credential.expiresAt.isAfter(clock.now().toUtc())) throw _denied();
        return result;
      }, settings: _readCommitted);

  Future<ByteData> download(Session session, String secret, String assetId) =>
      session.db.transaction((transaction) async {
        final credential = await _authorize(session, secret, transaction);
        final id = parseScheduleUuid(assetId);
        if (id == null) throw _denied();
        final timeline = await _timeline(session, credential, transaction);
        if (!_assets(timeline).contains(id.toString())) throw _denied();
        await session.db.unsafeQuery(
          'SELECT "id" FROM closecall_media WHERE "id" = CAST(@asset AS uuid) '
          'AND "coupleId" = CAST(@couple AS uuid) FOR SHARE',
          parameters: QueryParameters.named({
            'asset': id.toString(),
            'couple': credential.coupleId.toString(),
          }),
          transaction: transaction,
        );
        final media = await MediaRecord.db.findFirstRow(
          session,
          where: (t) =>
              t.id.equals(id) & t.coupleId.equals(credential.coupleId),
          transaction: transaction,
        );
        if (media == null) throw _denied();
        ByteData bytes;
        try {
          bytes = await session.serverpod.storage['private']!.retrieveFile(
            session: session,
            path: media.storagePath,
          );
        } on CloudStorageFileNotFoundException {
          throw _denied();
        }
        // Retrieval can cross an expiry/schedule boundary. Re-authorize current
        // truth and recompute the allowlist before releasing any private bytes.
        await _authorize(session, secret, transaction);
        final refreshed = await _timeline(session, credential, transaction);
        if (!_assets(refreshed).contains(id.toString()) ||
            !credential.expiresAt.isAfter(clock.now().toUtc())) {
          throw _denied();
        }
        return bytes;
      }, settings: _readCommitted);

  Set<String> _assets(WidgetTimeline timeline) => {
    ...timeline.schedules.map((e) => e.assetId),
    if (timeline.currentAssetId != null) timeline.currentAssetId!,
    if (timeline.latestAssetId != null) timeline.latestAssetId!,
    if (timeline.fallbackAssetId != null) timeline.fallbackAssetId!,
  };

  Future<WidgetTimeline> _timeline(
    Session session,
    WidgetDeviceCredentialRecord credential,
    Transaction transaction,
  ) async {
    final scope = await _scope(
      session,
      credential.coupleId,
      credential.memberId,
      credential.userIdentifier,
      transaction,
    );
    final now = clock.now().toUtc();
    final horizon = now.add(lifetime);
    final until = credential.expiresAt.isBefore(horizon)
        ? credential.expiresAt
        : horizon;
    if (!until.isAfter(now)) throw _denied();
    final rows = await WidgetScheduleRecord.db.find(
      session,
      where: (t) =>
          t.coupleId.equals(credential.coupleId) &
          t.recipientMemberId.equals(credential.memberId) &
          t.cancelledAt.equals(null) &
          (t.activeUntil > now) &
          (t.activeFrom < until),
      limit: maxSchedules + 1,
      transaction: transaction,
    );
    if (rows.length > maxSchedules) throw _denied();
    final fallback = await WidgetFallbackRecord.db.findFirstRow(
      session,
      where: (t) =>
          t.coupleId.equals(credential.coupleId) &
          t.recipientMemberId.equals(credential.memberId),
      transaction: transaction,
    );
    final baseline =
        scope.delivery.assetId?.toString() ??
        fallback?.assetId.toString() ??
        _empty;
    final schedules = rows
        .map(
          (r) => WidgetSchedule(
            id: r.id!.toString(),
            assetId: r.assetId.toString(),
            activeFrom: r.activeFrom.toUtc(),
            activeUntil: r.activeUntil.toUtc(),
            createdAt: r.createdAt.toUtc(),
          ),
        )
        .toList();
    WidgetResolution at(DateTime time) => WidgetScheduleResolver.resolve(
      now: time,
      schedules: schedules,
      fallbackAssetId: baseline,
    );
    final boundaries = <DateTime>{now};
    for (final s in schedules) {
      if (s.activeFrom.isAfter(now) && s.activeFrom.isBefore(until)) {
        boundaries.add(s.activeFrom);
      }
      if (s.activeUntil.isAfter(now) && s.activeUntil.isBefore(until)) {
        boundaries.add(s.activeUntil);
      }
    }
    final winners = <String>{};
    final assets = <String>{};
    var baselineVisible = false;
    for (final boundary in boundaries) {
      final resolution = at(boundary);
      if (resolution.assetId != _empty) assets.add(resolution.assetId);
      final winner = resolution.activeSchedule;
      if (winner == null) {
        baselineVisible = true;
      } else {
        winners.add(winner.id);
      }
    }
    if (assets.length > maxPhotos) throw _denied();
    final current = at(now);
    final entries =
        rows
            .where((r) => winners.contains(r.id!.toString()))
            .map(
              (r) => WidgetScheduleEntry(
                scheduleId: r.id!.toString(),
                assetId: r.assetId.toString(),
                senderId: scope.partner.userIdentifier,
                recipientId: scope.member.userIdentifier,
                activeFrom: r.activeFrom.isBefore(now)
                    ? now
                    : r.activeFrom.toUtc(),
                activeUntil: r.activeUntil.isAfter(until)
                    ? until
                    : r.activeUntil.toUtc(),
                createdAt: r.createdAt.toUtc(),
              ),
            )
            .toList()
          ..sort((a, b) {
            final time = a.createdAt.compareTo(b.createdAt);
            return time == 0 ? a.scheduleId.compareTo(b.scheduleId) : time;
          });
    return WidgetTimeline(
      coupleId: credential.coupleId.toString(),
      recipientId: credential.userIdentifier,
      // Neither the overridden personal fallback nor any fully masked schedule
      // is a readable background asset. Only actual horizon winners are exposed.
      fallbackAssetId: baselineVisible && scope.delivery.assetId == null
          ? fallback?.assetId.toString()
          : null,
      latestAssetId: baselineVisible
          ? scope.delivery.assetId?.toString()
          : null,
      deliveryVersion: scope.delivery.version,
      autoUpdateEnabled: true,
      currentAssetId: current.assetId == _empty ? null : current.assetId,
      nextTransition:
          current.nextTransition != null &&
              current.nextTransition!.isBefore(until)
          ? current.nextTransition
          : null,
      schedules: entries,
      serverTime: now,
    );
  }
}
