import 'dart:async';
import 'dart:typed_data';

import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/widget/data/local_widget_writer.dart';
import 'package:closecall/features/widget/data/schedule_repository.dart';
import 'package:closecall/features/widget/data/widget_consent_store.dart';
import 'package:closecall/features/widget/presentation/schedule_controller.dart';
import 'package:closecall_client/closecall_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

const optedIn = WidgetDeviceConsent(
  userId: 'me',
  coupleId: 'couple',
  enabled: true,
);

WidgetTimeline deliveryTimeline({
  String? latest,
  int version = 0,
  bool enabled = true,
  int seconds = 0,
  List<WidgetScheduleEntry> schedules = const [],
}) =>
    scheduleTimeline(
      schedules: schedules,
      now: scheduleEpoch.add(Duration(seconds: seconds)),
    ).copyWith(
      latestAssetId: latest,
      deliveryVersion: version,
      autoUpdateEnabled: enabled,
    );

class DeliverySchedules extends FakeSchedules
    implements DeliveryConsentRepository {
  final consentCalls = <bool>[];
  Object? consentFailure;
  Completer<void>? pendingConsent;
  int stateReads = 0;
  int timelineReads = 0;

  @override
  Future<WidgetTimeline> currentTimeline() {
    timelineReads++;
    return super.currentTimeline();
  }

  @override
  Future<WidgetDeliveryState> getDeliveryState() async {
    stateReads++;
    return WidgetDeliveryState(
      coupleId: own.coupleId,
      recipientId: own.recipientId,
      autoUpdateEnabled: own.autoUpdateEnabled,
      version: own.deliveryVersion,
      latestAssetId: own.latestAssetId,
    );
  }

  @override
  Future<WidgetDeliveryState> setDeliveryConsent(bool enabled) async {
    consentCalls.add(enabled);
    if (pendingConsent != null) await pendingConsent!.future;
    if (consentFailure != null) throw consentFailure!;
    own = own.copyWith(autoUpdateEnabled: enabled);
    return getDeliveryState();
  }

  void publish(WidgetTimeline timeline) {
    own = timeline;
    stream.add(timeline);
  }
}

class DelayedStore extends MemoryWidgetConsentStore {
  Completer<void>? pendingWrite;
  final writes = <WidgetDeviceConsent?>[];
  int active = 0;
  int maxActive = 0;

  @override
  Future<void> write(WidgetDeviceConsent? consent) async {
    active++;
    if (active > maxActive) maxActive = active;
    writes.add(consent);
    if (pendingWrite != null) await pendingWrite!.future;
    value = consent;
    active--;
  }
}

class RestoreAuth extends FakeAuth {
  final restoration = Completer<void>();

  @override
  Future<void> initialize() async {
    await restoration.future;
    change('me');
  }
}

class DeliveryHarness {
  DeliveryHarness({WidgetConsentStore? store, FakeAuth? auth})
    : store = store ?? MemoryWidgetConsentStore(),
      auth = auth ?? FakeAuth();

  final WidgetConsentStore store;
  final FakeAuth auth;
  final couples = FakeCouples();
  final repository = DeliverySchedules();
  final photos = ControlledScheduleMedia();
  final events = <String>[];
  final applied = <Uint8List>[];
  late final PairingController pairing;
  late final FakeNativeTimeline native;
  late final ScheduleController controller;
  bool controllerDisposed = false;
  Duration elapsed = Duration.zero;

  Future<void> start({bool validated = true, String user = 'me'}) async {
    if (validated) auth.change(user);
    pairing = PairingController(session: auth, repository: couples);
    if (validated) await pairing.initialize();
    native = FakeNativeTimeline(events);
    controller = ScheduleController(
      pairing: pairing,
      repository: repository,
      mediaRepository: photos,
      consentStore: store,
      elapsed: () => elapsed,
      now: () => scheduleEpoch,
      localWriter: LocalWidgetWriter(
        timeline: native,
        applyPhoto: (bytes) async {
          applied.add(Uint8List.fromList(bytes));
          events.add('apply');
        },
        clearPhoto: () async => events.add('clear'),
      ),
    );
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 80; i++) {
      await Future<void>.value();
    }
  }

  Future<void> dispose() async {
    if (!controllerDisposed) controller.dispose();
    pairing.dispose();
    auth.dispose();
    await repository.dispose();
    await settle();
  }
}

void main() {
  test(
    'a requested device pause persists across immediate controller shutdown',
    () async {
      for (final manual in [false, true]) {
        final store = MemoryWidgetConsentStore();
        final h = DeliveryHarness(store: store);
        await h.start();
        await h.controller.setPartnerUpdates(true);
        final pause = manual
            ? h.controller.applyManualPhoto(testPng)
            : h.controller.setPartnerUpdates(false);
        h.controller.dispose();
        h.controllerDisposed = true;
        await pause;
        await h.settle();
        expect(store.value!.enabled, isFalse);
        await h.dispose();
      }
    },
  );

  test(
    'failed server enable cannot opt in or persist enabled device consent',
    () async {
      final store = MemoryWidgetConsentStore();
      final h = DeliveryHarness(store: store);
      addTearDown(h.dispose);
      await h.start();
      h.repository.consentFailure = StateError('offline');
      await h.controller.setPartnerUpdates(true);
      expect(h.controller.partnerUpdatesEnabled, isFalse);
      expect(h.controller.partnerUpdatesError, isNotNull);
      expect(h.controller.partnerUpdatesBusy, isFalse);
      expect(store.value, isNull);
      expect(h.applied, isEmpty);
    },
  );

  test(
    'persisted local opt-in respects account-level opt-out on restoration',
    () async {
      final store = MemoryWidgetConsentStore()..value = optedIn;
      final h = DeliveryHarness(store: store);
      addTearDown(h.dispose);
      h.repository.own = deliveryTimeline(
        latest: 'sent',
        version: 1,
        enabled: false,
      );
      await h.start();
      expect(h.controller.partnerUpdatesEnabled, isFalse);
      expect(store.value!.enabled, isFalse);
      expect(h.repository.consentCalls, isEmpty);
      expect(h.photos.downloads, isEmpty);
    },
  );

  test('account consent alone never opts in a fresh device', () async {
    final h = DeliveryHarness();
    addTearDown(h.dispose);
    h.repository.own = deliveryTimeline(latest: 'sent', version: 1);
    await h.start();
    expect(h.controller.ownCurrentAssetId, 'sent');
    expect(h.controller.partnerUpdatesEnabled, isFalse);
    expect(h.photos.downloads, isEmpty);
    expect(h.applied, isEmpty);
    expect(h.repository.stateReads, 0);
  });

  test(
    'explicit enable persists and partner notice downloads/applies automatically',
    () async {
      final store = MemoryWidgetConsentStore();
      final h = DeliveryHarness(store: store);
      addTearDown(h.dispose);
      await h.start();
      await h.controller.setPartnerUpdates(true);
      expect(h.repository.consentCalls, [true]);
      expect(store.value!.matches('me', 'couple'), isTrue);
      expect(store.value!.enabled, isTrue);
      expect(h.controller.partnerUpdatesEnabled, isTrue);
      expect(h.controller.partnerUpdatesBusy, isFalse);
      h.repository.publish(
        deliveryTimeline(latest: 'partner-send', version: 1, seconds: 1),
      );
      await h.settle();
      expect(h.controller.ownCurrentAssetId, 'partner-send');
      expect(h.photos.downloads, ['fallback', 'partner-send']);
      expect(h.applied, hasLength(2));
      expect(h.native.payloads.last['fallbackAssetId'], 'partner-send');
      expect(h.repository.fallbacks, isEmpty);
      expect(h.controller.ownTimeline!.fallbackAssetId, 'fallback');
      expect(h.controller.status, isNot(contains('acknowledged')));
    },
  );

  test(
    'restart restores only the validated matching account/couple and fetches fresh truth',
    () async {
      final store = MemoryWidgetConsentStore()..value = optedIn;
      final auth = RestoreAuth();
      final h = DeliveryHarness(store: store, auth: auth);
      addTearDown(h.dispose);
      h.repository.own = deliveryTimeline(latest: 'fresh', version: 2);
      await h.start(validated: false);
      expect(store.value, same(optedIn));
      expect(h.controller.partnerUpdatesEnabled, isFalse);
      expect(h.events, ['clear-timeline', 'clear']);
      final initializing = h.pairing.initialize();
      auth.restoration.complete();
      await initializing;
      await h.settle();
      expect(h.controller.partnerUpdatesEnabled, isTrue);
      expect(h.repository.consentCalls, isEmpty);
      expect(h.repository.stateReads, 1);
      expect(h.repository.timelineReads, greaterThanOrEqualTo(2));
      expect(h.photos.downloads, ['fresh']);
      expect(h.applied, hasLength(1));
      expect(store.value!.enabled, isTrue);
    },
  );

  test(
    'actual persisted enable restores in a second controller, pause survives restart',
    () async {
      final store = MemoryWidgetConsentStore();
      final first = DeliveryHarness(store: store);
      await first.start();
      await first.controller.setPartnerUpdates(true);
      await first.dispose();
      final second = DeliveryHarness(store: store);
      second.repository.own = deliveryTimeline(latest: 'second', version: 1);
      await second.start();
      expect(second.controller.partnerUpdatesEnabled, isTrue);
      await second.controller.applyManualPhoto(testPng);
      expect(store.value!.enabled, isFalse);
      expect(second.repository.consentCalls, isEmpty);
      await second.dispose();
      final third = DeliveryHarness(store: store);
      addTearDown(third.dispose);
      third.repository.own = deliveryTimeline(latest: 'third', version: 2);
      await third.start();
      expect(third.controller.partnerUpdatesEnabled, isFalse);
      expect(third.photos.downloads, isEmpty);
    },
  );

  test(
    'persisted consent for a different account or couple never restores',
    () async {
      for (final consent in [
        const WidgetDeviceConsent(
          userId: 'other',
          coupleId: 'couple',
          enabled: true,
        ),
        const WidgetDeviceConsent(
          userId: 'me',
          coupleId: 'previous-couple',
          enabled: true,
        ),
      ]) {
        final store = MemoryWidgetConsentStore()..value = consent;
        final h = DeliveryHarness(store: store);
        h.repository.own = deliveryTimeline(latest: 'sent', version: 1);
        await h.start();
        expect(h.controller.partnerUpdatesEnabled, isFalse);
        expect(store.value!.enabled, isFalse);
        expect(h.photos.downloads, isEmpty);
        expect(h.repository.stateReads, 0);
        await h.dispose();
      }
    },
  );

  test(
    'off persists immediately and remains off when server opt-out fails',
    () async {
      final store = MemoryWidgetConsentStore();
      final h = DeliveryHarness(store: store);
      addTearDown(h.dispose);
      await h.start();
      await h.controller.setPartnerUpdates(true);
      h.repository.consentFailure = StateError('offline');
      final disabling = h.controller.setPartnerUpdates(false);
      expect(h.controller.partnerUpdatesEnabled, isFalse);
      await disabling;
      expect(store.value!.enabled, isFalse);
      expect(h.repository.consentCalls, [true, false]);
      expect(h.controller.partnerUpdatesError, isNotNull);
      expect(h.controller.status, contains('other opted-in devices'));
      expect(h.native.persisted, isNull);
      final count = h.applied.length;
      h.repository.publish(
        deliveryTimeline(latest: 'new', version: 1, seconds: 1),
      );
      await h.settle();
      expect(h.applied, hasLength(count));
    },
  );

  test(
    'manual pause and late download cannot overwrite manual photo or opt out other devices',
    () async {
      final store = MemoryWidgetConsentStore();
      final h = DeliveryHarness(store: store);
      addTearDown(h.dispose);
      await h.start();
      await h.controller.setPartnerUpdates(true);
      h.photos.pending['delayed'] = Completer<Uint8List>();
      h.repository.publish(
        deliveryTimeline(latest: 'delayed', version: 1, seconds: 1),
      );
      await h.settle();
      await h.controller.applyManualPhoto(testPng);
      final count = h.applied.length;
      h.photos.pending['delayed']!.complete(testPng);
      await h.settle();
      expect(h.applied, hasLength(count));
      expect(h.controller.partnerUpdatesEnabled, isFalse);
      expect(store.value!.enabled, isFalse);
      expect(h.repository.consentCalls, [true]);
      expect(h.repository.own.autoUpdateEnabled, isTrue);
      expect(h.native.persisted, isNull);
    },
  );

  test(
    'duplicate or older deliveries cannot replace newer latest or repeat native writes',
    () async {
      final h = DeliveryHarness();
      addTearDown(h.dispose);
      await h.start();
      await h.controller.setPartnerUpdates(true);
      final newest = deliveryTimeline(latest: 'new', version: 3, seconds: 3);
      h.repository.publish(newest);
      await h.settle();
      final count = h.events.length;
      h.repository.publish(
        newest.copyWith(
          serverTime: scheduleEpoch.add(const Duration(seconds: 4)),
        ),
      );
      h.repository.publish(
        deliveryTimeline(latest: 'old', version: 2, seconds: 5),
      );
      h.repository.publish(
        deliveryTimeline(latest: 'old', version: 3, seconds: 6),
      );
      h.repository.publish(
        deliveryTimeline(latest: 'future-but-old-time', version: 4, seconds: 1),
      );
      await h.settle();
      await h.controller.syncNow();
      expect(h.controller.ownCurrentAssetId, 'new');
      expect(h.events, hasLength(count));
      expect(h.photos.downloads, ['fallback', 'new']);
    },
  );

  test(
    'consent change with same delivery version pauses, true never silently re-enables',
    () async {
      final store = MemoryWidgetConsentStore();
      final h = DeliveryHarness(store: store);
      addTearDown(h.dispose);
      await h.start();
      await h.controller.setPartnerUpdates(true);
      h.repository.publish(
        deliveryTimeline(latest: 'sent', version: 1, seconds: 1),
      );
      await h.settle();
      h.repository.publish(
        deliveryTimeline(
          latest: 'sent',
          version: 1,
          seconds: 2,
          enabled: false,
        ),
      );
      await h.settle();
      expect(h.controller.partnerUpdatesEnabled, isFalse);
      expect(store.value!.enabled, isFalse);
      h.repository.publish(
        deliveryTimeline(latest: 'sent', version: 1, seconds: 3),
      );
      await h.settle();
      expect(h.controller.partnerUpdatesEnabled, isFalse);
      expect(h.repository.consentCalls, [true]);
    },
  );

  test(
    'latest is cached baseline during an active schedule and after its boundary',
    () async {
      final h = DeliveryHarness();
      addTearDown(h.dispose);
      h.repository.own = deliveryTimeline(
        latest: 'latest',
        version: 1,
        schedules: [scheduleEntry(from: -1, until: 20)],
      );
      await h.start();
      await h.controller.setPartnerUpdates(true);
      final payload = h.native.payloads.single;
      expect(h.controller.ownCurrentAssetId, 'scheduled');
      expect(payload['fallbackAssetId'], 'latest');
      expect(
        (payload['photos'] as Map).keys,
        unorderedEquals(['scheduled', 'latest']),
      );
      expect(h.photos.downloads, isNot(contains('fallback')));
      h.elapsed = const Duration(seconds: 20);
      h.controller.resolveNow();
      await h.settle();
      expect(h.controller.ownCurrentAssetId, 'latest');
      expect(h.applied, hasLength(2));
      expect(h.repository.fallbacks, isEmpty);
    },
  );

  test(
    'observed sign-out, re-pair and account switch clear previous opt-in',
    () async {
      for (final change in ['sign-out', 're-pair', 'account']) {
        final store = MemoryWidgetConsentStore();
        final h = DeliveryHarness(store: store);
        await h.start();
        await h.controller.setPartnerUpdates(true);
        if (change == 'sign-out') {
          h.auth.change(null);
          h.auth.change('me');
        } else if (change == 're-pair') {
          h.couples.couple = Couple(id: 'new', memberIds: ['me', 'partner']);
          await h.pairing.refresh();
        } else {
          h.couples.couple = Couple(
            id: 'couple',
            memberIds: ['other', 'partner'],
          );
          h.auth.change('other');
        }
        await h.settle();
        expect(h.controller.partnerUpdatesEnabled, isFalse);
        expect(store.value, isNull);
        expect(h.native.persisted, isNull);
        await h.dispose();
      }
    },
  );

  test(
    'late download after account switch cannot apply old recipient photo',
    () async {
      final h = DeliveryHarness();
      addTearDown(h.dispose);
      await h.start();
      await h.controller.setPartnerUpdates(true);
      h.photos.pending['delayed'] = Completer<Uint8List>();
      h.repository.publish(
        deliveryTimeline(latest: 'delayed', version: 1, seconds: 1),
      );
      await h.settle();
      h.auth.change(null);
      h.photos.pending['delayed']!.complete(testPng);
      await h.settle();
      expect(h.applied, hasLength(1));
      expect(h.controller.ownTimeline, isNull);
      expect(h.native.persisted, isNull);
      expect(h.controller.partnerUpdatesEnabled, isFalse);
    },
  );

  test(
    'serialized late consent write cannot restore old consent after scope reset',
    () async {
      final store = DelayedStore();
      final h = DeliveryHarness(store: store);
      addTearDown(h.dispose);
      await h.start();
      store.pendingWrite = Completer<void>();
      final enabling = h.controller.setPartnerUpdates(true);
      await h.settle();
      expect(store.active, 1);
      h.auth.change(null);
      h.auth.change('me');
      await h.settle();
      store.pendingWrite!.complete();
      await enabling;
      await h.settle();
      expect(store.maxActive, 1);
      expect(store.value, isNull);
      expect(h.controller.partnerUpdatesEnabled, isFalse);
      expect(h.applied, isEmpty);
    },
  );

  test(
    'off racing pending server enable wins locally and is sent after enable',
    () async {
      final store = MemoryWidgetConsentStore();
      final h = DeliveryHarness(store: store);
      addTearDown(h.dispose);
      await h.start();
      h.repository.pendingConsent = Completer<void>();
      final enabling = h.controller.setPartnerUpdates(true);
      await h.settle();
      final disabling = h.controller.setPartnerUpdates(false);
      await h.settle();
      expect(h.controller.partnerUpdatesEnabled, isFalse);
      expect(store.value!.enabled, isFalse);
      h.repository.pendingConsent!.complete();
      await Future.wait([enabling, disabling]);
      await h.settle();
      expect(h.repository.consentCalls, [true, false]);
      expect(h.repository.own.autoUpdateEnabled, isFalse);
      expect(store.value!.enabled, isFalse);
      expect(h.applied, isEmpty);
    },
  );

  test(
    'manual choice racing pending enable persists pause without revoking account consent',
    () async {
      final store = MemoryWidgetConsentStore();
      final h = DeliveryHarness(store: store);
      addTearDown(h.dispose);
      await h.start();
      h.repository.pendingConsent = Completer<void>();
      final enabling = h.controller.setPartnerUpdates(true);
      await h.settle();
      await h.controller.applyManualPhoto(testPng);
      h.repository.pendingConsent!.complete();
      await enabling;
      await h.settle();
      expect(h.repository.consentCalls, [true]);
      expect(h.repository.own.autoUpdateEnabled, isTrue);
      expect(h.controller.partnerUpdatesEnabled, isFalse);
      expect(store.value!.enabled, isFalse);
      expect(h.applied, hasLength(1));
    },
  );

  test(
    'late previous-scope store completion cannot clear a newly enabled scope',
    () async {
      final store = DelayedStore();
      final h = DeliveryHarness(store: store);
      addTearDown(h.dispose);
      await h.start();
      store.pendingWrite = Completer<void>();
      final previous = h.controller.setPartnerUpdates(true);
      await h.settle();
      h.auth.change(null);
      h.auth.change('me');
      await h.settle();
      final current = h.controller.setPartnerUpdates(true);
      await h.settle();
      expect(h.controller.partnerUpdatesBusy, isTrue);
      store.pendingWrite!.complete();
      await Future.wait([previous, current]);
      await h.settle();
      expect(store.maxActive, 1);
      expect(store.value!.enabled, isTrue);
      expect(h.controller.partnerUpdatesEnabled, isTrue);
      expect(h.controller.partnerUpdatesBusy, isFalse);
      expect(h.applied, hasLength(1));
    },
  );

  testWidgets(
    'stream reconnect catches up automatically with bounded backoff',
    (tester) async {
      final h = DeliveryHarness();
      await h.start();
      await h.controller.setPartnerUpdates(true);
      h.repository.stream.addError(StateError('transport interrupted'));
      h.repository.currentFailure = StateError('still offline');
      await tester.pump(const Duration(seconds: 1));
      expect(h.repository.watches, 1);
      h.repository.currentFailure = null;
      h.repository.own = deliveryTimeline(
        latest: 'missed-send',
        version: 1,
        seconds: 2,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(h.repository.watches, 1);
      await tester.pump(const Duration(seconds: 1));
      await h.settle();
      expect(h.repository.watches, 2);
      expect(h.controller.ownCurrentAssetId, 'missed-send');
      expect(h.applied, hasLength(2));
      expect(h.controller.streamError, isNull);
      await h.dispose();
    },
  );

  testWidgets(
    'off and background cancel reconnect, private auth failures never auto-retry',
    (tester) async {
      for (final stop in ['off', 'background', 'private']) {
        final h = DeliveryHarness();
        await h.start();
        await h.controller.setPartnerUpdates(true);
        h.repository.stream.addError(
          stop == 'private'
              ? ServerpodClientUnauthorized()
              : StateError('offline'),
        );
        if (stop == 'off') await h.controller.setPartnerUpdates(false);
        if (stop == 'background') h.controller.setForeground(false);
        if (stop == 'private') {
          h.controller.setForeground(false);
          h.controller.setForeground(true);
        }
        final reads = h.repository.timelineReads;
        await tester.pump(const Duration(minutes: 2));
        expect(h.repository.timelineReads, reads);
        expect(h.repository.watches, 1);
        await h.dispose();
      }
    },
  );

  test(
    'invalid or corrupt device consent cannot enable automatic updates',
    () async {
      expect(WidgetDeviceConsent.decode('{invalid'), isNull);
      expect(WidgetDeviceConsent.decode('{"userId":false}'), isNull);
      final saved = WidgetDeviceConsent.decode(optedIn.encode())!;
      expect(saved.matches('me', 'couple'), isTrue);
      expect(saved.enabled, isTrue);
    },
  );
}
