import 'package:closecall_client/closecall_client.dart' as api;

/// Transport boundary for reminders. Keeping this separate makes the
/// controller and screen usable with an in-memory repository in tests.
abstract interface class RemindersRepository {
  Future<List<api.ReminderEntry>> listReminders();

  Future<api.ReminderEntry> createReminder({
    required String requestId,
    required String title,
    required String kind,
    required DateTime remindAt,
  });

  Future<void> completeReminder({required String reminderId});

  Future<void> deleteReminder({required String reminderId});
}

class ServerpodRemindersRepository implements RemindersRepository {
  ServerpodRemindersRepository(this.client);

  final api.Client client;

  @override
  Future<List<api.ReminderEntry>> listReminders() =>
      client.reminders.listReminders();

  @override
  Future<api.ReminderEntry> createReminder({
    required String requestId,
    required String title,
    required String kind,
    required DateTime remindAt,
  }) => client.reminders.createReminder(
    requestId: requestId,
    title: title,
    kind: kind,
    remindAt: remindAt.toUtc(),
  );

  @override
  Future<void> completeReminder({required String reminderId}) =>
      client.reminders.completeReminder(reminderId: reminderId);

  @override
  Future<void> deleteReminder({required String reminderId}) =>
      client.reminders.deleteReminder(reminderId: reminderId);
}
