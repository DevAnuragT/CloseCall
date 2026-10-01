import 'package:closecall/features/widget/domain/widget_schedule.dart';
import 'package:closecall/features/widget/domain/widget_schedule_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed reference instant for deterministic tests.
final t0 = DateTime.utc(2026, 1, 1, 12, 0);

WidgetSchedule sched({
  String id = 's',
  String asset = 'photo',
  required DateTime from,
  required DateTime until,
  DateTime? created,
}) {
  return WidgetSchedule(
    id: id,
    assetId: asset,
    activeFrom: from,
    activeUntil: until,
    createdAt: created ?? DateTime.utc(2026, 1, 1, 0, 0),
  );
}

void main() {
  const fallback = 'default_photo';

  group('fallback behavior', () {
    test('no schedules -> fallback, no next transition', () {
      final r = WidgetScheduleResolver.resolve(
        now: t0,
        schedules: const [],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, fallback);
      expect(r.source, WidgetAssetSource.fallback);
      expect(r.activeSchedule, isNull);
      expect(r.nextTransition, isNull);
    });

    test('only an expired schedule -> fallback, no next transition', () {
      final s = sched(
        from: t0.subtract(const Duration(hours: 2)),
        until: t0.subtract(const Duration(hours: 1)),
      );
      final r = WidgetScheduleResolver.resolve(
        now: t0,
        schedules: [s],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, fallback);
      expect(r.isFallback, isTrue);
      expect(r.nextTransition, isNull);
    });
  });

  group('single schedule', () {
    test('active window shows scheduled asset and reverts at activeUntil', () {
      final until = t0.add(const Duration(hours: 3));
      final s = sched(
        asset: 'surprise',
        from: t0.subtract(const Duration(hours: 1)),
        until: until,
      );
      final r = WidgetScheduleResolver.resolve(
        now: t0,
        schedules: [s],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, 'surprise');
      expect(r.source, WidgetAssetSource.scheduled);
      expect(r.activeSchedule, s);
      // Next change is the revert back to fallback.
      expect(r.nextTransition, until);
    });

    test('future window -> fallback now, next transition at activeFrom', () {
      final from = t0.add(const Duration(hours: 8));
      final s = sched(
        asset: 'morning',
        from: from,
        until: from.add(const Duration(hours: 2)),
      );
      final r = WidgetScheduleResolver.resolve(
        now: t0,
        schedules: [s],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, fallback);
      expect(r.nextTransition, from);
    });
  });

  group('boundary conditions (start inclusive, end exclusive)', () {
    final from = t0;
    final until = t0.add(const Duration(hours: 1));
    final s = sched(asset: 'win', from: from, until: until);

    test('now == activeFrom is active', () {
      final r = WidgetScheduleResolver.resolve(
        now: from,
        schedules: [s],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, 'win');
    });

    test('now == activeUntil is NOT active (reverted)', () {
      final r = WidgetScheduleResolver.resolve(
        now: until,
        schedules: [s],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, fallback);
      expect(r.nextTransition, isNull);
    });
  });

  group('overlapping schedules', () {
    test('most recently created wins', () {
      final older = sched(
        id: 'a',
        asset: 'old',
        from: t0.subtract(const Duration(hours: 1)),
        until: t0.add(const Duration(hours: 1)),
        created: DateTime.utc(2026, 1, 1, 8, 0),
      );
      final newer = sched(
        id: 'b',
        asset: 'new',
        from: t0.subtract(const Duration(minutes: 30)),
        until: t0.add(const Duration(minutes: 30)),
        created: DateTime.utc(2026, 1, 1, 9, 0),
      );
      final r = WidgetScheduleResolver.resolve(
        now: t0,
        schedules: [older, newer],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, 'new');
      expect(r.activeSchedule, newer);
    });

    test('equal createdAt breaks tie on id (higher id wins)', () {
      final created = DateTime.utc(2026, 1, 1, 9, 0);
      final a = sched(
        id: 'aaa',
        asset: 'A',
        from: t0.subtract(const Duration(hours: 1)),
        until: t0.add(const Duration(hours: 1)),
        created: created,
      );
      final z = sched(
        id: 'zzz',
        asset: 'Z',
        from: t0.subtract(const Duration(hours: 1)),
        until: t0.add(const Duration(hours: 1)),
        created: created,
      );
      final r = WidgetScheduleResolver.resolve(
        now: t0,
        schedules: [a, z],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, 'Z');
    });

    test('when newer window ends, reverts to the still-active older one', () {
      final older = sched(
        id: 'a',
        asset: 'old',
        from: t0.subtract(const Duration(hours: 1)),
        until: t0.add(const Duration(hours: 2)),
        created: DateTime.utc(2026, 1, 1, 8, 0),
      );
      final newerUntil = t0.add(const Duration(minutes: 30));
      final newer = sched(
        id: 'b',
        asset: 'new',
        from: t0.subtract(const Duration(minutes: 30)),
        until: newerUntil,
        created: DateTime.utc(2026, 1, 1, 9, 0),
      );
      final r = WidgetScheduleResolver.resolve(
        now: t0,
        schedules: [older, newer],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, 'new');
      // Next change is when 'new' ends and 'old' takes back over.
      expect(r.nextTransition, newerUntil);
    });
  });

  group('malformed and edge data', () {
    test('zero-length and inverted windows are ignored', () {
      final zero = sched(id: 'z', from: t0, until: t0);
      final inverted = sched(
        id: 'i',
        from: t0.add(const Duration(hours: 1)),
        until: t0.subtract(const Duration(hours: 1)),
      );
      final r = WidgetScheduleResolver.resolve(
        now: t0,
        schedules: [zero, inverted],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, fallback);
      expect(r.nextTransition, isNull);
    });

    test('back-to-back windows with same asset report no false transition', () {
      final mid = t0.add(const Duration(hours: 1));
      final end = t0.add(const Duration(hours: 2));
      final first = sched(
        id: '1',
        asset: 'same',
        from: t0,
        until: mid,
      );
      final second = sched(
        id: '2',
        asset: 'same',
        from: mid,
        until: end,
      );
      final r = WidgetScheduleResolver.resolve(
        now: t0,
        schedules: [first, second],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, 'same');
      // The seam at `mid` keeps the same asset; the real change is the revert
      // to fallback at `end`.
      expect(r.nextTransition, end);
    });
  });

  group('timezone handling', () {
    test('local-time inputs resolve by absolute instant', () {
      final localFrom = DateTime(2026, 1, 1, 10); // local
      final localUntil = DateTime(2026, 1, 1, 14); // local
      final nowLocal = DateTime(2026, 1, 1, 12); // local, inside window
      final s = sched(asset: 'local', from: localFrom, until: localUntil);
      final r = WidgetScheduleResolver.resolve(
        now: nowLocal,
        schedules: [s],
        fallbackAssetId: fallback,
      );
      expect(r.assetId, 'local');
      expect(r.nextTransition, localUntil.toUtc());
    });
  });

  group('model', () {
    test('json round-trips', () {
      final s = sched(
        id: 'x',
        asset: 'p',
        from: t0,
        until: t0.add(const Duration(hours: 1)),
      );
      final back = WidgetSchedule.fromJson(s.toJson());
      expect(back, s);
    });

    test('isValid / isActiveAt / isExpiredAt', () {
      final until = t0.add(const Duration(hours: 1));
      final s = sched(from: t0, until: until);
      expect(s.isValid, isTrue);
      expect(s.isActiveAt(t0), isTrue);
      expect(s.isActiveAt(until), isFalse);
      expect(s.isExpiredAt(until), isTrue);
      expect(s.isExpiredAt(t0), isFalse);
    });
  });
}
