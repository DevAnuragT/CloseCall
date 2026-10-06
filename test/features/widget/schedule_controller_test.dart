import 'dart:async';
import 'dart:typed_data';

import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/media/data/photo_preparation.dart';
import 'package:closecall/features/widget/presentation/schedule_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

void main() {
  late ScheduleHarness h;
  setUp(() {
    h = ScheduleHarness();
  });
  tearDown(() async {
    await h.dispose();
  });

  test(
    'bootstrap clears persisted truth even when initially signed out',
    () async {
      await h.initialize(signedIn: false);
      expect(h.events, ['clear-timeline', 'clear-photo']);
      expect(h.controller.ownTimeline, isNull);
      expect(h.repository.watches, 0);
      expect(h.controller.autoSyncEnabled, isFalse);
    },
  );

  test(
    'initial own and partner resolution does not opt in or download',
    () async {
      await h.initialize();
      expect(h.controller.ownCurrentAssetId, 'fallback');
      expect(h.controller.partnerCurrentAssetId, 'partner-only');
      expect(h.controller.serverNow, scheduleEpoch);
      expect(h.photos.downloads, isEmpty);
      expect(h.native.payloads, isEmpty);
      expect(h.applied, isEmpty);
    },
  );

  test(
    'offline UTC boundaries, overlaps and fallback use monotonic elapsed',
    () async {
      h.repository.own = scheduleTimeline(
        schedules: [
          scheduleEntry(id: 'base', asset: 'base', from: 5, until: 40),
          scheduleEntry(
            id: 'overlap',
            asset: 'new',
            from: 10,
            until: 20,
            created: 1,
          ),
        ],
      );
      await h.initialize();
      h.controller.setForeground(false);
      h.wall = DateTime(
        1900,
      ); // Device wall-clock/time-zone changes are irrelevant.
      for (final step in [
        (5, 'base'),
        (10, 'new'),
        (20, 'base'),
        (40, 'fallback'),
      ]) {
        h.elapsed = Duration(seconds: step.$1);
        h.controller.resolveNow();
        expect(h.controller.ownCurrentAssetId, step.$2);
        expect(h.controller.serverNow.isUtc, isTrue);
      }
      expect(h.applied, isEmpty);
    },
  );

  test(
    'equal timestamp duplicate cannot rewind, older stream is ignored',
    () async {
      await h.initialize();
      h.elapsed = const Duration(seconds: 7);
      h.repository.stream.add(scheduleTimeline());
      expect(
        h.controller.serverNow,
        scheduleEpoch.add(const Duration(seconds: 7)),
      );
      h.repository.stream.add(
        scheduleTimeline(
          fallback: 'stale',
          now: scheduleEpoch.subtract(const Duration(seconds: 1)),
        ),
      );
      expect(h.controller.ownCurrentAssetId, 'fallback');
    },
  );

  test(
    'UTC create retry preserves exact request and does not issue new ID',
    () async {
      await h.initialize();
      h.repository.createFailure = StateError('response lost after commit');
      final from = DateTime.parse('2026-10-03T13:05:00+01:00');
      final until = DateTime.parse('2026-10-03T13:15:00+01:00');
      await h.controller.createPartnerSchedule('mine', from, until);
      expect(h.controller.pendingCreate, isNotNull);
      await h.controller.createPartnerSchedule('other', from, until);
      expect(h.repository.creates, hasLength(1));
      h.repository.createFailure = null;
      await h.controller.retry();
      expect(h.repository.creates, hasLength(2));
      expect(h.repository.creates[0], h.repository.creates[1]);
      expect(h.repository.creates[0].$2.isUtc, isTrue);
      expect(h.requestIds, 1);
      expect(h.controller.pendingCreate, isNull);
      expect(h.controller.error, isNull);
    },
  );

  test('invalid creation window never calls repository', () async {
    await h.initialize();
    await h.controller.createPartnerSchedule(
      'mine',
      scheduleEpoch,
      scheduleEpoch,
    );
    expect(h.controller.error, isA<FormatException>());
    expect(h.repository.creates, isEmpty);
    expect(h.controller.pendingCreate, isNull);
  });

  test(
    'own fallback and authorized cancellation refresh correct timelines',
    () async {
      h.repository.own = scheduleTimeline(schedules: [scheduleEntry()]);
      await h.initialize();
      await h.controller.setOwnFallback('mine');
      expect(h.repository.fallbacks, ['mine']);
      expect(h.controller.ownCurrentAssetId, 'mine');
      expect(h.controller.partnerCurrentAssetId, 'partner-only');
      await h.controller.cancelSchedule(
        h.controller.ownTimeline!.schedules.single,
      );
      expect(h.repository.cancellations, ['schedule']);
      expect(h.controller.ownTimeline!.schedules, isEmpty);
      expect(h.controller.canCancel(scheduleEntry(id: 'unknown')), isFalse);
    },
  );

  test(
    'auth reset discards pending stream, request, resolution and downloads',
    () async {
      await h.initialize();
      h.photos.pending['fallback'] = Completer<Uint8List>();
      final syncing = h.controller.setAutoSync(true);
      await h.settle();
      h.auth.change(null);
      h.repository.stream.add(scheduleTimeline(fallback: 'late-old-user'));
      h.photos.pending['fallback']!.complete(testPng);
      await syncing;
      await h.settle();
      expect(h.controller.ownTimeline, isNull);
      expect(h.controller.ownResolution, isNull);
      expect(h.controller.cachedAssetCount, 0);
      expect(h.controller.autoSyncEnabled, isFalse);
      expect(h.applied, isEmpty);
      expect(h.native.persisted, isNull);
      expect(h.events.last, 'clear-photo');
    },
  );

  test('late refresh result after current user reset is ignored', () async {
    await h.initialize();
    h.repository.pendingCurrent = Completer();
    final refreshing = h.controller.refresh();
    h.auth.change(null);
    h.repository.pendingCurrent!.complete(scheduleTimeline(fallback: 'old'));
    await refreshing;
    expect(h.controller.ownTimeline, isNull);
    expect(h.controller.error, isNull);
  });

  test(
    'couple change clears cache and opt-in; same account token refresh does not',
    () async {
      await h.initialize();
      await h.controller.setAutoSync(true);
      final clears = h.clears;
      h.auth.change('me');
      await h.settle();
      expect(h.clears, clears);
      expect(h.controller.autoSyncEnabled, isTrue);
      h.couples.couple = Couple(id: 'new-couple', memberIds: ['me', 'partner']);
      await h.pairing.refresh();
      await h.settle();
      expect(h.clears, greaterThan(clears));
      expect(h.controller.autoSyncEnabled, isFalse);
      expect(h.native.persisted, isNull);
    },
  );

  test(
    'recipient and couple mismatch stream cannot become own cache',
    () async {
      await h.initialize();
      await h.controller.setAutoSync(true);
      final count = h.native.payloads.length;
      h.repository.stream.add(
        scheduleTimeline(recipient: 'partner', fallback: 'partner-only'),
      );
      expect(h.controller.streamError, isA<StateError>());
      expect(h.controller.ownCurrentAssetId, 'fallback');
      await h.settle();
      expect(h.native.payloads, hasLength(count));
    },
  );

  test(
    'stale download for replaced own stream never writes or caches old truth',
    () async {
      await h.initialize();
      h.photos.pending['fallback'] = Completer<Uint8List>();
      final syncing = h.controller.setAutoSync(true);
      await h.settle();
      h.repository.stream.add(
        scheduleTimeline(
          fallback: 'fresh',
          now: scheduleEpoch.add(const Duration(seconds: 1)),
        ),
      );
      await h.settle();
      h.photos.pending['fallback']!.complete(testPng);
      await syncing;
      await h.settle();
      expect(h.controller.ownCurrentAssetId, 'fresh');
      expect(h.native.payloads.single['fallbackAssetId'], 'fresh');
      expect(h.applied, hasLength(1));
    },
  );

  test(
    'own update disables outdated cached alarms even when replacement download fails',
    () async {
      await h.initialize();
      await h.controller.setAutoSync(true);
      expect(h.native.persisted, isNotNull);
      h.photos.downloadFailure = StateError('offline');
      h.repository.stream.add(
        scheduleTimeline(
          fallback: 'unavailable',
          now: scheduleEpoch.add(const Duration(seconds: 1)),
        ),
      );
      await h.settle();
      expect(h.native.persisted, isNull);
      expect(h.controller.syncError, isNotNull);
      expect(
        h.applied,
        hasLength(1),
      ); // Disable must not clear the existing photo.
    },
  );

  test(
    'opt-in caches only own timeline after fallback and upcoming photos download',
    () async {
      h.repository.own = scheduleTimeline(schedules: [scheduleEntry()]);
      await h.initialize();
      h.photos.pending['scheduled'] = Completer<Uint8List>();
      final syncing = h.controller.setAutoSync(true);
      await h.settle();
      expect(h.applied, hasLength(1));
      expect(h.native.payloads, isEmpty);
      h.photos.pending['scheduled']!.complete(testPng);
      await syncing;
      final payload = h.native.payloads.single;
      expect(payload['scope'], contains('me:0/couple/paired'));
      expect(payload['serverTimeMs'], scheduleEpoch.millisecondsSinceEpoch);
      expect(
        (payload['photos'] as Map).keys,
        unorderedEquals(['fallback', 'scheduled']),
      );
      expect(h.photos.downloads, isNot(contains('partner-only')));
      final entry = (payload['schedules'] as List).single as Map;
      expect(
        entry['activeFromMs'],
        scheduleEpoch.add(const Duration(seconds: 10)).millisecondsSinceEpoch,
      );
      expect(entry['createdAtMs'], scheduleEpoch.millisecondsSinceEpoch);
      expect(
        payload.keys,
        unorderedEquals([
          'scope',
          'serverTimeMs',
          'fallbackAssetId',
          'schedules',
          'photos',
        ]),
      );
    },
  );

  test('empty own timeline clears photo then caches empty truth', () async {
    h.repository.own = scheduleTimeline(fallback: null);
    await h.initialize();
    await h.controller.setAutoSync(true);
    expect(h.controller.ownCurrentAssetId, isNull);
    expect(h.clears, 2);
    expect(h.native.payloads.single['photos'], isEmpty);
    expect(h.native.payloads.single['fallbackAssetId'], isNull);
  });

  test(
    'auto-sync off disables native timeline without clearing photo',
    () async {
      await h.initialize();
      await h.controller.setAutoSync(true);
      final clears = h.clears;
      await h.controller.setAutoSync(false);
      expect(h.events.last, 'disable');
      expect(h.clears, clears);
      expect(h.applied, hasLength(1));
      expect(h.native.persisted, isNull);
      expect(h.controller.autoSyncEnabled, isFalse);
    },
  );

  test(
    'manual selection waits for in-flight cache then disables before image apply',
    () async {
      await h.initialize();
      h.native.pendingCache = Completer<void>();
      final syncing = h.controller.setAutoSync(true);
      await h.settle();
      expect(h.events.last, 'cache-start');
      final manual = h.controller.applyManualPhoto(testPng);
      await h.settle();
      expect(h.events.last, 'cache-start');
      h.native.pendingCache!.complete();
      await syncing;
      await manual;
      expect(h.events.sublist(h.events.indexOf('cache-start')), [
        'cache-start',
        'cache-done',
        'disable',
        'photo-start',
        'photo-done',
      ]);
      expect(h.controller.autoSyncEnabled, isFalse);
      expect(h.native.persisted, isNull);
    },
  );

  test(
    'failed native disable prevents manual apply and exposes retryable error',
    () async {
      await h.initialize();
      h.native.disableFailure = StateError('native disk failure');
      await expectLater(
        h.controller.applyManualPhoto(testPng),
        throwsStateError,
      );
      expect(h.applied, isEmpty);
      expect(h.controller.syncError, isNotNull);
      h.native.disableFailure = null;
      await h.controller.applyManualPhoto(testPng);
      expect(h.applied, hasLength(1));
    },
  );

  test(
    'stale in-flight cache completes before auth clear, never after it',
    () async {
      await h.initialize();
      h.native.pendingCache = Completer<void>();
      final syncing = h.controller.setAutoSync(true);
      await h.settle();
      h.auth.change(null);
      await h.settle();
      expect(h.events.last, 'cache-start');
      h.native.pendingCache!.complete();
      await syncing;
      await h.settle();
      expect(h.events.sublist(h.events.indexOf('cache-start')), [
        'cache-start',
        'cache-done',
        'clear-timeline',
        'clear-photo',
      ]);
      expect(h.native.persisted, isNull);
      expect(h.applied, isEmpty);
    },
  );

  test(
    'disposed valid opted-in scope leaves completed Android cache running',
    () async {
      await h.initialize();
      await h.controller.setAutoSync(true);
      final events = List<String>.from(h.events);
      h.controller.dispose();
      await h.settle();
      expect(h.events, events);
      expect(h.native.persisted, isNotNull);
    },
  );

  test(
    'dispose after sign-out still executes already queued auth cleanup',
    () async {
      await h.initialize();
      h.native.pendingCache = Completer<void>();
      final syncing = h.controller.setAutoSync(true);
      await h.settle();
      h.auth.change(null);
      h.controller.dispose();
      h.native.pendingCache!.complete();
      await syncing;
      await h.settle();
      expect(h.native.persisted, isNull);
      expect(h.applied, isEmpty);
      expect(h.events, contains('clear-timeline'));
    },
  );

  test(
    'iOS/unsupported platform remains foreground-only, never claims cache',
    () async {
      await h.initialize(android: false);
      await h.controller.setAutoSync(true);
      expect(h.applied, hasLength(1));
      expect(h.native.payloads, isEmpty);
      expect(h.controller.backgroundCacheSupported, isFalse);
      expect(h.controller.status, 'Ready');
    },
  );

  test(
    'TTL payload excludes ended schedules and starts at or after 24h',
    () async {
      h.repository.own = scheduleTimeline(
        schedules: [
          scheduleEntry(id: 'ended', asset: 'expired', from: -10, until: 0),
          scheduleEntry(id: 'last', asset: 'last', from: 86399, until: 90000),
          scheduleEntry(
            id: 'too-late',
            asset: 'too-late',
            from: 86400,
            until: 90001,
          ),
        ],
      );
      await h.initialize();
      await h.controller.setAutoSync(true);
      expect(ScheduleController.nativeCacheTtl, const Duration(hours: 24));
      expect(
        (h.native.payloads.single['schedules'] as List).map(
          (entry) => (entry as Map)['scheduleId'],
        ),
        ['last'],
      );
      expect(h.photos.downloads, ['fallback', 'last']);
    },
  );

  test(
    '12 photos and 100 schedules fit exactly; larger truth disables instead of truncating',
    () async {
      h.repository.own = scheduleTimeline(
        schedules: [
          for (var i = 0; i < 100; i++)
            scheduleEntry(id: 's$i', asset: 'p${i % 11}', from: 10, until: 50),
        ],
      );
      await h.initialize();
      await h.controller.setAutoSync(true);
      expect((h.native.payloads.single['photos'] as Map), hasLength(12));
      expect((h.native.payloads.single['schedules'] as List), hasLength(100));
      expect(h.controller.cachedAssetCount, 12);
      h.repository.stream.add(
        scheduleTimeline(
          schedules: [
            ...h.repository.own.schedules,
            scheduleEntry(id: 'overflow', asset: 'p0'),
          ],
          now: scheduleEpoch.add(const Duration(seconds: 1)),
        ),
      );
      await h.settle();
      expect(h.native.payloads, hasLength(1));
      expect(h.native.persisted, isNull);
      expect(h.controller.status, contains('exceeds'));
    },
  );

  test(
    'photo overflow bounds downloads and cannot cache incorrect truncated overlaps',
    () async {
      h.repository.own = scheduleTimeline(
        schedules: [
          for (var i = 0; i < 20; i++)
            scheduleEntry(
              id: 's$i',
              asset: 'p$i',
              from: i + 1,
              until: 50,
              created: i,
            ),
        ],
      );
      await h.initialize();
      await h.controller.setAutoSync(true);
      expect(h.photos.downloads, hasLength(12));
      expect(h.controller.cachedAssetCount, 12);
      expect(h.native.payloads, isEmpty);
      expect(h.controller.status, contains('Foreground sync only'));
    },
  );

  test(
    'oversized PNG fails validation and never enters native cache',
    () async {
      await h.initialize();
      h.photos.photos['fallback'] = Uint8List(maxPhotoBytes + 1);
      await h.controller.setAutoSync(true);
      expect(h.controller.syncError, isA<FormatException>());
      expect(h.controller.cachedAssetCount, 0);
      expect(h.native.payloads, isEmpty);
      expect(h.applied, isEmpty);
    },
  );

  test(
    'queue execution anchors exact server now after a delayed native photo write',
    () async {
      await h.initialize();
      h.pendingApply = Completer<void>();
      final syncing = h.controller.setAutoSync(true);
      await h.settle();
      h.elapsed = const Duration(milliseconds: 7123);
      h.pendingApply!.complete();
      await syncing;
      expect(
        h.native.payloads.single['serverTimeMs'],
        scheduleEpoch.millisecondsSinceEpoch + 7123,
      );
    },
  );

  test(
    'suspending app preserves existing cached schedule and suppresses foreground downloads',
    () async {
      await h.initialize();
      await h.controller.setAutoSync(true);
      final persisted = h.native.persisted;
      h.controller.setForeground(false);
      h.elapsed = const Duration(seconds: 9);
      await h.controller.syncNow();
      expect(h.native.persisted, same(persisted));
      expect(h.native.payloads, hasLength(1));
      expect(h.photos.downloads, hasLength(1));
    },
  );

  test(
    'mutable generated DTO cannot change an accepted scope snapshot',
    () async {
      final entry = scheduleEntry();
      h.repository.own = scheduleTimeline(schedules: [entry]);
      await h.initialize();
      entry.assetId = 'mutated';
      h.repository.own.fallbackAssetId = 'mutated-fallback';
      h.elapsed = const Duration(seconds: 10);
      h.controller.resolveNow();
      expect(h.controller.ownCurrentAssetId, 'scheduled');
      expect(h.controller.ownTimeline!.fallbackAssetId, 'fallback');
    },
  );

  test(
    'dispose must disable stale in-flight cache after a newer received timeline',
    () async {
      await h.initialize();
      h.native.pendingCache = Completer<void>();
      final syncing = h.controller.setAutoSync(true);
      await h.settle();
      h.repository.stream.add(
        scheduleTimeline(
          fallback: 'new',
          now: scheduleEpoch.add(const Duration(seconds: 1)),
        ),
      );
      h.controller.dispose();
      h.native.pendingCache!.complete();
      await syncing;
      await h.settle();
      expect(h.native.persisted, isNull);
      expect(h.events.last, 'disable');
    },
  );

  test(
    'same user sign-out/sign-in revision cannot restore prior opt-in or request',
    () async {
      await h.initialize();
      await h.controller.setAutoSync(true);
      h.repository.createFailure = StateError('uncertain commit');
      await h.controller.createPartnerSchedule(
        'mine',
        scheduleEpoch.add(const Duration(minutes: 1)),
        scheduleEpoch.add(const Duration(minutes: 2)),
      );
      final clears = h.clears;
      h.auth.change(null);
      h.auth.change('me');
      await h.settle();
      expect(h.pairing.authRevision, 2);
      expect(h.controller.pendingCreate, isNull);
      expect(h.controller.autoSyncEnabled, isFalse);
      expect(h.clears, greaterThan(clears));
      expect(h.native.persisted, isNull);
    },
  );
}
