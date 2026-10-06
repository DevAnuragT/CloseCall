import 'package:closecall/features/widget/presentation/schedule_panel.dart';
import 'package:closecall/features/widget/presentation/schedule_photo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

Future<void> showPanel(
  WidgetTester tester,
  ScheduleHarness h, {
  bool screen = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          alwaysUse24HourFormat: true,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: screen
          ? SchedulePhotoScreen(controller: h.controller, media: h.media)
          : Scaffold(
              body: SingleChildScrollView(
                child: SchedulePanel(controller: h.controller, media: h.media),
              ),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> closePanel(WidgetTester tester, ScheduleHarness h) async {
  await tester.pumpWidget(const SizedBox());
  await h.dispose();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> selectTime(
  WidgetTester tester,
  String field,
  DateTime local, {
  bool cancelTime = false,
}) async {
  await tapVisible(tester, find.byKey(Key(field)));
  expect(find.byType(DatePickerDialog), findsOneWidget);
  final initial = tester
      .widget<DatePickerDialog>(find.byType(DatePickerDialog))
      .initialDate!;
  final months = (local.year - initial.year) * 12 + local.month - initial.month;
  for (var i = 0; i < months; i++) {
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('${local.day}').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  expect(find.byType(TimePickerDialog), findsOneWidget);
  if (cancelTime) {
    await tester.tap(find.text('Cancel'));
  } else {
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '${local.hour}');
    await tester.enterText(fields.at(1), '${local.minute}');
    await tester.tap(find.text('OK'));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'photo choices show private pixels, never raw identifiers or technical settings',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [
        testAsset(id: 'my-private-uuid', uploader: 'me'),
        testAsset(id: 'partner-private-uuid'),
      ];
      h.controller.status = 'TECHNICAL SHARED GLOBAL STATUS';
      await showPanel(tester, h);
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image)).image;
      final source = image is ResizeImage ? image.imageProvider : image;
      expect((source as MemoryImage).bytes, testPng);
      expect(
        find.byKey(const Key('photo-choice-partner-private-uuid')),
        findsNothing,
      );
      for (final raw in [
        'my-private-uuid',
        'partner-private-uuid',
        'Recipient',
        'Server-adjusted now',
        'UTC',
        'ISO',
        'TECHNICAL SHARED GLOBAL STATUS',
        'Default photo',
        'Auto-sync',
      ]) {
        expect(find.textContaining(raw), findsNothing);
      }
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Switch), findsNothing);
      await tapVisible(
        tester,
        find.byKey(const Key('photo-choice-my-private-uuid')),
      );
      expect(find.byKey(const Key('schedule-summary')), findsOneWidget);
      await tapVisible(tester, find.text('Schedule photo'));
      final request = h.repository.creates.single;
      expect(request.$1, 'my-private-uuid');
      expect(request.$2, scheduleEpoch.add(const Duration(minutes: 5)));
      expect(request.$3, scheduleEpoch.add(const Duration(minutes: 65)));
      expect(request.$2.isUtc && request.$3.isUtc, isTrue);
      expect(find.text('Photo scheduled for your partner.'), findsOneWidget);
      await closePanel(tester, h);
    },
  );

  testWidgets('paused receiving consent does not disable sending form', (
    tester,
  ) async {
    final h = ScheduleHarness();
    await h.initialize();
    h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
    expect(h.controller.partnerUpdatesEnabled, isFalse);
    await showPanel(tester, h);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('schedule-start')))
          .onPressed,
      isNotNull,
    );
    await tapVisible(tester, find.byKey(const Key('photo-choice-mine')));
    await tapVisible(tester, find.text('Schedule photo'));
    expect(h.repository.creates, hasLength(1));
    expect(h.controller.partnerUpdatesEnabled, isFalse);
    expect(find.byType(Switch), findsNothing);
    await closePanel(tester, h);
  });

  testWidgets('unpaired shows pairing guidance instead of editable form', (
    tester,
  ) async {
    final h = ScheduleHarness();
    await h.initialize(signedIn: false);
    await showPanel(tester, h);
    expect(
      find.text('Complete pairing before scheduling a photo.'),
      findsOneWidget,
    );
    expect(find.text('Schedule photo'), findsNothing);
    expect(find.byType(Image), findsNothing);
    await closePanel(tester, h);
  });

  testWidgets(
    'both date and time must confirm; cancelling either leaves the window unchanged',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
      await showPanel(tester, h);
      final original = tester
          .widget<OutlinedButton>(find.byKey(const Key('schedule-start')))
          .child!
          .toStringDeep();
      await tapVisible(tester, find.byKey(const Key('schedule-start')));
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateUtils.dateOnly(scheduleEpoch.toLocal()));
      expect(
        picker.lastDate,
        DateUtils.dateOnly(
          scheduleEpoch.add(const Duration(days: 30)).toLocal(),
        ),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('schedule-start')))
            .child!
            .toStringDeep(),
        original,
      );
      await selectTime(
        tester,
        'schedule-start',
        scheduleEpoch.add(const Duration(days: 1)).toLocal(),
        cancelTime: true,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('schedule-start')))
            .child!
            .toStringDeep(),
        original,
      );
      await tapVisible(tester, find.byKey(const Key('photo-choice-mine')));
      await tapVisible(tester, find.text('Schedule photo'));
      expect(
        h.repository.creates.single.$2,
        scheduleEpoch.add(const Duration(minutes: 5)),
      );
      await closePanel(tester, h);
    },
  );

  testWidgets(
    'confirmed local pickers send UTC and move end to stay after a later start',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
      await showPanel(tester, h);
      final start = scheduleEpoch
          .add(const Duration(days: 1, minutes: 30))
          .toLocal();
      await selectTime(tester, 'schedule-start', start);
      await tapVisible(tester, find.byKey(const Key('photo-choice-mine')));
      await tapVisible(tester, find.text('Schedule photo'));
      expect(h.repository.creates.single.$2, start.toUtc());
      expect(
        h.repository.creates.single.$3,
        start.add(const Duration(hours: 1)).toUtc(),
      );
      await closePanel(tester, h);
    },
  );

  testWidgets('end before start produces a friendly error without submitting', (
    tester,
  ) async {
    final h = ScheduleHarness();
    await h.initialize();
    h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
    await showPanel(tester, h);
    await selectTime(tester, 'schedule-end', scheduleEpoch.toLocal());
    expect(find.text('Choose an end after the start.'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('photo-choice-mine')));
    await tapVisible(tester, find.text('Schedule photo'));
    expect(find.text('Choose an end after the start.'), findsOneWidget);
    expect(h.repository.creates, isEmpty);
    await closePanel(tester, h);
  });

  testWidgets(
    'future and seven-day interval bounds are enforced before submitting',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
      await showPanel(tester, h);
      await selectTime(
        tester,
        'schedule-start',
        scheduleEpoch.subtract(const Duration(minutes: 1)).toLocal(),
      );
      expect(find.text('Choose a start in the future.'), findsOneWidget);
      await selectTime(
        tester,
        'schedule-start',
        scheduleEpoch.add(const Duration(minutes: 5)).toLocal(),
      );
      await selectTime(
        tester,
        'schedule-end',
        scheduleEpoch.add(const Duration(days: 7, minutes: 6)).toLocal(),
      );
      expect(
        find.text('A photo can be scheduled for up to seven days.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.byKey(const Key('photo-choice-mine')));
      await tapVisible(tester, find.text('Schedule photo'));
      expect(h.repository.creates, isEmpty);
      await closePanel(tester, h);
    },
  );

  testWidgets(
    'the last start date still checks its time against the 30-day limit',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
      await showPanel(tester, h);
      await selectTime(
        tester,
        'schedule-start',
        scheduleEpoch.add(const Duration(days: 30, minutes: 1)).toLocal(),
      );
      expect(
        find.text('Choose a start within the next 30 days.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.byKey(const Key('photo-choice-mine')));
      await tapVisible(tester, find.text('Schedule photo'));
      expect(h.repository.creates, isEmpty);
      await closePanel(tester, h);
    },
  );

  testWidgets(
    'pending retry is explicit, read-only, and preserves the exact request',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
      h.repository.createFailure = StateError('offline');
      await h.controller.createPartnerSchedule(
        'mine',
        scheduleEpoch.add(const Duration(minutes: 5)),
        scheduleEpoch.add(const Duration(minutes: 10)),
      );
      await showPanel(tester, h);
      expect(find.byKey(const Key('schedule-error')), findsOneWidget);
      expect(
        find.textContaining('Retry keeps the same photo and times.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('schedule-start')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(find.byKey(const Key('photo-choice-mine')))
            .onTap,
        isNull,
      );
      expect(h.repository.creates, hasLength(1));
      h.repository.createFailure = null;
      await tapVisible(tester, find.text('Retry pending schedule'));
      expect(h.repository.creates, hasLength(2));
      expect(h.repository.creates[0], h.repository.creates[1]);
      expect(h.requestIds, 1);
      await closePanel(tester, h);
    },
  );

  testWidgets(
    'discarding uncertainty never automatically schedules a replacement',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
      h.repository.createFailure = StateError('offline');
      await h.controller.createPartnerSchedule(
        'mine',
        scheduleEpoch.add(const Duration(minutes: 5)),
        scheduleEpoch.add(const Duration(minutes: 10)),
      );
      await showPanel(tester, h);
      await tapVisible(tester, find.text('Discard pending schedule'));
      expect(h.controller.pendingCreate, isNull);
      expect(h.repository.creates, hasLength(1));
      expect(
        find.textContaining('The schedule may still have been saved.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('schedule-start')))
            .onPressed,
        isNotNull,
      );
      await closePanel(tester, h);
    },
  );

  testWidgets(
    'upcoming cards have private thumbnails, recipient labels and cancellation',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [
        testAsset(id: 'own-window-photo'),
        testAsset(id: 'sent-window-photo', uploader: 'me'),
      ];
      h.repository.own = scheduleTimeline(
        schedules: [scheduleEntry(id: 'own-window', asset: 'own-window-photo')],
      );
      h.repository.partner = scheduleTimeline(
        recipient: 'partner',
        schedules: [
          scheduleEntry(
            id: 'sent-window',
            asset: 'sent-window-photo',
            recipient: 'partner',
          ),
        ],
      );
      await h.controller.refresh();
      await showPanel(tester, h);
      await tapVisible(tester, find.text('Upcoming photos'));
      expect(find.text('For you'), findsOneWidget);
      expect(find.text('For your partner'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(3));
      expect(find.textContaining('own-window-photo'), findsNothing);
      expect(find.textContaining('partner-only'), findsNothing);
      await tapVisible(
        tester,
        find.byKey(const Key('cancel-schedule-sent-window')),
      );
      expect(h.repository.cancellations, ['sent-window']);
      expect(find.text('Schedule cancelled.'), findsOneWidget);
      await closePanel(tester, h);
    },
  );

  testWidgets(
    'account change during picker cannot apply stale choice to the new pairing',
    (tester) async {
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
      await showPanel(tester, h, screen: true);
      expect(find.text('Send later'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('schedule-start')));
      h.auth.change(null);
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(
        find.text('Pairing changed. Close this screen and try again.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text('Schedule photo'), findsNothing);
      expect(h.repository.creates, isEmpty);
      await closePanel(tester, h);
    },
  );

  testWidgets(
    '320-wide screen with double-sized text stays scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = ScheduleHarness();
      await h.initialize();
      h.media.assets = [testAsset(id: 'mine', uploader: 'me')];
      await showPanel(tester, h, screen: true, scale: 2);
      await tapVisible(tester, find.byKey(const Key('photo-choice-mine')));
      await tester.ensureVisible(find.text('Schedule photo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      await closePanel(tester, h);
    },
  );
}
