import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/reminders/data/reminder_notifications.dart';
import 'package:closecall/features/reminders/data/reminders_repository.dart';
import 'package:closecall/features/reminders/presentation/reminder_controller.dart';
import 'package:closecall/features/reminders/presentation/reminders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:closecall_client/closecall_client.dart' as api;

import '../../support/live_fakes.dart';

class _EmptyReminders implements RemindersRepository {
  @override
  Future<List<api.ReminderEntry>> listReminders() async => const [];

  @override
  Future<api.ReminderEntry> createReminder({
    required String requestId,
    required String title,
    required String kind,
    required DateTime remindAt,
  }) => throw UnimplementedError();

  @override
  Future<void> completeReminder({required String reminderId}) async {}

  @override
  Future<void> deleteReminder({required String reminderId}) async {}
}

void main() {
  testWidgets('dismissing a reminder dialog then navigating back is safe', (
    tester,
  ) async {
    final auth = FakeAuth();
    final pairing = PairingController(session: auth, repository: FakeCouples());
    final controller = ReminderController(
      pairing: pairing,
      repository: _EmptyReminders(),
      notifications: const NoopReminderNotifications(),
    );
    addTearDown(() {
      controller.dispose();
      pairing.dispose();
      auth.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => RemindersScreen(controller: controller),
              ),
            ),
            child: const Text('Open reminders'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open reminders'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminders-add')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Open reminders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
