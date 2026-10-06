import 'dart:async';

import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/widget/data/local_widget_writer.dart';
import 'package:closecall/features/widget/data/schedule_repository.dart';
import 'package:closecall/features/widget/presentation/schedule_controller.dart';
import 'package:closecall/features/widget/presentation/widget_tab_screen.dart';
import 'package:closecall/features/widget/presentation/editor/widget_editor_screen.dart';
import 'package:closecall/features/widget/presentation/schedule_photo_screen.dart';
import 'package:closecall/features/widget/presentation/default_photo_picker.dart';
import 'package:closecall/features/widget/presentation/hub_photo_picker.dart';
import 'package:closecall/features/widget/presentation/widget_preview_screen.dart';
import 'package:closecall/features/widget/presentation/photo_sync_settings_screen.dart';
import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

class _ConsentSchedules extends FakeSchedules
    implements DeliveryConsentRepository {
  final consents = <bool>[];
  Completer<void>? pendingConsent;
  Object? failure;

  WidgetDeliveryState get delivery => WidgetDeliveryState(
    coupleId: 'couple',
    recipientId: 'me',
    autoUpdateEnabled: own.autoUpdateEnabled,
    version: consents.length,
  );

  @override
  Future<WidgetDeliveryState> getDeliveryState() async => delivery;

  @override
  Future<WidgetDeliveryState> setDeliveryConsent(bool enabled) async {
    consents.add(enabled);
    if (pendingConsent != null) await pendingConsent!.future;
    if (failure != null) throw failure!;
    own = own.copyWith(autoUpdateEnabled: enabled);
    return delivery;
  }
}

void main() {
  late FakeAuth auth;
  late PairingController pairing;
  late _ConsentSchedules repository;
  late FakeMedia photos;
  late MediaController media;
  late ScheduleController schedules;
  final sends = <String>[];
  final sendRequests = <String>[];
  Object? sendFailure;

  setUp(() async {
    auth = FakeAuth()..change('me');
    pairing = PairingController(session: auth, repository: FakeCouples());
    await pairing.initialize();
    repository = _ConsentSchedules();
    photos = FakeMedia();
    sends.clear();
    sendRequests.clear();
    sendFailure = null;
    schedules = ScheduleController(
      pairing: pairing,
      repository: repository,
      mediaRepository: photos,
      localWriter: LocalWidgetWriter(
        timeline: FakeNativeTimeline([], supported: false),
        applyPhoto: (_) async {},
        clearPhoto: () async {},
      ),
      now: () => scheduleEpoch,
    );
    media = MediaController(
      pairing: pairing,
      repository: photos,
      sendAsset: (asset, request) async {
        sends.add(asset);
        sendRequests.add(request);
        if (sendFailure != null) throw sendFailure!;
        return WidgetSendReceipt(
          sendId: 'send',
          requestId: request,
          coupleId: 'couple',
          senderId: 'me',
          recipientId: 'partner',
          assetId: asset,
          version: 1,
          createdAt: scheduleEpoch,
          recipientAutoUpdateEnabled: false,
        );
      },
    );
    for (var i = 0; i < 30; i++) {
      await Future<void>.value();
    }
  });
  tearDown(() async {
    media.dispose();
    schedules.dispose();
    pairing.dispose();
    auth.dispose();
    await repository.dispose();
  });

  var applied = 0;
  Future<void> showTab(WidgetTester tester, {double scale = 1}) =>
      tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: WidgetTabScreen(
              liveMode: true,
              media: media,
              schedules: schedules,
              pickPhoto: () async => testPng,
              applyLocalPhoto: (_) async {
                applied++;
              },
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester, String key) async {
    final hubScroll = find.descendant(
      of: find.byKey(const Key('paired-widget-hub')),
      matching: find.byType(Scrollable),
    );
    tester.state<ScrollableState>(hubScroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      160,
      scrollable: find.descendant(
        of: find.byKey(const Key('paired-widget-hub')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> awaitRoute(WidgetTester tester, Type route) async {
    for (var i = 0; i < 50 && find.byType(route).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
    expect(find.byType(route), findsOneWidget);
  }

  testWidgets(
    'partner photo settings explicitly allows, pauses and resumes via API',
    (tester) async {
      await showTab(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('allow-partner-updates')), findsNothing);
      await open(tester, 'hub-partner-updates');
      final allow = find.byKey(const Key('automatic-photo-sync-toggle'));
      expect(allow, findsOneWidget);
      expect(tester.getTopLeft(allow).dy, lessThan(600));
      expect(find.byType(Switch), findsOneWidget);
      expect(repository.consents, isEmpty);
      expect(
        find.textContaining('Closed-app photo delivery is not available yet.'),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        await tester.scrollUntilVisible(
          find.byKey(const Key('photo-sync-finish')),
          -160,
        );
        await tester.tap(find.byKey(const Key('photo-sync-finish')));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(repository.consents, [true]);
      expect(schedules.partnerUpdatesEnabled, isTrue);
      await open(tester, 'hub-partner-updates');
      expect(find.byType(Switch), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byType(Switch));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(repository.consents, [true, false]);
      expect(schedules.partnerUpdatesEnabled, isFalse);
      expect(find.textContaining('Off on this device'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byType(Switch));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(repository.consents, [true, false, true]);
      expect(schedules.partnerUpdatesEnabled, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('consent busy blocks repeats and failure copy is sanitized', (
    tester,
  ) async {
    repository.pendingConsent = Completer<void>();
    repository.failure = StateError(
      'Authorization=secret raw-user-id private.invalid',
    );
    await showTab(tester);
    await tester.pumpAndSettle();
    await open(tester, 'hub-partner-updates');
    await tester.runAsync(() async {
      await tester.scrollUntilVisible(
        find.byKey(const Key('photo-sync-finish')),
        -160,
      );
      await tester.tap(find.byKey(const Key('photo-sync-finish')));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    final button = tester.widget<SwitchListTile>(
      find.byKey(const Key('automatic-photo-sync-toggle')),
    );
    expect(button.onChanged, isNull);
    expect(repository.consents, [true]);
    await tester.runAsync(() async {
      repository.pendingConsent!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not confirm your photo syncing preference'),
      findsOneWidget,
    );
    expect(find.textContaining('secret'), findsNothing);
    expect(find.textContaining('private.invalid'), findsNothing);
    expect(schedules.partnerUpdatesEnabled, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stale partner switch cannot opt in a reauthenticated account', (
    tester,
  ) async {
    await showTab(tester);
    await tester.pumpAndSettle();
    await open(tester, 'hub-partner-updates');
    final previous = tester.widget<SwitchListTile>(
      find.byKey(const Key('automatic-photo-sync-toggle')),
    );
    auth.change(null);
    auth.change('me');
    await tester.pumpAndSettle();
    previous.onChanged!(true);
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(repository.consents, isEmpty);
    expect(sends, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('library sends only own photos without another upload', (
    tester,
  ) async {
    media.assets = [
      testAsset(id: 'my-saved-photo', uploader: 'me'),
      testAsset(id: 'received'),
    ];
    await showTab(tester);
    await tester.pumpAndSettle();
    await open(tester, 'hub-send-to-partner');
    expect(find.byKey(const ValueKey(('hub-photo', 'received'))), findsNothing);
    expect(find.text('Saved photos'), findsOneWidget);
    expect(find.text('Previously sent'), findsNothing);
    expect(find.text('Not sent'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey(('hub-photo', 'my-saved-photo'))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HubPhotoPreview), findsOneWidget);
    expect(find.bySemanticsLabel('Large photo preview'), findsOneWidget);
    expect(sends, isEmpty);
    expect(photos.requestIds, isEmpty);
    await tester.scrollUntilVisible(
      find.byKey(const Key('hub-photo-confirm')),
      150,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('hub-photo-confirm')));
    await tester.pumpAndSettle();
    expect(sends, ['my-saved-photo']);
    expect(photos.requestIds, isEmpty);
    expect(media.status, contains('queued until your partner allows updates'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'uncertain send uses explicit retry and hides technical failure details',
    (tester) async {
      sendFailure = TimeoutException(
        'Authorization=hidden private.invalid raw-id',
      );
      await showTab(tester);
      await media.sendUploaded(testAsset(id: 'saved-photo', uploader: 'me'));
      await tester.pumpAndSettle();
      expect(media.hasPendingSend, isTrue);
      expect(sends, ['saved-photo']);
      final send = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(const Key('hub-send-to-partner')),
          matching: find.byType(InkWell),
        ),
      );
      expect(send.onTap, isNull);
      await tester.scrollUntilVisible(find.text('Retry photo operation'), 300);
      expect(
        find.textContaining('Could not confirm the send.'),
        findsOneWidget,
      );
      expect(find.textContaining('Authorization'), findsNothing);
      expect(find.textContaining('private.invalid'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(sends, ['saved-photo']); // No background resend.
      sendFailure = null;
      await tester.tap(find.text('Retry photo operation'));
      await tester.pumpAndSettle();
      expect(sends, ['saved-photo', 'saved-photo']);
      expect(sendRequests[0], sendRequests[1]);
      expect(photos.requestIds, isEmpty);
      expect(media.hasPendingSend, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'saved photo preview retries the same send UUID without another upload',
    (tester) async {
      media.assets = [testAsset(id: 'saved', uploader: 'me')];
      sendFailure = TimeoutException('private.invalid raw-id');
      await showTab(tester);
      await tester.pumpAndSettle();
      await open(tester, 'hub-send-to-partner');
      await tester.tap(find.byKey(const ValueKey(('hub-photo', 'saved'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hub-photo-confirm')));
      await tester.pumpAndSettle();
      expect(media.hasPendingSend, isTrue);
      expect(sends, ['saved']);
      expect(find.textContaining('private.invalid'), findsNothing);
      sendFailure = null;
      await tester.scrollUntilVisible(
        find.text('Retry'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(sends, ['saved', 'saved']);
      expect(sendRequests[0], sendRequests[1]);
      expect(photos.requestIds, isEmpty);
      expect(find.text('Sent to your partner.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('hub builds private library and schedules only when opened', (
    tester,
  ) async {
    await showTab(tester);
    await tester.pumpAndSettle();
    expect(find.byType(SchedulePhotoScreen), findsNothing);
    expect(find.byKey(const Key('schedule-asset')), findsNothing);
    expect(find.byType(HubPhotoPicker), findsNothing);
    expect(find.byType(DefaultPhotoPicker), findsNothing);
    expect(find.byKey(const Key('hub-my-photos')), findsNothing);
    for (final label in [
      'Send a photo',
      'My widget',
      'Photos from your partner',
      'Send later',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 100);
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('asset'), findsNothing);
    expect(find.text('Refresh private photos'), findsNothing);
    expect(find.byKey(const Key('allow-partner-updates')), findsNothing);
    await open(tester, 'hub-schedule-photo');
    expect(find.byType(SchedulePhotoScreen), findsOneWidget);
    expect(find.byType(DefaultPhotoPicker), findsNothing);
    expect(find.byType(Switch), findsNothing);
    Navigator.of(tester.element(find.byType(SchedulePhotoScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SchedulePhotoScreen), findsNothing);
    await open(tester, 'hub-my-widget');
    expect(find.byKey(const Key('hub-default-photo-setting')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'saved photo preview cancellation never sends uploads or applies',
    (tester) async {
      media.assets = [testAsset(id: 'private-id', uploader: 'me')];
      await showTab(tester);
      await tester.pumpAndSettle();
      expect(photos.downloads, isEmpty);
      await open(tester, 'hub-send-to-partner');
      await tester.tap(find.byKey(const ValueKey(('hub-photo', 'private-id'))));
      await tester.pumpAndSettle();
      expect(sends, isEmpty);
      expect(photos.requestIds, isEmpty);
      expect(media.selectedAsset, isNull);
      expect(find.text('private-id'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('hub-photo-cancel')),
        150,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('hub-photo-cancel')));
      await tester.pumpAndSettle();
      expect(sends, isEmpty);
      expect(photos.requestIds, isEmpty);
      expect(media.selectedAsset, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'quiet startup checks and successful statuses do not flash photo progress',
    (tester) async {
      media.busy = true;
      media.status = 'Technical private download status';
      schedules.busy = true;
      schedules.syncing = true;
      schedules.status = 'Cached native timeline details';
      await showTab(tester);
      await tester.pump();
      expect(find.byKey(const Key('hub-action-busy')), findsNothing);
      expect(find.byKey(const Key('hub-media-pending')), findsNothing);
      expect(find.textContaining('Technical private'), findsNothing);
      expect(find.textContaining('Cached native'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'open large photo preview removes actions after auth revision changes',
    (tester) async {
      media.assets = [testAsset(id: 'private-id', uploader: 'me')];
      await showTab(tester);
      await tester.pumpAndSettle();
      await open(tester, 'hub-send-to-partner');
      await tester.tap(find.byKey(const ValueKey(('hub-photo', 'private-id'))));
      await tester.pumpAndSettle();
      expect(find.byType(HubPhotoPreview), findsOneWidget);
      auth.change(null);
      auth.change('me');
      await tester.pumpAndSettle();
      expect(find.byType(HubPhotoPreview), findsNothing);
      expect(find.byKey(const Key('hub-photo-confirm')), findsNothing);
      expect(find.textContaining('Pairing changed'), findsWidgets);
      expect(sends, isEmpty);
      expect(photos.requestIds, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'send card opens existing editor and preview without local apply',
    (tester) async {
      applied = 0;
      await showTab(tester);
      await tester.pumpAndSettle();
      await open(tester, 'hub-send-to-partner');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('hub-send-new-photo')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await awaitRoute(tester, WidgetEditorScreen);
      await tester.runAsync(() async {
        Navigator.of(
          tester.element(find.byType(WidgetEditorScreen)),
        ).pop(testPng);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await awaitRoute(tester, WidgetPreviewScreen);
      expect(find.byKey(const Key('preview-save-privately')), findsOneWidget);
      await tester.tap(find.byKey(const Key('preview-cancel')));
      await tester.pumpAndSettle();
      expect(applied, 0);
      expect(sends, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('hub keeps explicit pending schedule retry actions and UUID', (
    tester,
  ) async {
    media.assets = [testAsset(id: 'mine', uploader: 'me')];
    repository.createFailure = TimeoutException('private.invalid secret');
    await showTab(tester);
    await tester.pumpAndSettle();
    final watches = repository.watches;
    await schedules.createPartnerSchedule(
      'mine',
      scheduleEpoch,
      scheduleEpoch.add(const Duration(hours: 1)),
    );
    await tester.pumpAndSettle();
    expect(repository.creates, hasLength(1));
    expect(repository.creates.single.$1, 'mine');
    expect(repository.watches, watches);
    expect(repository.consents, isEmpty);
    expect(find.textContaining('private.invalid'), findsNothing);
    expect(find.byKey(const Key('hub-schedule-pending')), findsOneWidget);
    repository.createFailure = null;
    await tester.ensureVisible(find.text('Retry schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry schedule'));
    await tester.pumpAndSettle();
    expect(repository.creates, hasLength(2));
    expect(repository.creates[0], repository.creates[1]);
    expect(schedules.pendingCreate, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'open library immediately hides private controls after sign-out',
    (tester) async {
      media.assets = [testAsset(id: 'mine', uploader: 'me')];
      await showTab(tester);
      await tester.pumpAndSettle();
      await open(tester, 'hub-send-to-partner');
      expect(find.byKey(const ValueKey(('hub-photo', 'mine'))), findsOneWidget);
      auth.change(null);
      await tester.pumpAndSettle();
      expect(find.byType(HubPhotoPicker), findsNothing);
      expect(find.text('Refresh private photos'), findsNothing);
      expect(find.textContaining('Pairing changed'), findsOneWidget);
      expect(repository.consents, isEmpty);
      expect(sends, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'My widget local action edits, confirms, and applies only locally',
    (tester) async {
      applied = 0;
      await showTab(tester);
      await tester.pumpAndSettle();
      await open(tester, 'hub-my-widget');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('hub-local-photo')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await awaitRoute(tester, WidgetEditorScreen);
      await tester.runAsync(() async {
        Navigator.of(
          tester.element(find.byType(WidgetEditorScreen)),
        ).pop(testPng);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('preview-confirm')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(applied, 1);
      expect(sends, isEmpty);
      expect(photos.requestIds, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('library partner download and apply remains explicit', (
    tester,
  ) async {
    var local = 0;
    media.dispose();
    media = MediaController(
      pairing: pairing,
      repository: photos,
      applyLocalPhoto: (_) async {
        local++;
      },
    );
    media.assets = [testAsset(id: 'received')];
    await showTab(tester);
    await tester.pumpAndSettle();
    await open(tester, 'hub-my-widget');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey(('hub-photo', 'received'))),
      150,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey(('hub-photo', 'received'))));
    await tester.pumpAndSettle();
    expect(media.photoFor('received'), isNotNull);
    expect(media.downloadedPhoto, isNull);
    expect(local, 0);
    await tester.scrollUntilVisible(
      find.text('Use on my widget'),
      150,
      scrollable: find.descendant(
        of: find.byType(BottomSheet).last,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Use on my widget'));
    await tester.pumpAndSettle();
    expect(local, 1);
    expect(sends, isEmpty);
    expect(photos.downloads.where((id) => id == 'received'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('My widget blank canvas does not pick or share a photo', (
    tester,
  ) async {
    applied = 0;
    await showTab(tester);
    await tester.pumpAndSettle();
    await open(tester, 'hub-my-widget');
    await tester.scrollUntilVisible(
      find.byKey(const Key('hub-blank-canvas')),
      150,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hub-blank-canvas')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<WidgetEditorScreen>(find.byType(WidgetEditorScreen))
          .background,
      isNull,
    );
    Navigator.of(tester.element(find.byType(WidgetEditorScreen))).pop();
    await tester.pumpAndSettle();
    expect(applied, 0);
    expect(sends, isEmpty);
    expect(photos.requestIds, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('hub and lazy sheets fit width $width and text scale 2', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      media.assets = [
        testAsset(id: 'mine', uploader: 'me'),
        testAsset(id: 'received'),
      ];
      await showTab(tester, scale: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final entry in {
        'hub-my-widget': 'My widget',
        'hub-partner-updates': 'Photos from your partner',
        'hub-send-to-partner': 'Send a photo',
      }.entries) {
        await open(tester, entry.key);
        expect(tester.takeException(), isNull);
        if (entry.key == 'hub-partner-updates') {
          expect(find.byType(PhotoSyncSettingsScreen), findsOneWidget);
          await tester.drag(find.byType(ListView).last, const Offset(0, -450));
          await tester.pumpAndSettle();
          await tester.pageBack();
          await tester.pumpAndSettle();
          continue;
        }
        final scrollable = find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first;
        for (var i = 0; i < 8; i++) {
          await tester.drag(scrollable, const Offset(0, -450));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byTooltip('Close ${entry.value}'));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(Key(entry.key))).height,
          greaterThanOrEqualTo(48),
        );
      }
      await open(tester, 'hub-schedule-photo');
      expect(find.byType(SchedulePhotoScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const Key('hub-default-photo-setting')), findsNothing);
      final scheduleScroll = find
          .descendant(
            of: find.byType(SchedulePhotoScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var i = 0; i < 5; i++) {
        await tester.drag(scheduleScroll, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      Navigator.of(tester.element(find.byType(SchedulePhotoScreen))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'sign-out removes consent and send controls without private calls',
    (tester) async {
      await showTab(tester);
      await tester.pumpAndSettle();
      auth.change(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('allow-partner-updates')), findsNothing);
      expect(find.text('Choose photo'), findsNothing);
      expect(find.text('Send to partner'), findsNothing);
      expect(repository.consents, isEmpty);
      expect(photos.requestIds, isEmpty);
      expect(sends, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
