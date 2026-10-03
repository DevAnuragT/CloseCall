import 'package:closecall_server/src/auth/authentication.dart';
import 'package:closecall_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

Matcher failure(String code) =>
    isA<PairingFailure>().having((e) => e.code, 'code', code);

void main() {
  withServerpod(
    'Persistent authenticated pairing',
    (sessionBuilder, endpoints) {
      TestSessionBuilder asUser(String id) => sessionBuilder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );

      setUp(() async {
        final session = sessionBuilder.build();
        configureAuthentication(session.serverpod);
        // These tests deliberately commit transactions, giving competing calls
        // separate connections and real PostgreSQL lock/commit behavior.
        await Couple.db.deleteWhere(session, where: (_) => Constant.bool(true));
      });

      test('all pairing methods reject an unauthenticated session', () async {
        await expectLater(
          endpoints.pairing.createCouple(sessionBuilder),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
        await expectLater(
          endpoints.pairing.joinByCode(sessionBuilder, 'ABC234'),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
        await expectLater(
          endpoints.pairing.currentCouple(sessionBuilder),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
      });

      test(
        'anonymous login persists an identity and issues verifiable JWTs',
        () async {
          final first = await endpoints.anonymousIdp.login(sessionBuilder);
          final second = await endpoints.anonymousIdp.login(sessionBuilder);
          final session = sessionBuilder.build();
          final auth = await session.serverpod.authenticationHandler!(
            session,
            first.token,
          );
          expect(auth, isNotNull);
          expect(auth!.userIdentifier, first.authUserId.toString());
          expect(second.authUserId, isNot(first.authUserId));
          expect(first.refreshToken, isNotNull);
          expect(
            await session.serverpod.authenticationHandler!(session, 'invalid'),
            isNull,
          );

          final authenticated = asUser(auth.userIdentifier);
          final state = await endpoints.pairing.createCouple(authenticated);
          expect(state.memberIds, [first.authUserId.toString()]);
          expect(
            await endpoints.pairing.currentCouple(
              asUser(second.authUserId.toString()),
            ),
            isNull,
          );
        },
      );

      test(
        'pending creation is idempotent and isolated to the current user',
        () async {
          final alice = asUser('alice');
          expect(await endpoints.pairing.currentCouple(alice), isNull);
          final first = await endpoints.pairing.createCouple(alice);
          final again = await endpoints.pairing.createCouple(alice);
          expect(again.coupleId, first.coupleId);
          expect(again.pairingCode, first.pairingCode);
          expect(first.memberIds, ['alice']);
          expect(first.themeKey, 'blush');
          expect(first.partnerNickname, isNull);
          expect(first.anniversary, isNull);
          expect(await endpoints.pairing.currentCouple(asUser('bob')), isNull);
          expect(await Couple.db.count(sessionBuilder.build()), 1);
        },
      );

      test(
        'join normalizes, consumes the invite, and survives new sessions',
        () async {
          final pending = await endpoints.pairing.createCouple(asUser('alice'));
          final code = pending.pairingCode!;
          final joined = await endpoints.pairing.joinByCode(
            asUser('bob'),
            ' ${code.substring(0, 3).toLowerCase()}-${code.substring(3).toLowerCase()} ',
          );
          expect(joined.coupleId, pending.coupleId);
          expect(joined.memberIds, ['alice', 'bob']);
          expect(joined.pairingCode, isNull);
          final aliceState = await endpoints.pairing.currentCouple(
            asUser('alice'),
          );
          final bobState = await endpoints.pairing.currentCouple(asUser('bob'));
          expect(aliceState!.memberIds, joined.memberIds);
          expect(bobState!.coupleId, joined.coupleId);
          expect(aliceState.pairingCode, isNull);
          await expectLater(
            endpoints.pairing.joinByCode(asUser('charlie'), code),
            throwsA(failure('code_not_found')),
          );
          await expectLater(
            endpoints.pairing.createCouple(asUser('bob')),
            throwsA(failure('already_paired')),
          );
        },
      );

      test(
        'malformed, missing, self and already-paired invites are rejected',
        () async {
          await expectLater(
            endpoints.pairing.joinByCode(asUser('alice'), 'ABC0IL'),
            throwsA(failure('invalid_code')),
          );
          await expectLater(
            endpoints.pairing.joinByCode(asUser('alice'), 'ABC234'),
            throwsA(failure('code_not_found')),
          );
          final alice = await endpoints.pairing.createCouple(asUser('alice'));
          final bob = await endpoints.pairing.createCouple(asUser('bob'));
          await expectLater(
            endpoints.pairing.joinByCode(asUser('alice'), alice.pairingCode!),
            throwsA(failure('cannot_pair_with_self')),
          );
          await expectLater(
            endpoints.pairing.joinByCode(asUser('alice'), bob.pairingCode!),
            throwsA(failure('already_paired')),
          );
          expect(await CoupleMember.db.count(sessionBuilder.build()), 2);
        },
      );

      test(
        'database constraints enforce one couple per user and at most two slots',
        () async {
          final first = await endpoints.pairing.createCouple(asUser('alice'));
          final second = await endpoints.pairing.createCouple(
            asUser('charlie'),
          );
          final session = sessionBuilder.build();
          final firstId = UuidValue.fromString(first.coupleId);
          await expectLater(
            Couple.db.insertRow(
              session,
              Couple(pairingCode: first.pairingCode),
            ),
            throwsA(
              isA<DatabaseUniqueViolationException>().having(
                (e) => e.constraintName,
                'constraintName',
                'closecall_couple_pairing_code_unique',
              ),
            ),
          );
          await expectLater(
            CoupleMember.db.insertRow(
              session,
              CoupleMember(
                coupleId: UuidValue.fromString(second.coupleId),
                userIdentifier: 'alice',
                creatorSlot: false,
              ),
            ),
            throwsA(isA<DatabaseUniqueViolationException>()),
          );
          await endpoints.pairing.joinByCode(asUser('bob'), first.pairingCode!);
          for (final slot in [false, true]) {
            await expectLater(
              CoupleMember.db.insertRow(
                session,
                CoupleMember(
                  coupleId: firstId,
                  userIdentifier: 'dave',
                  creatorSlot: slot,
                ),
              ),
              throwsA(isA<DatabaseUniqueViolationException>()),
            );
          }
          expect(
            await CoupleMember.db.count(
              session,
              where: (t) => t.coupleId.equals(firstId),
            ),
            2,
          );
        },
      );

      test(
        'concurrent pending creates produce one couple and one stable code',
        () async {
          final results = await Future.wait(
            List.generate(
              8,
              (_) => endpoints.pairing.createCouple(asUser('alice')),
            ),
          );
          expect(results.map((state) => state.coupleId).toSet(), hasLength(1));
          expect(
            results.map((state) => state.pairingCode).toSet(),
            hasLength(1),
          );
          expect(await Couple.db.count(sessionBuilder.build()), 1);
          expect(await CoupleMember.db.count(sessionBuilder.build()), 1);
        },
      );

      test(
        'concurrent joins have exactly one winner and consume the code',
        () async {
          final pending = await endpoints.pairing.createCouple(asUser('alice'));
          Future<Object> join(String user) async {
            try {
              return await endpoints.pairing.joinByCode(
                asUser(user),
                pending.pairingCode!,
              );
            } on PairingFailure catch (error) {
              return error;
            }
          }

          final results = await Future.wait([
            join('bob'),
            join('charlie'),
            join('dave'),
          ]);
          expect(results.whereType<PairingState>(), hasLength(1));
          expect(
            results.whereType<PairingFailure>().map((e) => e.code),
            everyElement('code_not_found'),
          );
          final state = await endpoints.pairing.currentCouple(asUser('alice'));
          expect(state!.memberIds, hasLength(2));
          expect(state.pairingCode, isNull);
          expect(await CoupleMember.db.count(sessionBuilder.build()), 2);
        },
      );

      test(
        'owner create racing with redemption never returns a mixed snapshot',
        () async {
          final pending = await endpoints.pairing.createCouple(asUser('alice'));
          Future<Object> create() async {
            try {
              return await endpoints.pairing.createCouple(asUser('alice'));
            } on PairingFailure catch (error) {
              return error;
            }
          }

          final results = await Future.wait<Object>([
            ...List.generate(8, (_) => create()),
            endpoints.pairing.joinByCode(asUser('bob'), pending.pairingCode!),
          ]);
          for (final state in results.whereType<PairingState>()) {
            expect(state.pairingCode == null, state.memberIds.length == 2);
          }
          expect(
            results.whereType<PairingFailure>().map((e) => e.code),
            everyElement('already_paired'),
          );
          final state = await endpoints.pairing.currentCouple(asUser('alice'));
          expect(state!.memberIds, ['alice', 'bob']);
        },
      );

      test(
        'one user racing to join two couples acquires only one membership',
        () async {
          final alice = await endpoints.pairing.createCouple(asUser('alice'));
          final charlie = await endpoints.pairing.createCouple(
            asUser('charlie'),
          );
          Future<Object> join(String code) async {
            try {
              return await endpoints.pairing.joinByCode(asUser('bob'), code);
            } on PairingFailure catch (error) {
              return error;
            }
          }

          final results = await Future.wait([
            join(alice.pairingCode!),
            join(charlie.pairingCode!),
          ]);
          expect(results.whereType<PairingState>(), hasLength(1));
          expect(
            results.whereType<PairingFailure>().single.code,
            'already_paired',
          );
          expect(
            await CoupleMember.db.count(
              sessionBuilder.build(),
              where: (t) => t.userIdentifier.equals('bob'),
            ),
            1,
          );
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
  );
}
