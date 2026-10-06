import 'package:closecall/features/widget/presentation/default_photo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

void main() {
  testWidgets(
    'default picker includes couple photos as actual images and saves only my default',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [
        testAsset(id: 'own-uuid', uploader: 'me'),
        testAsset(id: 'partner-uuid'),
        testAsset(id: 'other-uuid', couple: 'other'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DefaultPhotoPicker(
                controller: h.controller,
                media: h.media,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Default photo'), findsOneWidget);
      expect(
        find.textContaining('no scheduled photo or latest photo received'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNWidgets(2));
      for (final id in [
        'own-uuid',
        'partner-uuid',
        'other-uuid',
        'partner-only',
      ]) {
        expect(find.textContaining(id), findsNothing);
      }
      expect(find.byKey(const Key('photo-choice-other-uuid')), findsNothing);
      await tester.tap(find.byKey(const Key('photo-choice-partner-uuid')));
      await tester.pump();
      await tester.ensureVisible(find.text('Save default photo'));
      await tester.tap(find.text('Save default photo'));
      await tester.pumpAndSettle();
      expect(h.repository.fallbacks, ['partner-uuid']);
      expect(h.controller.partnerTimeline?.fallbackAssetId, 'partner-only');
      expect(find.text('Default photo saved.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await h.dispose();
    },
  );

  testWidgets(
    'default picker hides private pictures and stale save after account changes',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DefaultPhotoPicker(
                controller: h.controller,
                media: h.media,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('photo-choice-mine')));
      await tester.pump();
      h.auth.change(null);
      await tester.pumpAndSettle();
      expect(
        find.text('Pairing changed. Close this screen and try again.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text('Save default photo'), findsNothing);
      expect(h.repository.fallbacks, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await h.dispose();
    },
  );
}
