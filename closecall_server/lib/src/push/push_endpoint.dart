import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Registers an FCM installation for later opaque wake dispatch. Tokens are
/// server-only credentials: this endpoint never returns one or logs one.
class PushEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<void> registerDevice(
    Session session, {
    required String token,
    required String deviceId,
    String? platform,
    String? appVersion,
  }) async {
    _validate(token, deviceId, platform, appVersion);
    final user = session.authenticated!.userIdentifier;
    await session.db.transaction((transaction) async {
      final member = await CoupleMember.db.findFirstRow(
        session,
        where: (t) => t.userIdentifier.equals(user),
        transaction: transaction,
      );
      if (member == null || member.id == null) {
        throw PushFailure(code: 'not_paired');
      }
      if (await CoupleMember.db.count(
                session,
                where: (t) => t.coupleId.equals(member.coupleId),
                transaction: transaction,
              ) !=
              2) {
        throw PushFailure(code: 'not_paired');
      }

      // Serialize rotations for one authenticated installation across pods.
      await session.db.unsafeQuery(
        'SELECT pg_advisory_xact_lock(hashtextextended(@identity, 0))',
        parameters: QueryParameters.named({
          'identity': 'closecall/push/$user/$deviceId',
        }),
        transaction: transaction,
      );

      // A device has one active token. Removing its old token makes token
      // rotation compatible with the all-record unique token constraint.
      await session.db.unsafeQuery(
        'DELETE FROM closecall_push_device_registration '
        'WHERE "memberId" = @member AND "deviceId" = @device',
        parameters: QueryParameters.named({
          'member': member.id!,
          'device': deviceId,
        }),
        transaction: transaction,
      );
      // A token can move when the platform rotates/reuses an installation;
      // the authenticated registration becomes its sole current owner.
      await session.db.unsafeQuery(
        'INSERT INTO closecall_push_device_registration '
        '("coupleId", "memberId", "deviceId", "token", "platform", '
        '"appVersion", "updatedAt", "revokedAt") '
        'VALUES (CAST(@couple AS uuid), @member, @device, @token, @platform, @version, '
        'CURRENT_TIMESTAMP, NULL) '
        'ON CONFLICT ("token") DO UPDATE SET '
        '"coupleId" = EXCLUDED."coupleId", '
        '"memberId" = EXCLUDED."memberId", '
        '"deviceId" = EXCLUDED."deviceId", '
        '"platform" = EXCLUDED."platform", '
        '"appVersion" = EXCLUDED."appVersion", '
        '"updatedAt" = CURRENT_TIMESTAMP, "revokedAt" = NULL',
        parameters: QueryParameters.named({
          'couple': member.coupleId.toString(),
          'member': member.id!,
          'device': deviceId,
          'token': token,
          'platform': platform,
          'version': appVersion,
        }),
        transaction: transaction,
      );
    });
  }

  Future<void> revokeDevice(
    Session session, {
    required String deviceId,
    required String token,
  }) async {
    if (deviceId.isEmpty || deviceId.length > 128) {
      throw PushFailure(code: 'invalid_device');
    }
    final user = session.authenticated!.userIdentifier;
    await session.db.transaction((transaction) async {
      final member = await CoupleMember.db.findFirstRow(
        session,
        where: (t) => t.userIdentifier.equals(user),
        transaction: transaction,
      );
      if (member == null || member.id == null) {
        throw PushFailure(code: 'not_paired');
      }
      await session.db.unsafeQuery(
        'UPDATE closecall_push_device_registration '
        'SET "revokedAt" = CURRENT_TIMESTAMP, "updatedAt" = CURRENT_TIMESTAMP '
        'WHERE "memberId" = @member AND "deviceId" = @device '
        'AND "token" = @token '
        'AND "revokedAt" IS NULL',
        parameters: QueryParameters.named({
          'member': member.id!,
          'device': deviceId,
          'token': token,
        }),
        transaction: transaction,
      );
    });
  }

  void _validate(
    String token,
    String deviceId,
    String? platform,
    String? appVersion,
  ) {
    // FCM token length is intentionally bounded without assuming a token
    // format; values are never included in failures or logs.
    if (token.length < 20 || token.length > 4096 ||
        RegExp(r'\s').hasMatch(token)) {
      throw PushFailure(code: 'invalid_token');
    }
    if (deviceId.isEmpty || deviceId.length > 128) {
      throw PushFailure(code: 'invalid_device');
    }
    if (platform != null && (platform.isEmpty || platform.length > 32)) {
      throw PushFailure(code: 'invalid_device');
    }
    if (appVersion != null && appVersion.length > 64) {
      throw PushFailure(code: 'invalid_device');
    }
  }
}
