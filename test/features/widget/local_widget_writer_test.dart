import 'dart:async';
import 'dart:typed_data';

import 'package:closecall/features/widget/data/local_widget_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

Map<String, Object?> payload(Uint8List photo) => {
  'scope': 'me/couple',
  'serverTimeMs': scheduleEpoch.millisecondsSinceEpoch,
  'fallbackAssetId': 'fallback',
  'schedules': <Map<String, Object?>>[],
  'photos': <String, Uint8List>{'fallback': photo},
};

void main() {
  test(
    'writer shared queue skips queued stale cache and clears after started manual write',
    () async {
      final events = <String>[];
      final native = FakeNativeTimeline(events);
      final pending = Completer<void>();
      final writer = LocalWidgetWriter(
        timeline: native,
        applyPhoto: (_) async {
          events.add('apply-start');
          await pending.future;
          events.add('apply-done');
        },
        clearPhoto: () async {
          events.add('clear-photo');
        },
      );
      await writer.setScope('old');
      events.clear();
      final manual = writer.write(testPng, isCurrent: () => true);
      await Future<void>.delayed(Duration.zero);
      final cache = writer.cacheTimeline(
        payload(testPng),
        isCurrent: () => true,
      );
      final clearing = writer.setScope(null);
      pending.complete();
      expect(await manual, isFalse);
      expect(await cache, isFalse);
      await clearing;
      expect(events, [
        'apply-start',
        'apply-done',
        'clear-timeline',
        'clear-photo',
      ]);
      expect(native.payloads, isEmpty);
      writer.dispose();
    },
  );

  test(
    'native payload deep copies photo bytes and schedules before queueing',
    () async {
      final events = <String>[];
      final native = FakeNativeTimeline(events);
      final pending = Completer<void>();
      final writer = LocalWidgetWriter(
        timeline: native,
        applyPhoto: (_) => pending.future,
        clearPhoto: () async {},
      );
      await writer.setScope('me');
      final blocking = writer.write(testPng, isCurrent: () => true);
      final photo = Uint8List.fromList(testPng);
      final data = payload(photo);
      final entry = <String, Object?>{'scheduleId': 'original'};
      (data['schedules'] as List).add(entry);
      final caching = writer.cacheTimeline(data, isCurrent: () => true);
      photo[0] = 0;
      entry['scheduleId'] = 'mutated';
      (data['photos'] as Map).clear();
      pending.complete();
      await blocking;
      expect(await caching, isTrue);
      expect((native.payloads.single['photos'] as Map)['fallback'], testPng);
      expect(
        ((native.payloads.single['schedules'] as List).single
            as Map)['scheduleId'],
        'original',
      );
      writer.dispose();
    },
  );

  test(
    'failed identity cleanup blocks all new image/cache writes until clear succeeds',
    () async {
      final events = <String>[];
      final native = FakeNativeTimeline(events)
        ..clearFailure = StateError('disk');
      final writer = LocalWidgetWriter(
        timeline: native,
        applyPhoto: (_) async {
          events.add('apply');
        },
        clearPhoto: () async {
          events.add('clear-photo');
        },
      );
      await expectLater(writer.setScope('me'), throwsStateError);
      await expectLater(
        writer.write(testPng, isCurrent: () => true),
        throwsStateError,
      );
      expect(events, isNot(contains('apply')));
      native.clearFailure = null;
      expect(await writer.write(testPng, isCurrent: () => true), isTrue);
      expect(events.sublist(events.length - 3), [
        'clear-timeline',
        'clear-photo',
        'apply',
      ]);
      writer.dispose();
    },
  );

  test('default injected writer uses no native plugins', () async {
    final writer = LocalWidgetWriter(
      applyPhoto: (_) async {},
      clearPhoto: () async {},
    );
    expect(writer.timeline.supported, isFalse);
    await writer.setScope(null);
    expect(await writer.write(testPng, isCurrent: () => true), isTrue);
    expect(await writer.disableTimeline(isCurrent: () => true), isTrue);
    writer.dispose();
  });

  test(
    'cache anchor sampled inside queue, not when payload was constructed',
    () async {
      final native = FakeNativeTimeline([]);
      final pending = Completer<void>();
      var now = scheduleEpoch;
      final writer = LocalWidgetWriter(
        timeline: native,
        applyPhoto: (_) => pending.future,
        clearPhoto: () async {},
      );
      await writer.setScope('me');
      final blocking = writer.write(testPng, isCurrent: () => true);
      final caching = writer.cacheTimeline(
        payload(testPng),
        isCurrent: () => true,
        serverNow: () => now,
      );
      now = scheduleEpoch.add(const Duration(milliseconds: 1234));
      pending.complete();
      await blocking;
      await caching;
      expect(
        native.payloads.single['serverTimeMs'],
        now.millisecondsSinceEpoch,
      );
      writer.dispose();
    },
  );
}
