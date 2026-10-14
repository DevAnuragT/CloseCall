import 'package:closecall/core/push/push_notification_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const momentId = '123e4567-e89b-42d3-a456-426614174000';
  const reminderId = '123e4567-e89b-42d3-a456-426614174001';

  test('accepts only validated opaque Moment and reminder event data', () {
    final moment = PushNotificationPayload.parse({
      'type': 'moment_created',
      'momentId': momentId,
      'title': 'private text must not be used',
    });
    final reminder = PushNotificationPayload.parse({
      'type': 'reminder_created',
      'reminderId': reminderId,
      'reminderTitle': 'private text must not be used',
      'remindAt': '2026-10-14T12:00:00Z',
    });

    expect(moment?.type, PushNotificationType.momentCreated);
    expect(moment?.id, momentId);
    expect(reminder?.type, PushNotificationType.reminderCreated);
    expect(reminder?.id, reminderId);
  });

  test('rejects unknown events, wrong identifier keys, and malformed IDs', () {
    expect(
      PushNotificationPayload.parse({
        'type': 'reminder_created',
        'momentId': reminderId,
      }),
      isNull,
    );
    expect(
      PushNotificationPayload.parse({
        'type': 'reminder_created',
        'reminderId': 123,
      }),
      isNull,
    );
    expect(
      PushNotificationPayload.parse({
        'type': 'unknown',
        'reminderId': reminderId,
      }),
      isNull,
    );
    expect(
      PushNotificationPayload.parse({
        'type': 'moment_created',
        'momentId': 'not-a-uuid',
      }),
      isNull,
    );
  });
}
