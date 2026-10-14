import 'dart:convert';

import 'package:closecall_server/src/push/fcm_sender.dart';
import 'package:test/test.dart';

void main() {
  const key = '-----BEGIN PRIVATE KEY-----\\nkey\\n-----END PRIVATE KEY-----';

  test(
    'reads the exact service-account JSON shape without guessing project id',
    () {
      final account = FcmServiceAccount.fromEnvironment({
        'FCM_SERVICE_ACCOUNT_JSON': jsonEncode({
          'project_id': 'closecall-prod-123',
          'client_email': 'sender@closecall-prod-123.iam.gserviceaccount.com',
          'private_key': key,
        }),
      });
      expect(account.projectId, 'closecall-prod-123');
      expect(account.clientEmail, contains('@'));
      expect(account.privateKey, contains('\n'));
    },
  );

  test('supports explicit fields and disables only when all are absent', () {
    expect(FcmServiceAccount.tryFromEnvironment({}), isNull);
    final account = FcmServiceAccount.fromEnvironment({
      'FCM_PROJECT_ID': 'closecall-prod-456',
      'FCM_CLIENT_EMAIL': 'sender@example.test',
      'FCM_PRIVATE_KEY': key,
    });
    expect(account.projectId, 'closecall-prod-456');
  });

  test(
    'rejects reminder payloads unless the event and opaque UUID are valid',
    () async {
      final sender = FcmHttpV1Sender(
        FcmServiceAccount(
          projectId: 'closecall-prod-456',
          clientEmail: 'sender@example.test',
          privateKey: key.replaceAll(r'\n', '\n'),
        ),
      );
      expect(
        (await sender.sendReminder(
          token: 'token',
          reminderId: 'not-an-id',
          eventType: 'reminder_created',
        )).status,
        FcmSendStatus.permanentFailure,
      );
      expect(
        (await sender.sendReminder(
          token: 'token',
          reminderId: '00000000-0000-0000-0000-000000000000',
          eventType: 'private_title',
        )).status,
        FcmSendStatus.permanentFailure,
      );
    },
  );

  test(
    'rejects partial or malformed credentials without exposing secret values',
    () {
      expect(
        () => FcmServiceAccount.fromEnvironment({'FCM_PROJECT_ID': 'prod'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => FcmServiceAccount.fromEnvironment({
          'FCM_SERVICE_ACCOUNT_JSON': jsonEncode({'project_id': 'prod'}),
        }),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
