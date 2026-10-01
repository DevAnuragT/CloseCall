import 'package:closecall/features/auth/domain/app_user.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/mood/domain/mood.dart';
import 'package:closecall/features/reminders/domain/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoodKind', () {
    test('round-trips through key', () {
      for (final m in MoodKind.values) {
        expect(MoodKind.fromKey(m.key), m);
      }
    });

    test('throws on unknown key', () {
      expect(() => MoodKind.fromKey('nope'), throwsArgumentError);
    });
  });

  group('MoodCheckIn', () {
    test('json round-trips and stores UTC', () {
      final checkIn = MoodCheckIn(
        userId: 'u1',
        mood: MoodKind.missingYou,
        createdAt: DateTime(2026, 2, 14, 9),
        note: 'thinking of you',
      );
      final back = MoodCheckIn.fromJson(checkIn.toJson());
      expect(back, checkIn);
      expect(back.createdAt.isUtc, isTrue);
    });
  });

  group('Couple', () {
    final couple = Couple(
      id: 'c1',
      memberIds: const ['a', 'b'],
      partnerNickname: 'Love',
      anniversary: DateTime.utc(2024, 6, 1),
    );

    test('partnerOf returns the other member', () {
      expect(couple.partnerOf('a'), 'b');
      expect(couple.partnerOf('b'), 'a');
    });

    test('partnerOf returns null for a non-member', () {
      expect(couple.partnerOf('z'), isNull);
    });

    test('isComplete reflects two members', () {
      expect(couple.isComplete, isTrue);
      expect(Couple(id: 'c2', memberIds: const ['a']).isComplete, isFalse);
    });

    test('json round-trips', () {
      expect(Couple.fromJson(couple.toJson()), couple);
    });
  });

  group('AppUser', () {
    test('json round-trips with nullable fields', () {
      const user = AppUser(id: 'u1', displayName: 'Sam');
      expect(AppUser.fromJson(user.toJson()), user);
    });
  });

  group('reminders', () {
    final now = DateTime.utc(2026, 1, 1, 12);
    final past = Reminder(
      id: 'r0',
      title: 'done',
      kind: ReminderKind.call,
      when: now.subtract(const Duration(hours: 1)),
    );
    final soon = Reminder(
      id: 'r1',
      title: 'call tonight',
      kind: ReminderKind.call,
      when: now.add(const Duration(hours: 2)),
    );
    final later = Reminder(
      id: 'r2',
      title: 'anniversary',
      kind: ReminderKind.anniversary,
      when: now.add(const Duration(days: 10)),
    );

    test('nextReminder picks the soonest upcoming', () {
      expect(nextReminder([later, soon, past], now), soon);
    });

    test('nextReminder is null when nothing is upcoming', () {
      expect(nextReminder([past], now), isNull);
    });

    test('json round-trips', () {
      expect(Reminder.fromJson(soon.toJson()), soon);
    });
  });
}
