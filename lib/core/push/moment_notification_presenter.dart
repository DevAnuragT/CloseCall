import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Presents only the generic, opaque Moment notification. The Moment text,
/// audio and private identifiers other than the UUID payload never cross this
/// local-notification boundary.
class MomentNotificationPresenter {
  MomentNotificationPresenter({
    FlutterLocalNotificationsPlugin? plugin,
    this.onTap,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String momentId)? onTap;
  Future<void>? _initialized;

  Future<void> initialize() async {
    final flight = _initialized ??= _initialize();
    await flight;
  }

  Future<void> _initialize() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        final parts = payload.split('|');
        if (parts.length == 2 &&
            parts.first == 'moment_created' &&
            _isUuid(parts.last)) {
          onTap?.call(parts.last);
        }
      },
    );
  }

  Future<void> show(String momentId) async {
    if (!_isUuid(momentId)) return;
    try {
      await initialize();
      await _plugin.show(
        _notificationId(momentId),
        'CloseCall',
        'New moment from your partner',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'closecall_moments',
            'Moments',
            channelDescription: 'Private Moment notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'moment_created|$momentId',
      );
    } catch (_) {
      // Notification presentation is optional and must never block the feed.
    }
  }

  /// Shows a generic foreground reminder notification. The reminder ID is
  /// used only to keep notifications distinct; no reminder fields are read or
  /// displayed, and tapping it does not authorize access to the reminder.
  Future<void> showReminder(String reminderId) async {
    if (!_isUuid(reminderId)) return;
    try {
      await initialize();
      await _plugin.show(
        _notificationId(reminderId),
        'CloseCall',
        'Your partner added a reminder',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'closecall_reminders',
            'Reminders',
            channelDescription: 'CloseCall reminder notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'reminder_created|$reminderId',
      );
    } catch (_) {
      // Notification presentation is optional and must never block the feed.
    }
  }

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

  static int _notificationId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
