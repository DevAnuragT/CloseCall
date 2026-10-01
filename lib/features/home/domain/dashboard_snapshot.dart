import 'package:closecall/features/mood/domain/mood.dart';
import 'package:closecall/features/reminders/domain/reminder.dart';
import 'package:closecall/features/widget/domain/widget_schedule.dart';
import 'package:closecall/features/widget/domain/widget_schedule_resolver.dart';

/// Everything the home dashboard renders in one immutable snapshot. Fed by a
/// repository later; a mock source powers it until the backend lands.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.partnerNickname,
    required this.partnerMood,
    required this.widget,
    required this.nextReminder,
  });

  final String partnerNickname;
  final MoodCheckIn? partnerMood;
  final WidgetResolution widget;
  final Reminder? nextReminder;
}

/// Deterministic sample data so the dashboard is demoable before Supabase is
/// wired in. Uses the real [WidgetScheduleResolver] so the preview behaves
/// exactly as production will.
abstract final class MockDashboard {
  static DashboardSnapshot snapshot({DateTime? now}) {
    final at = (now ?? DateTime.now()).toUtc();

    final schedule = WidgetSchedule(
      id: 'sched-1',
      assetId: 'morning_surprise.jpg',
      activeFrom: at.subtract(const Duration(minutes: 30)),
      activeUntil: at.add(const Duration(hours: 2)),
      createdAt: at.subtract(const Duration(hours: 3)),
    );

    final resolution = WidgetScheduleResolver.resolve(
      now: at,
      schedules: [schedule],
      fallbackAssetId: 'favorite_couple.jpg',
    );

    return DashboardSnapshot(
      partnerNickname: 'Love',
      partnerMood: MoodCheckIn(
        userId: 'partner',
        mood: MoodKind.missingYou,
        createdAt: at.subtract(const Duration(minutes: 12)),
      ),
      widget: resolution,
      nextReminder: Reminder(
        id: 'r1',
        title: 'Call tonight',
        kind: ReminderKind.call,
        when: at.add(const Duration(hours: 6)),
      ),
    );
  }
}
