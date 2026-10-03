import 'package:closecall_shared/closecall_shared.dart';
import 'package:test/test.dart';

final now = DateTime.utc(2026, 1, 1, 12);
WidgetSchedule schedule(
  String id,
  String asset,
  DateTime from,
  DateTime until, {
  DateTime? created,
}) => WidgetSchedule(
  id: id,
  assetId: asset,
  activeFrom: from,
  activeUntil: until,
  createdAt: created ?? now,
);
WidgetResolution resolve(List<WidgetSchedule> schedules, {DateTime? at}) =>
    WidgetScheduleResolver.resolve(
      now: at ?? now,
      schedules: schedules,
      fallbackAssetId: 'fallback',
    );

void main() {
  test('empty and expired schedules use fallback without a transition', () {
    expect(resolve([]).assetId, 'fallback');
    expect(resolve([]).nextTransition, isNull);
    final expired = schedule(
      'a',
      'old',
      now.subtract(const Duration(hours: 2)),
      now,
    );
    expect(resolve([expired]).isFallback, isTrue);
    expect(resolve([expired]).nextTransition, isNull);
  });
  test(
    'future window switches at inclusive start and reverts at exclusive end',
    () {
      final start = now.add(const Duration(hours: 1));
      final end = start.add(const Duration(hours: 2));
      final window = schedule('a', 'surprise', start, end);
      expect(resolve([window]).nextTransition, start);
      expect(resolve([window], at: start).assetId, 'surprise');
      expect(resolve([window], at: start).nextTransition, end);
      expect(resolve([window], at: end).assetId, 'fallback');
      expect(resolve([window], at: end).nextTransition, isNull);
    },
  );
  test('newest overlap wins then older window resumes', () {
    final end = now.add(const Duration(hours: 2));
    final newerEnd = now.add(const Duration(hours: 1));
    final old = schedule(
      'a',
      'old',
      now,
      end,
      created: now.subtract(const Duration(days: 1)),
    );
    final newest = schedule('b', 'new', now, newerEnd);
    expect(resolve([old, newest]).assetId, 'new');
    expect(resolve([old, newest]).nextTransition, newerEnd);
    expect(resolve([old, newest], at: newerEnd).assetId, 'old');
    expect(resolve([old, newest], at: newerEnd).nextTransition, end);
  });
  test(
    'equal creation time deterministically chooses highest id in any list order',
    () {
      final end = now.add(const Duration(hours: 1));
      final a = schedule('aaa', 'A', now, end);
      final z = schedule('zzz', 'Z', now, end);
      for (final ordered in [
        [a, z],
        [z, a],
      ]) {
        expect(resolve(ordered).assetId, 'Z');
        expect(resolve(ordered).activeSchedule, z);
      }
    },
  );
  test('zero-length and inverted windows ignored', () {
    final zero = schedule('zero', 'bad', now, now);
    final inverted = schedule(
      'inverted',
      'bad',
      now.add(const Duration(hours: 1)),
      now,
    );
    expect(resolve([zero, inverted]).assetId, 'fallback');
    expect(resolve([zero, inverted]).nextTransition, isNull);
  });
  test(
    'same-asset seams and hidden boundaries do not create false transitions',
    () {
      final mid = now.add(const Duration(hours: 1));
      final end = now.add(const Duration(hours: 2));
      final first = schedule('a', 'same', now, mid);
      final second = schedule('b', 'same', mid, end);
      expect(resolve([first, second]).nextTransition, end);
      final hidden = schedule(
        'hidden',
        'other',
        now,
        mid,
        created: now.subtract(const Duration(days: 1)),
      );
      final winner = schedule('winner', 'same', now, end);
      expect(resolve([hidden, winner]).nextTransition, end);
    },
  );
  test(
    'absolute local/UTC instants and model roundtrip/copy retain semantics',
    () {
      final local = now.toLocal();
      final window = schedule(
        'a',
        'photo',
        local,
        local.add(const Duration(hours: 1)),
      );
      expect(window.activeFrom.isUtc, isTrue);
      expect(resolve([window], at: local).assetId, 'photo');
      expect(WidgetSchedule.fromJson(window.toJson()), window);
      expect(window.copyWith(), window);
      expect(window.copyWith(assetId: 'new').assetId, 'new');
      expect(window.isActiveAt(now), isTrue);
      expect(window.isExpiredAt(window.activeUntil), isTrue);
      expect(window.isActiveAt(window.activeUntil), isFalse);
    },
  );
}
