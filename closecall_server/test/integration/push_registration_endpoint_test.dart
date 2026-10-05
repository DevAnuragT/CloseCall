import 'package:closecall_server/src/auth/authentication.dart';
import 'package:closecall_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Authenticated push registration', (sessionBuilder, endpoints) {
    TestSessionBuilder asUser(String id) => sessionBuilder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(id, {}),
    );

    setUp(() async {
      final session = sessionBuilder.build();
      configureAuthentication(session.serverpod);
      await Couple.db.deleteWhere(session, where: (_) => Constant.bool(true));
    });

    test('rejects unauthenticated, unpaired, and invalid tokens', () async {
      await expectLater(
        endpoints.push.registerDevice(
          sessionBuilder,
          token: 'opaque-token-12345678901234567890',
          deviceId: 'device',
        ),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
      await expectLater(
        endpoints.push.registerDevice(
          asUser('stranger'),
          token: 'opaque-token-12345678901234567890',
          deviceId: 'device',
        ),
        throwsA(isA<PushFailure>()),
      );
      await expectLater(
        endpoints.push.registerDevice(
          asUser('stranger'),
          token: '',
          deviceId: 'device',
        ),
        throwsA(isA<PushFailure>()),
      );
    });

    test('registers idempotently, rotates token, and revokes current device', () async {
      final pending = await endpoints.pairing.createCouple(asUser('alice'));
      await endpoints.pairing.joinByCode(asUser('bob'), pending.pairingCode!);
      await endpoints.push.registerDevice(
        asUser('alice'),
        token: 'opaque-token-12345678901234567890',
        deviceId: 'device',
        platform: 'android',
      );
      await endpoints.push.registerDevice(
        asUser('alice'),
        token: 'opaque-token-12345678901234567890',
        deviceId: 'device',
      );
      await endpoints.push.registerDevice(
        asUser('alice'),
        token: 'rotated-token-12345678901234567890',
        deviceId: 'device',
      );
      final session = sessionBuilder.build();
      expect(await PushDeviceRegistration.db.count(session), 1);
      final row = await PushDeviceRegistration.db.findFirstRow(session);
      expect(row?.token, 'rotated-token-12345678901234567890');
      expect(row?.revokedAt, isNull);
      await endpoints.push.revokeDevice(
        asUser('alice'),
        deviceId: 'device',
        token: 'rotated-token-12345678901234567890',
      );
      final revoked = await PushDeviceRegistration.db.findFirstRow(session);
      expect(revoked?.revokedAt, isNotNull);
    });
  });
}
