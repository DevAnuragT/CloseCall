import 'package:closecall_client/closecall_client.dart';
import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/widget/presentation/widget_tab_screen.dart';
import 'package:closecall/features/widget/presentation/editor/widget_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/live_fakes.dart';

void main() {
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

  testWidgets(
    'picked photo reaches editor and private upload waits for preview confirmation',
    (tester) async {
      final auth = FakeAuth()..change('me');
      final pairing = PairingController(
        session: auth,
        repository: FakeCouples(),
      );
      await pairing.initialize();
      final repository = FakeMedia();
      var localApplied = 0;
      final media = MediaController(
        pairing: pairing,
        repository: repository,
        prepare: (bytes) async => bytes,
        applyLocalPhoto: (_) async {
          localApplied++;
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
        await tester.tap(find.text('Decorate and upload private photo'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(WidgetEditorScreen), findsOneWidget);
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
      expect(find.text('Upload private photo'), findsOneWidget);
      expect(repository.requestIds, isEmpty);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('preview-confirm')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(repository.requestIds, hasLength(1));
      expect(localApplied, 0);
    },
  );

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
      await tester.tap(find.text('Refresh private photos'));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(applied, 0);
      await tester.tap(find.text('Apply downloaded photo to this device'));
      await tester.pumpAndSettle();
      expect(applied, 1);
      repository.uploadFailure = MediaFailure(code: 'quota_exceeded');
      await media.uploadConfirmed(testPng);
      await tester.pumpAndSettle();
      expect(
        find.text('Your private photo storage quota has been reached.'),
        findsOneWidget,
      );
      repository.uploadFailure = null;
      await tester.tap(find.text('Retry photo operation'));
      await tester.pumpAndSettle();
      expect(repository.requestIds.toSet(), hasLength(1));
      expect(find.textContaining('Uploaded privately'), findsOneWidget);
      auth.change(null);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Partner’s private photo'), findsNothing);
    },
  );
}
