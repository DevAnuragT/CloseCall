import 'package:closecall_server/src/generated/protocol.dart';
import 'package:closecall_server/src/moments/moment_event_dispatcher.dart';
import 'package:closecall_server/src/push/fcm_sender.dart';
import 'package:closecall_server/src/reminders/reminder_event_dispatcher.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

class _FakeSender implements MomentFcmSender, ReminderFcmSender {
  final moments = <String>[];
  final reminders = <String>[];

  @override
  Future<FcmSendResult> sendMoment({
    required String token,
    required String momentId,
    required String eventType,
  }) async {
    moments.add(token);
    return const FcmSendResult(FcmSendStatus.sent);
  }

  @override
  Future<FcmSendResult> sendReminder({
    required String token,
    required String reminderId,
    required String eventType,
  }) async {
    reminders.add(token);
    return const FcmSendResult(FcmSendStatus.sent);
  }
}

void main() {
  withServerpod(
    'Moment and reminder FCM dispatch',
    (builder, endpoints) {
      TestSessionBuilder asUser(String id) => builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );

      setUp(() async {
        final session = builder.build();
        await Couple.db.deleteWhere(session, where: (_) => Constant.bool(true));
      });

      Future<void> pairAndRegisterBob() async {
        final pending = await endpoints.pairing.createCouple(asUser('alice'));
        await endpoints.pairing.joinByCode(asUser('bob'), pending.pairingCode!);
        await endpoints.push.registerDevice(
          asUser('bob'),
          token: 'bob-token-1234567890123456789012345',
          deviceId: 'bob-device',
        );
      }

      test('moment event is sent to the partner registration', () async {
        await pairAndRegisterBob();
        await endpoints.moments.createMoment(
          asUser('alice'),
          requestId: const Uuid().v4(),
          text: 'hello',
        );
        final session = builder.build();
        final sender = _FakeSender();
        await MomentEventOutboxDispatcher(
          sender: sender,
        ).reconcile(session.serverpod);
        final row = (await MomentEventOutbox.db.find(session)).single;
        expect(row.lastError, 'sent');
        expect(sender.moments, ['bob-token-1234567890123456789012345']);
      });

      test('reminder event is sent to the partner registration', () async {
        await pairAndRegisterBob();
        await endpoints.reminders.createReminder(
          asUser('alice'),
          requestId: const Uuid().v4(),
          title: 'water plants',
          kind: 'call',
          remindAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
        );
        final session = builder.build();
        final sender = _FakeSender();
        await ReminderEventOutboxDispatcher(
          sender: sender,
        ).reconcile(session.serverpod);
        final row = (await ReminderEventOutbox.db.find(session)).single;
        expect(row.lastError, 'sent');
        expect(sender.reminders, ['bob-token-1234567890123456789012345']);
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
    testServerOutputMode: TestServerOutputMode.silent,
  );
}
