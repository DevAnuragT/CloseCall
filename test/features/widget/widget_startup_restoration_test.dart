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

class _RestoringAuth extends FakeAuth {
  final validated = Completer<void>();
  @override
  Future<void> initialize() async {
    await validated.future;
    change('me');
  }
}

class _DelayedCouples extends FakeCouples {
  Completer<Couple?>? pending;
  Object? failure;
  @override
  Future<Couple?> coupleForUser(String id) async {
    if (failure != null) throw failure!;
    return pending?.future ?? couple;
  }
}

class _Delivery extends FakeSchedules implements DeliveryConsentRepository {
  Object? deliveryFailure;
  @override
  Future<WidgetDeliveryState> getDeliveryState() async {
    if (deliveryFailure != null) throw deliveryFailure!;
    return WidgetDeliveryState(
      coupleId: own.coupleId,
      recipientId: own.recipientId,
      autoUpdateEnabled: own.autoUpdateEnabled,
      version: 0,
    );
  }

  @override
  Future<WidgetDeliveryState> setDeliveryConsent(bool enabled) async {
    own = own.copyWith(autoUpdateEnabled: enabled);
    return getDeliveryState();
  }
}

class _Harness {
  _Harness({FakeAuth? auth}) : auth = auth ?? FakeAuth();
  final FakeAuth auth;
  final couples = _DelayedCouples();
  final repository = _Delivery();
  final photos = ControlledScheduleMedia();
  final store = MemoryWidgetConsentStore();
  final events = <String>[];
  late final native = FakeRestoringTimeline(events);
  late final pairing = PairingController(session: auth, repository: couples);
  late final writer = LocalWidgetWriter(
    timeline: native,
    applyPhoto: (photo) async {
      native.displayed = Uint8List.fromList(photo);
      events.add('apply');
    },
    clearPhoto: () async {
      native.displayed = null;
      events.add('clear-photo');
    },
  );
  late final controller = ScheduleController(
    pairing: pairing,
    repository: repository,
    mediaRepository: photos,
    localWriter: writer,
    consentStore: store,
    now: () => scheduleEpoch,
  );
  Future<void> start({bool validated = true}) async {
    if (validated) {
      auth.change('me');
      await pairing.initialize();
    }
    controller;
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 120; i++) {
      await Future<void>.value();
    }
  }

  void savePartner({bool enabled = true}) {
    native.ownerScope = 'me/couple';
    native.ownerAsset = 'fallback';
    native.displayed = testPng;
    store.value = WidgetDeviceConsent(
      userId: 'me',
      coupleId: 'couple',
      enabled: enabled,
    );
    repository.own = repository.own.copyWith(autoUpdateEnabled: true);
  }

  Future<void> dispose() async {
    controller.dispose();
    pairing.dispose();
    auth.dispose();
    await repository.dispose();
    await settle();
  }
}

void main() {
  test(
    'same validated scope restores without clear, rewrite, download or startup progress',
    () async {
      final h = _Harness()..savePartner();
      addTearDown(h.dispose);
      await h.start();
      expect(h.native.restoredScopes, ['me/couple']);
      expect(h.events, isNot(contains('clear-photo')));
      expect(h.events, isNot(contains('clear-timeline')));
      expect(h.events, isNot(contains('apply')));
      expect(h.photos.downloads, isEmpty);
      expect(h.controller.currentPhoto, testPng);
      expect(h.controller.downloadingNewPhoto, isFalse);
      expect(h.controller.status, 'Ready');
    },
  );

  test(
    'unknown startup only suspends, partial auth waits for loaded membership',
    () async {
      final auth = _RestoringAuth();
      final h = _Harness(auth: auth)..savePartner(enabled: false);
      addTearDown(h.dispose);
      h.couples.pending = Completer<Couple?>();
      await h.start(validated: false);
      expect(h.events, ['suspend']);
      expect(h.native.restoredScopes, isEmpty);
      final loading = h.pairing.initialize();
      auth.validated.complete();
      await h.settle();
      expect(h.pairing.userId, 'me');
      expect(h.pairing.hasLoadedPairing, isFalse);
      expect(h.native.restoredScopes, isEmpty);
      expect(h.events, ['suspend']);
      h.couples.pending!.complete(h.couples.couple);
      await loading;
      await h.settle();
      expect(h.native.displayed, testPng);
      expect(h.native.restoredScopes, ['me/couple']);
      expect(h.controller.partnerUpdatesEnabled, isFalse);
    },
  );

  test(
    'signed-out validation and unknown/mismatch/expired owners fail closed',
    () async {
      for (final owner in [null, 'other/couple', 'me/couple']) {
        final h = _Harness()..savePartner(enabled: false);
        h.native.ownerScope = owner;
        h.native.fresh = owner != 'me/couple';
        await h.start();
        expect(h.native.displayed, isNull);
        expect(h.events, contains('clear-timeline'));
        await h.dispose();
      }
      final h = _Harness()..savePartner();
      addTearDown(h.dispose);
      await h.start(validated: false);
      await h.pairing.initialize();
      await h.settle();
      expect(h.native.displayed, isNull);
      expect(h.events, contains('clear-photo'));
    },
  );

  test(
    'private authorization revocation clears; ordinary offline errors retain owned photo paused',
    () async {
      for (final failure in [
        StateError('offline'),
        ScheduleFailure(code: 'unauthorized'),
      ]) {
        final h = _Harness()..savePartner();
        h.repository.deliveryFailure = failure;
        await h.start();
        expect(h.controller.partnerUpdatesEnabled, isFalse);
        expect(
          h.native.displayed,
          failure is ScheduleFailure ? isNull : testPng,
        );
        expect(h.native.suspended, isTrue);
        await h.dispose();
      }
    },
  );

  test(
    'failed startup membership validation cannot use held partner photo as offline authorization',
    () async {
      final auth = _RestoringAuth();
      final h = _Harness(auth: auth)..savePartner();
      addTearDown(h.dispose);
      h.couples.failure = StateError('offline before membership validation');
      await h.start(validated: false);
      expect(
        h.native.displayed,
        testPng,
      ); // bounded hold while validation is pending
      final loading = h.pairing.initialize();
      auth.validated.complete();
      await loading;
      await h.settle();
      expect(h.pairing.hasLoadedPairing, isFalse);
      expect(h.native.restoredScopes, isEmpty);
      expect(h.native.displayed, isNull);
    },
  );

  test(
    'same unpaired manual owner survives, navigation does not reset it, pairing changes clear',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.couples.couple = null;
      h.native
        ..ownerScope = 'me/unpaired'
        ..displayed = testPng;
      await h.start();
      expect(h.native.displayed, testPng);
      h.controller.setForeground(false);
      h.controller.setForeground(true);
      await h.settle();
      expect(h.events, isNot(contains('clear-photo')));
      await h.controller.applyManualPhoto(testPng);
      expect(h.native.ownerScope, 'me/unpaired');
      h.couples.couple = Couple(id: 'new-couple', memberIds: ['me', 'partner']);
      await h.pairing.refresh();
      await h.settle();
      expect(h.native.displayed, isNull);
      expect(h.events, contains('clear-photo'));
    },
  );

  test(
    'progress only covers newly resolved current download; manual/off prevents late apply',
    () async {
      final h = _Harness()..savePartner();
      addTearDown(h.dispose);
      await h.start();
      h.photos.pending['new'] = Completer<Uint8List>();
      h.repository.stream.add(
        h.repository.own.copyWith(
          fallbackAssetId: 'new',
          serverTime: scheduleEpoch.add(const Duration(seconds: 1)),
        ),
      );
      await h.settle();
      expect(h.controller.downloadingNewPhoto, isTrue);
      await h.controller.applyManualPhoto(testPng);
      expect(h.controller.downloadingNewPhoto, isFalse);
      h.photos.pending['new']!.complete(testPng);
      await h.settle();
      expect(h.events.where((e) => e == 'apply'), hasLength(1));
      expect(h.native.ownerAsset, isNull);
      expect(h.native.ownerScope, 'me/couple');
    },
  );
}
