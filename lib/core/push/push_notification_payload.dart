/// A validated, data-only FCM notification hint.
///
/// Push data is untrusted. In particular, an identifier in this object is only
/// an opaque notification hint; it is never an authorization decision.
class PushNotificationPayload {
  const PushNotificationPayload({required this.type, required this.id});

  final PushNotificationType type;
  final String id;

  /// Parses only the two user-visible notification events understood by the
  /// client. Notification/title/content fields are intentionally ignored.
  static PushNotificationPayload? parse(Map<String, dynamic> data) {
    final type = data['type'];
    final idKey = switch (type) {
      'moment_created' => PushNotificationType.momentCreated,
      'reminder_created' => PushNotificationType.reminderCreated,
      _ => null,
    };
    if (idKey == null) return null;

    final id =
        data[idKey == PushNotificationType.momentCreated
            ? 'momentId'
            : 'reminderId'];
    if (id is! String || !_uuid.hasMatch(id)) return null;
    return PushNotificationPayload(type: idKey, id: id);
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
}

enum PushNotificationType { momentCreated, reminderCreated }
