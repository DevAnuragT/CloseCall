import 'package:closecall_client/closecall_client.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notifications are deliberately behind this interface: server state is
/// authoritative and tests can use [NoopReminderNotifications].
abstract interface class ReminderNotifications {
  Future<void> schedule(api.ReminderEntry reminder);

  Future<void> cancel(api.ReminderEntry reminder);

  Future<void> cancelAll();
}

class NoopReminderNotifications implements ReminderNotifications {
  const NoopReminderNotifications();

  @override
  Future<void> cancel(api.ReminderEntry reminder) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule(api.ReminderEntry reminder) async {}
}

/// Best-effort local reminders. Android uses inexact alarms and deliberately
/// does not request exact-alarm permissions. Notification text is generic so a
/// private reminder title never appears on a lock screen.
class LocalReminderNotifications implements ReminderNotifications {
  LocalReminderNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialized;

  Future<void> _ensureInitialized() {
    return _initialized ??= _initialize();
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    final initialized = await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    if (initialized != true && !kIsWeb) {
      // Some platforms return null when no platform implementation exists.
      // Scheduling remains best effort and should never block server state.
      return;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  @override
  Future<void> schedule(api.ReminderEntry reminder) async {
    if (reminder.completedAt != null ||
        reminder.remindAt.isBefore(DateTime.now())) {
      return;
    }
    try {
      await _ensureInitialized();
      await _plugin.zonedSchedule(
        notificationId(reminder.id.toString()),
        'CloseCall reminder',
        'You have a reminder.',
        tz.TZDateTime.from(reminder.remindAt.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'closecall_reminders',
            'Reminders',
            channelDescription: 'CloseCall reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'reminder',
      );
    } catch (_) {
      // A denied permission or unsupported host must not make a successful
      // reminder mutation look like it failed.
    }
  }

  @override
  Future<void> cancel(api.ReminderEntry reminder) async {
    try {
      await _ensureInitialized();
      await _plugin.cancel(notificationId(reminder.id.toString()));
    } catch (_) {}
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _ensureInitialized();
      await _plugin.cancelAll();
    } catch (_) {}
  }
}

/// Stable positive Android notification id derived from the server UUID.
int notificationId(String uuid) {
  var hash = 0x811c9dc5;
  for (final codeUnit in uuid.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
