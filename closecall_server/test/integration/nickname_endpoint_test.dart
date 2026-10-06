import 'package:closecall_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

Matcher failure(String code) =>
    isA<PairingFailure>().having((e) => e.code, 'code', code);

void main() {
  withServerpod(
    'Private nickname preferences',
    (sessionBuilder, endpoints) {
      TestSessionBuilder asUser(String id) => sessionBuilder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );

      setUp(() async {
        await Couple.db.deleteWhere(
          sessionBuilder.build(),
          where: (_) => Constant.bool(true),
        );
      });

      test('persists each member preference and scopes readback', () async {
        final pending = await endpoints.pairing.createCouple(asUser('alice'));
        await endpoints.pairing.joinByCode(asUser('bob'), pending.pairingCode!);

        final alice = await endpoints.pairing.updateNicknames(
          asUser('alice'),
          pending.coupleId,
          '  Alice  Smith ',
          ' My Partner ',
        );
        expect(alice.ownNickname, 'Alice Smith');
        expect(alice.partnerNickname, 'My Partner');

        final bobBefore = await endpoints.pairing.currentCouple(asUser('bob'));
        expect(bobBefore!.ownNickname, isNull);
        expect(bobBefore.partnerNickname, isNull);

        final bob = await endpoints.pairing.updateNicknames(
          asUser('bob'),
          pending.coupleId,
          ' Bob ',
          ' Alice ',
        );
        expect(bob.ownNickname, 'Bob');
        expect(bob.partnerNickname, 'Alice');
        final aliceAgain = await endpoints.pairing.currentCouple(
          asUser('alice'),
        );
        expect(aliceAgain!.ownNickname, 'Alice Smith');
        expect(aliceAgain.partnerNickname, 'My Partner');
      });

      test('rejects unauthenticated, unpaired, and invalid input', () async {
        await expectLater(
          endpoints.pairing.updateNicknames(
            sessionBuilder,
            '00000000-0000-0000-0000-000000000000',
            'A',
            'B',
          ),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
        await expectLater(
          endpoints.pairing.updateNicknames(
            asUser('alone'),
            '00000000-0000-0000-0000-000000000000',
            'A',
            'B',
          ),
          throwsA(failure('not_paired')),
        );
        final pending = await endpoints.pairing.createCouple(asUser('alice'));
        await endpoints.pairing.joinByCode(asUser('bob'), pending.pairingCode!);
        await expectLater(
          endpoints.pairing.updateNicknames(
            asUser('alice'),
            pending.coupleId,
            'A\nB',
            'C',
          ),
          throwsA(failure('invalid_nickname')),
        );
        await expectLater(
          endpoints.pairing.updateNicknames(
            asUser('alice'),
            pending.coupleId,
            '😀' * 41,
            'C',
          ),
          throwsA(failure('invalid_nickname')),
        );
        final cleared = await endpoints.pairing.updateNicknames(
          asUser('alice'),
          pending.coupleId,
          '',
          '',
        );
        expect(cleared.ownNickname, isNull);
        expect(cleared.partnerNickname, isNull);
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
  );
}
