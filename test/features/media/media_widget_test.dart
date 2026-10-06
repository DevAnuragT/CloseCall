import 'package:closecall_client/closecall_client.dart';
import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/widget/presentation/widget_tab_screen.dart';
import 'package:closecall/features/widget/presentation/editor/widget_editor_screen.dart';
import 'package:closecall/features/widget/presentation/widget_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/live_fakes.dart';

Future<void> waitForRoute(WidgetTester tester, Type type) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pumpAndSettle();
    if (find.byType(type).evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  expect(find.byType(type), findsOneWidget);
}

void main() {
  testWidgets('uncertain upload shows safe recovery copy and explicit retry', (
    tester,
  ) async {
    final auth = FakeAuth()..change('me');
    final pairing = PairingController(session: auth, repository: FakeCouples());
    await pairing.initialize();
    final repository = FakeMedia()
      ..uploadFailure = const ServerpodClientNetworkException(
        'Request timed out: https://private.invalid?Authorization=hidden',
      );
    final media = MediaController(
      pairing: pairing,
      repository: repository,
      prepare: (bytes) async => bytes,
    );
    addTearDown(() {
      media.dispose();
      pairing.dispose();
      auth.dispose();
    });
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WidgetTabScreen(media: media, liveMode: true)),
      ),
    );
    await media.uploadConfirmed(testPng);
    await tester.pumpAndSettle();
    expect(media.error, isA<ServerpodClientNetworkException>());
    expect(find.textContaining('may have succeeded'), findsOneWidget);
    expect(find.textContaining('Retry the same upload'), findsOneWidget);
    expect(find.textContaining('private.invalid'), findsNothing);
    expect(find.textContaining('Authorization'), findsNothing);
    expect(repository.requestIds, hasLength(1));
    repository.uploadFailure = null;
    await tester.ensureVisible(find.text('Retry photo operation'));
    await tester.tap(find.text('Retry photo operation'));
    await tester.pumpAndSettle();
    expect(repository.requestIds, hasLength(2));
    expect(repository.requestIds.toSet(), hasLength(1));
    expect(media.hasPendingUpload, isFalse);
  });

  testWidgets(
    'picker cancellation keeps demo editor local and does not navigate',
    (tester) async {
      var picks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetTabScreen(
              pickPhoto: () async {
                picks++;
                return null;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Decorate a photo — local widget only'));
      await tester.pumpAndSettle();
      expect(picks, 1);
      expect(find.byType(WidgetEditorScreen), findsNothing);
      expect(
        find.text('Demo mode: local-only editing. Nothing is uploaded.'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  for (final action in ['send', 'save', 'cancel']) {
    testWidgets(
      'picked photo reaches editor and preview explicitly confirms $action',
      (tester) async {
        final auth = FakeAuth()..change('me');
        final pairing = PairingController(
          session: auth,
          repository: FakeCouples(),
        );
        await pairing.initialize();
        final repository = FakeMedia();
        var localApplied = 0;
        final sends = <(String, String)>[];
        final media = MediaController(
          pairing: pairing,
          repository: repository,
          prepare: (bytes) async => bytes,
          applyLocalPhoto: (_) async {
            localApplied++;
          },
          sendAsset: (asset, request) async {
            sends.add((asset, request));
            return WidgetSendReceipt(
              sendId: 'send',
              requestId: request,
              coupleId: 'couple',
              senderId: 'me',
              recipientId: 'partner',
              assetId: asset,
              version: 1,
              createdAt: DateTime.utc(2026, 10, 5),
              recipientAutoUpdateEnabled: true,
            );
          },
        );
        addTearDown(() {
          media.dispose();
          pairing.dispose();
          auth.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WidgetTabScreen(
                media: media,
                liveMode: true,
                pickPhoto: () async => testPng,
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('hub-send-to-partner')));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        await waitForRoute(tester, WidgetEditorScreen);
        expect(
          tester
              .widget<WidgetEditorScreen>(find.byType(WidgetEditorScreen))
              .background,
          isA<Image>(),
        );
        expect(repository.requestIds, isEmpty);
        // Inject the editor result; its draw/text/sticker behavior has separate tests.
        await tester.runAsync(() async {
          Navigator.of(
            tester.element(find.byType(WidgetEditorScreen)),
          ).pop(testPng);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        await waitForRoute(tester, WidgetPreviewScreen);
        expect(find.text('Send to partner'), findsOneWidget);
        expect(find.text('Save privately'), findsOneWidget);
        expect(repository.requestIds, isEmpty);
        expect(sends, isEmpty);
        await tester.runAsync(() async {
          await tester.tap(
            find.byKey(
              Key(switch (action) {
                'send' => 'preview-confirm',
                'save' => 'preview-save-privately',
                _ => 'preview-cancel',
              }),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(repository.requestIds, hasLength(action == 'cancel' ? 0 : 1));
        expect(sends, hasLength(action == 'send' ? 1 : 0));
        if (action == 'send') expect(sends.single.$1, 'uploaded');
        expect(localApplied, 0);
      },
    );
  }

  testWidgets(
    'list/download/typed upload failure/retry/local apply need no plugins',
    (tester) async {
      final auth = FakeAuth()..change('me');
      final pairing = PairingController(
        session: auth,
        repository: FakeCouples(),
      );
      await pairing.initialize();
      final repository = FakeMedia();
      var applied = 0;
      final media = MediaController(
        pairing: pairing,
        repository: repository,
        prepare: (bytes) async => bytes,
        applyLocalPhoto: (_) async {
          applied++;
        },
      );
      addTearDown(() {
        media.dispose();
        pairing.dispose();
        auth.dispose();
      });
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WidgetTabScreen(media: media, liveMode: true)),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('hub-my-photos')));
      await tester.tap(find.byKey(const Key('hub-my-photos')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Refresh private photos'));
      await tester.tap(find.text('Refresh private photos'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(applied, 0);
      await tester.ensureVisible(
        find.text('Apply downloaded photo to this device'),
      );
      await tester.tap(find.text('Apply downloaded photo to this device'));
      await tester.pumpAndSettle();
      expect(applied, 1);
      repository.uploadFailure = MediaFailure(code: 'quota_exceeded');
      await media.uploadConfirmed(testPng);
      await tester.pumpAndSettle();
      expect(
        find.text('Your private photo storage quota has been reached.'),
        findsWidgets,
      );
      repository.uploadFailure = null;
      final sheetRetry = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Retry photo operation'),
      );
      await tester.ensureVisible(sheetRetry);
      await tester.tap(sheetRetry);
      await tester.pumpAndSettle();
      expect(repository.requestIds.toSet(), hasLength(1));
      expect(find.textContaining('Uploaded privately'), findsWidgets);
      auth.change(null);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Partner’s private photo'), findsNothing);
    },
  );
}
