import 'package:closecall_server/src/auth/authentication.dart';
import 'package:closecall_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    'Couple-scoped current moods',
    (builder, endpoints) {
      TestSessionBuilder asUser(String id) => builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );

      setUp(() async {
        final session = builder.build();
        configureAuthentication(session.serverpod);
        await Couple.db.deleteWhere(session, where: (_) => Constant.bool(true));
      });

      test('unpaired users cannot read or write a mood', () async {
        await expectLater(
          endpoints.mood.current(asUser('alice')),
          throwsA(
            isA<MoodFailure>().having((e) => e.code, 'code', 'not_paired'),
          ),
        );
        await expectLater(
          endpoints.mood.setMood(asUser('alice'), 'happy'),
          throwsA(
            isA<MoodFailure>().having((e) => e.code, 'code', 'not_paired'),
          ),
        );
      });

      test(
        'paired members persist their own mood and read their partner',
        () async {
          final pending = await endpoints.pairing.createCouple(asUser('alice'));
          await endpoints.pairing.joinByCode(
            asUser('bob'),
            pending.pairingCode!,
          );

          final initial = await endpoints.mood.current(asUser('alice'));
          expect(initial.ownMood, isNull);
          expect(initial.partnerMood, isNull);
          expect(initial.partnerUserId, 'bob');

          final saved = await endpoints.mood.setMood(asUser('alice'), 'happy');
          expect(saved.ownMood, 'happy');
          expect(saved.ownUpdatedAt, isNotNull);
          expect(saved.partnerMood, isNull);

          final bobView = await endpoints.mood.current(asUser('bob'));
          expect(bobView.ownMood, isNull);
          expect(bobView.partnerUserId, 'alice');
          expect(bobView.partnerMood, 'happy');
          expect(bobView.partnerUpdatedAt, saved.ownUpdatedAt);
        },
      );

      test('only the bounded mood keys are accepted', () async {
        final pending = await endpoints.pairing.createCouple(asUser('alice'));
        await endpoints.pairing.joinByCode(asUser('bob'), pending.pairingCode!);
        await expectLater(
          endpoints.mood.setMood(asUser('alice'), 'angry'),
          throwsA(
            isA<MoodFailure>().having((e) => e.code, 'code', 'invalid_mood'),
          ),
        );
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
  );
}
