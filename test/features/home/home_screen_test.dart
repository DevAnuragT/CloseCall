import 'package:closecall/features/home/domain/dashboard_snapshot.dart';
import 'package:closecall/features/home/presentation/home_screen.dart';
import 'package:closecall/features/mood/domain/mood.dart';
import 'package:closecall/features/reminders/domain/reminder.dart';
import 'package:closecall/features/widget/domain/widget_schedule.dart';
import 'package:closecall/features/widget/domain/widget_schedule_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardSnapshot _snapshot({required bool scheduled}) {
  final now = DateTime.utc(2026, 1, 1, 12);
  final schedules = scheduled
      ? [
          WidgetSchedule(
            id: 's',
            assetId: 'surprise.jpg',
            activeFrom: now.subtract(const Duration(hours: 1)),
            activeUntil: now.add(const Duration(hours: 1)),
            createdAt: now.subtract(const Duration(hours: 2)),
          ),
        ]
      : <WidgetSchedule>[];
  return DashboardSnapshot(
    partnerNickname: 'Love',
    partnerMood: MoodCheckIn(
      userId: 'p',
      mood: MoodKind.missingYou,
      createdAt: now,
    ),
    widget: WidgetScheduleResolver.resolve(
      now: now,
      schedules: schedules,
      fallbackAssetId: 'fallback.jpg',
    ),
    nextReminder: Reminder(
      id: 'r',
      title: 'Call tonight',
      kind: ReminderKind.call,
      when: now.add(const Duration(hours: 6)),
    ),
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Enlarges the test surface so the whole dashboard lays out without the
/// ListView lazily dropping off-screen cards.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('HomeScreen', () {
    testWidgets('renders partner nickname, mood, reminder', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_wrap(HomeScreen(snapshot: _snapshot(scheduled: true))));

      expect(find.text('Love'), findsOneWidget);
      expect(find.text('Missing You'), findsOneWidget);
      expect(find.text('Call tonight'), findsOneWidget);
    });

    testWidgets('shows Scheduled badge + asset when a schedule is active',
        (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_wrap(HomeScreen(snapshot: _snapshot(scheduled: true))));
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('surprise.jpg'), findsOneWidget);
    });

    testWidgets('shows Default badge + fallback asset otherwise',
        (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_wrap(HomeScreen(snapshot: _snapshot(scheduled: false))));
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('fallback.jpg'), findsOneWidget);
    });
  });
}
