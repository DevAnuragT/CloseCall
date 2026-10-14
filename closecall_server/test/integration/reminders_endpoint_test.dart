import 'package:closecall_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

Matcher failure(String code) =>
    isA<ReminderFailure>().having((error) => error.code, 'code', code);

void main() {
  withServerpod(
    'Reminder partner event outbox',
    (builder, endpoints) {
      TestSessionBuilder asUser(String id) => builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );
      Future<PairingState> pair() async {
        final pending = await endpoints.pairing.createCouple(asUser('alice'));
        return endpoints.pairing.joinByCode(
          asUser('bob'),
          pending.pairingCode!,
        );
      }

      setUp(() async {
        await Couple.db.deleteWhere(
          builder.build(),
          where: (_) => Constant.bool(true),
        );
      });

      test(
        'creates one opaque partner event and idempotent retries do not duplicate',
        () async {
          final paired = await pair();
          final requestId = Uuid().v4();
          final remindAt = DateTime.now().toUtc().add(const Duration(hours: 1));
          final entries = await Future.wait(
            List.generate(
              6,
              (_) => endpoints.reminders.createReminder(
                asUser('alice'),
                requestId: requestId,
                title: 'Private title',
                kind: 'dateNight',
                remindAt: remindAt,
              ),
            ),
          );
          expect(entries.map((entry) => entry.id).toSet(), hasLength(1));
          expect(entries.first.id, isNotNull);

          final session = builder.build();
          expect(await ReminderRecord.db.count(session), 1);
          final events = await ReminderEventOutbox.db.find(session);
          expect(events, hasLength(1));
          expect(events.single.reminderId, entries.first.id);
          expect(events.single.recipientMemberId, isNotNull);
          final creator = (await CoupleMember.db.find(
            session,
            where: (t) => t.userIdentifier.equals('alice'),
          )).single;
          expect(events.single.recipientMemberId, isNot(creator.id));
        expect(events.single.coupleId.toString(), paired.coupleId);
          expect(events.single.eventType, 'reminder_created');
          expect(events.single.toJson().keys, isNot(contains('title')));

          expect(
            (await endpoints.reminders.createReminder(
              asUser('alice'),
              requestId: requestId.toUpperCase(),
              title: 'Private title',
              kind: 'dateNight',
              remindAt: remindAt,
            )).id,
            entries.first.id,
          );
          expect(await ReminderEventOutbox.db.count(session), 1);
        },
      );

      test(
        'request retries with changed content conflict without an event',
        () async {
          await pair();
          final requestId = Uuid().v4();
          final remindAt = DateTime.now().toUtc().add(const Duration(hours: 1));
          await endpoints.reminders.createReminder(
            asUser('alice'),
            requestId: requestId,
            title: 'Original',
            kind: 'call',
            remindAt: remindAt,
          );
          await expectLater(
            endpoints.reminders.createReminder(
              asUser('alice'),
              requestId: requestId,
              title: 'Changed',
              kind: 'call',
              remindAt: remindAt,
            ),
            throwsA(failure('request_conflict')),
          );
          expect(await ReminderEventOutbox.db.count(builder.build()), 1);
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
    testServerOutputMode: TestServerOutputMode.silent,
  );
}
