import 'package:closecall/features/widget/presentation/schedule_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

Future<void> showPanel(WidgetTester tester, ScheduleHarness h) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SchedulePanel(controller: h.controller, media: h.media),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'Android opt-in warns closed-app delay, reconnect and 24h TTL; manual pauses it',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      await showPanel(tester, h);
      expect(
        find.text('Auto-sync + cached Android transitions'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Cached Android transitions may run while app closed; OS can delay.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'New, changed or cancelled schedules require reconnect; cache expires after 24h.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Local-only photo choices pause it.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();
      expect(h.controller.autoSyncEnabled, isTrue);
      expect(h.native.payloads, hasLength(1));
      await h.controller.applyManualPhoto(testPng);
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.pumpWidget(const SizedBox());
      await h.dispose();
    },
  );

  testWidgets(
    'iOS has foreground-only text, no promise of closed-app transitions',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize(android: false);
      await showPanel(tester, h);
      expect(find.text('Foreground auto-sync on this device'), findsOneWidget);
      expect(
        find.textContaining(
          'Background cache is unavailable on this platform; keep the app open.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Cached Android transitions may run'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      await h.dispose();
    },
  );

  testWidgets('unpaired switch disabled and explicit pairing guidance shown', (
    tester,
  ) async {
    final h = ScheduleHarness();
    await h.initialize(signedIn: false);
    await showPanel(tester, h);
    expect(
      find.text('Complete pairing before loading timelines.'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    await tester.pumpWidget(const SizedBox());
    await h.dispose();
  });

  testWidgets('schedule form rejects timestamps without explicit UTC offset', (
    tester,
  ) async {
    final h = ScheduleHarness();
    await h.initialize();
    h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
    await showPanel(tester, h);
    await tester.ensureVisible(find.byKey(const Key('schedule-asset')));
    await tester.tap(find.byKey(const Key('schedule-asset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('mine').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('schedule-start')),
      '2026-10-03T12:05:00',
    );
    await tester.ensureVisible(find.text('Schedule for partner'));
    await tester.tap(find.text('Schedule for partner'));
    await tester.pump();
    expect(
      find.text('Include an explicit time zone: Z or ±hh:mm.'),
      findsOneWidget,
    );
    expect(h.repository.creates, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await h.dispose();
  });

  testWidgets(
    'failed request exposes retry with same photo, UTC window and request ID',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.repository.createFailure = StateError('offline');
      await h.controller.createPartnerSchedule(
        'mine',
        scheduleEpoch.add(const Duration(minutes: 5)),
        scheduleEpoch.add(const Duration(minutes: 10)),
      );
      await showPanel(tester, h);
      expect(find.byKey(const Key('schedule-error')), findsOneWidget);
      expect(
        find.textContaining('Retry preserves this exact photo and UTC window.'),
        findsOneWidget,
      );
      h.repository.createFailure = null;
      await tester.ensureVisible(find.text('Retry pending schedule'));
      await tester.tap(find.text('Retry pending schedule'));
      await tester.pump();
      await tester.pump();
      expect(h.repository.creates, hasLength(2));
      expect(h.repository.creates[0], h.repository.creates[1]);
      await tester.pumpWidget(const SizedBox());
      await h.dispose();
    },
  );
}
