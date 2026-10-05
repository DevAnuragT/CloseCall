import 'dart:async';

import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/widget/data/local_widget_writer.dart';
import 'package:closecall/features/widget/data/schedule_repository.dart';
import 'package:closecall/features/widget/presentation/schedule_controller.dart';
import 'package:closecall/features/widget/presentation/widget_tab_screen.dart';
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
  Object? sendFailure;

  setUp(() async {
    auth = FakeAuth()..change('me');
    pairing = PairingController(session: auth, repository: FakeCouples());
    await pairing.initialize();
    repository = _ConsentSchedules();
    photos = FakeMedia();
    sends.clear();
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

  Future<void> showTab(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WidgetTabScreen(
          liveMode: true,
          media: media,
          schedules: schedules,
        ),
      ),
    ),
  );

  testWidgets(
    'top consent card explicitly allows, pauses and resumes via API',
    (tester) async {
      await showTab(tester);
      await tester.pumpAndSettle();
      final allow = find.byKey(const Key('allow-partner-updates'));
      expect(allow, findsOneWidget);
      expect(tester.getTopLeft(allow).dy, lessThan(600));
      expect(find.byType(Switch), findsNothing);
      expect(repository.consents, isEmpty);
      expect(
        find.textContaining(
          'receiving new photos with the app closed is not available yet.',
        ),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        await tester.tap(allow);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(repository.consents, [true]);
      expect(schedules.partnerUpdatesEnabled, isTrue);
      expect(find.byType(Switch), findsOneWidget); // No second schedule toggle.
      await tester.runAsync(() async {
        await tester.tap(find.byType(Switch));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(repository.consents, [true, false]);
      expect(schedules.partnerUpdatesEnabled, isFalse);
      expect(find.textContaining('Paused — resume'), findsOneWidget);
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
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('allow-partner-updates')));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('allow-partner-updates')),
    );
    expect(button.onPressed, isNull);
    expect(repository.consents, [true]);
    await tester.runAsync(() async {
      repository.pendingConsent!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('partner-updates-error')), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.textContaining('private.invalid'), findsNothing);
    expect(schedules.partnerUpdatesEnabled, isFalse);
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
    await tester.scrollUntilVisible(find.text('Send to partner'), 300);
    expect(find.text('Send to partner'), findsOneWidget);
    expect(find.text('Partner’s private photo'), findsOneWidget);
    await tester.tap(find.text('Send to partner'));
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
      final choose = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Choose photo'),
      );
      expect(choose.onPressed, isNull);
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
      expect(photos.requestIds, isEmpty);
      expect(media.hasPendingSend, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
