import 'dart:async';
import 'dart:typed_data';

import 'package:closecall/core/theme/app_theme.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/widget/data/local_widget_writer.dart';
import 'package:closecall/features/widget/presentation/editor/widget_editor_screen.dart';
import 'package:closecall/features/widget/presentation/schedule_controller.dart';
import 'package:closecall/features/widget/presentation/schedule_panel.dart';
import 'package:closecall/features/widget/presentation/unpaired_widget_screen.dart';
import 'package:closecall/features/widget/presentation/widget_preview_screen.dart';
import 'package:closecall/features/widget/presentation/widget_tab_screen.dart';
import 'package:closecall_client/closecall_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import '../../support/schedule_fakes.dart';

class _Couples extends FakeCouples {
  _Couples() {
    couple = null;
  }
  Object? failure;
  Completer<Couple?>? pending;
  @override
  Future<Couple?> coupleForUser(String id) async {
    if (failure != null) throw failure!;
    return pending == null ? couple : pending!.future;
  }
}

class _Media extends FakeMedia {
  int lists = 0;
  @override
  Future<List<MediaAsset>> listAssets() {
    lists++;
    return super.listAssets();
  }
}

class _Schedules extends FakeSchedules {
  int reads = 0;
  @override
  Future<WidgetTimeline> currentTimeline() {
    reads++;
    return super.currentTimeline();
  }

  @override
  Future<WidgetTimeline> partnerTimeline() {
    reads++;
    return super.partnerTimeline();
  }
}

class _Fixture {
  final auth = FakeAuth()..change('me');
  final couples = _Couples();
  final repository = _Media();
  late final pairing = PairingController(session: auth, repository: couples);
  late final media = MediaController(pairing: pairing, repository: repository);
  void dispose() {
    media.dispose();
    pairing.dispose();
    auth.dispose();
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Fixture f, {
  Future<Uint8List?> Function()? pick,
  Future<void> Function(Uint8List)? apply,
  ScheduleController? schedules,
  double scale = 1,
  double navigationInset = 0,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      bottomNavigationBar: navigationInset == 0
          ? null
          : SizedBox(height: navigationInset),
      body: WidgetTabScreen(
        media: f.media,
        liveMode: true,
        pickPhoto: pick,
        applyLocalPhoto: apply,
        schedules: schedules,
        onConnectPartner: () {},
      ),
    ),
  ),
);

void _noPrivate(_Fixture f) {
  expect(f.repository.lists, 0);
  expect(f.repository.downloads, isEmpty);
  expect(f.repository.requestIds, isEmpty);
  for (final text in [
    'Share privately',
    'Private library',
    'Upload another private photo',
    'Refresh private photos',
    'Photos from your couple',
    'Auto-sync',
    'Send a photo',
    'Photos from your partner',
    'Send later',
    'Saved photos',
    'Default photo',
  ]) {
    expect(find.text(text), findsNothing);
  }
}

Future<void> _returnEditorPhoto(WidgetTester tester) async {
  // The editor's PNG export/drawing is tested separately. Return its result
  // through the real route, then exercise the real preview confirmation.
  await tester.runAsync(() async {
    Navigator.of(tester.element(find.byType(WidgetEditorScreen))).pop(testPng);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
  // Image validation/PNG work runs outside the fake frame clock. Wait for the
  // route, not an assumed 100 ms wall-clock duration under suite load.
  for (
    var i = 0;
    i < 50 && find.byType(WidgetPreviewScreen).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.descendant(
      of: find.byKey(const Key('unpaired-widget-list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final state in ['unpaired', 'unknown', 'error']) {
    testWidgets(
      '$state hides even stale private results and makes no schedule RPCs',
      (tester) async {
        final f = _Fixture();
        addTearDown(f.dispose);
        if (state == 'error') f.couples.failure = StateError('offline');
        if (state != 'unknown') {
          await tester.runAsync(f.pairing.initialize);
        }
        // Deliberately seed old private results: the UI must not render them.
        f.media.assets = [testAsset(couple: 'old-couple')];
        f.media.downloadedPhoto = testPng;
        f.media.selectedAsset = testAsset(couple: 'old-couple');
        final repository = _Schedules();
        final writer = LocalWidgetWriter(
          timeline: FakeNativeTimeline([]),
          applyPhoto: (_) async {},
          clearPhoto: () async {},
        );
        final schedules = ScheduleController(
          pairing: f.pairing,
          repository: repository,
          mediaRepository: f.repository,
          localWriter: writer,
        );
        addTearDown(() async {
          schedules.dispose();
          await repository.dispose();
        });
        await _pump(tester, f, schedules: schedules);
        await tester.pump();
        expect(find.byType(Image), findsNothing);
        expect(find.byType(SchedulePanel), findsNothing);
        expect(repository.reads, 0);
        expect(repository.watches, 0);
        expect(repository.creates, isEmpty);
        expect(repository.fallbacks, isEmpty);
        expect(repository.cancellations, isEmpty);
        _noPrivate(f);
      },
    );
  }

  testWidgets(
    'unknown and loading do not claim unpaired or call private RPCs',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await _pump(tester, f);
      expect(
        find.text('Your partner space will appear here when it is ready.'),
        findsOneWidget,
      );
      expect(find.byType(UnpairedWidgetScreen), findsNothing);
      expect(find.text('Connect partner'), findsNothing);
      _noPrivate(f);
      f.couples.pending = Completer<Couple?>();
      final load = f.pairing.initialize();
      await tester.pump();
      _noPrivate(f);
      f.couples.pending!.complete(null);
      await load;
      await tester.pumpAndSettle();
      expect(find.text('Choose a photo'), findsOneWidget);
      _noPrivate(f);
    },
  );

  testWidgets(
    'pairing read error has no inline retry and no fabricated local/private state',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      f.couples.failure = StateError('secret diagnostic');
      await tester.runAsync(f.pairing.initialize);
      await _pump(tester, f);
      expect(
        find.text('We couldn’t check your partner connection.'),
        findsOneWidget,
      );
      expect(find.textContaining('secret'), findsNothing);
      expect(find.text('Choose a photo'), findsNothing);
      _noPrivate(f);
      f.couples.failure = null;
      expect(find.byKey(const Key('widget-pairing-retry')), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('Better together'), findsOneWidget);
      _noPrivate(f);
    },
  );

  testWidgets('unpaired picker cancellation is safe, help starts collapsed', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.pairing.initialize();
    var picks = 0;
    await _pump(
      tester,
      f,
      pick: () async {
        picks++;
        return null;
      },
    );
    expect(find.text('Preview · illustration'), findsOneWidget);
    expect(find.textContaining('1. Touch and hold'), findsNothing);
    await tester.tap(find.byKey(const Key('choose-local-photo')));
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(find.byType(WidgetEditorScreen), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    _noPrivate(f);
    await _scrollTo(tester, find.byType(ExpansionTile));
    await tester.tap(find.text('How to add the widget'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('2. Tap Widgets and find CloseCall.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('does not add the widget automatically'),
      findsOneWidget,
    );
  });

  testWidgets(
    'photo editor and preview require explicit local-only confirmation',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.pairing.initialize();
      final applied = <Uint8List>[];
      await _pump(
        tester,
        f,
        pick: () async => testPng,
        apply: (photo) async {
          applied.add(photo);
        },
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('choose-local-photo')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WidgetEditorScreen>(find.byType(WidgetEditorScreen))
            .background,
        isA<Image>(),
      );
      await _returnEditorPhoto(tester);
      expect(find.byType(WidgetPreviewScreen), findsOneWidget);
      expect(find.text('Set on my widget'), findsOneWidget);
      expect(applied, isEmpty);
      _noPrivate(f);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('preview-confirm')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(applied, hasLength(1));
      expect(find.text('Preview · your photo'), findsOneWidget);
      expect(find.byKey(const Key('local-photo-saved')), findsOneWidget);
      _noPrivate(f);
      // An identity switch clears even a local-only State-owned preview.
      f.auth.change('someone-else');
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Preview · illustration'), findsOneWidget);
    },
  );

  testWidgets(
    'blank canvas uses editor without gallery, cancellation never saves',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.pairing.initialize();
      var picks = 0;
      var applies = 0;
      await _pump(
        tester,
        f,
        pick: () async {
          picks++;
          return testPng;
        },
        apply: (_) async {
          applies++;
        },
      );
      await tester.tap(find.byKey(const Key('blank-local-canvas')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WidgetEditorScreen>(find.byType(WidgetEditorScreen))
            .background,
        isNull,
      );
      Navigator.of(tester.element(find.byType(WidgetEditorScreen))).pop();
      await tester.pumpAndSettle();
      expect(picks, 0);
      expect(applies, 0);
      _noPrivate(f);
    },
  );

  testWidgets(
    'local save failure is retryable without another gallery or private call',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.pairing.initialize();
      var attempts = 0;
      await _pump(
        tester,
        f,
        apply: (_) async {
          attempts++;
          if (attempts == 1) throw StateError('native save failed');
        },
      );
      await tester.tap(find.byKey(const Key('blank-local-canvas')));
      await tester.pumpAndSettle();
      await _returnEditorPhoto(tester);
      await tester.tap(find.byKey(const Key('preview-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('local-photo-error')), findsOneWidget);
      await _scrollTo(tester, find.text('Retry save'));
      await tester.tap(find.text('Retry save'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byKey(const Key('local-photo-error')), findsNothing);
      _noPrivate(f);
    },
  );

  testWidgets(
    'pairing changes reactively show pending, paired, then hide stale private photos',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.pairing.initialize();
      await _pump(tester, f);
      f.couples.couple = Couple(id: 'pending-raw-id', memberIds: ['me']);
      await f.pairing.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Waiting for your partner'), findsOneWidget);
      expect(find.text('View invite'), findsOneWidget);
      expect(find.textContaining('pending-raw-id'), findsNothing);
      _noPrivate(f);
      f.couples.couple = Couple(id: 'couple', memberIds: ['me', 'partner']);
      await f.pairing.refresh();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hub-send-to-partner')), findsOneWidget);
      expect(f.repository.lists, 1);
      expect(f.repository.downloads, ['asset']);
      f.couples.couple = null;
      await f.pairing.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Photos from your couple'), findsNothing);
      expect(find.text('Choose a photo'), findsOneWidget);
    },
  );

  testWidgets(
    'late gallery result after account change cannot open editor or save',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.pairing.initialize();
      final picked = Completer<Uint8List?>();
      var applied = 0;
      await _pump(
        tester,
        f,
        pick: () => picked.future,
        apply: (_) async {
          applied++;
        },
      );
      await tester.tap(find.byKey(const Key('choose-local-photo')));
      await tester.pump();
      f.auth.change('new-user');
      await tester.pumpAndSettle();
      picked.complete(testPng);
      await tester.pumpAndSettle();
      expect(find.byType(WidgetEditorScreen), findsNothing);
      expect(applied, 0);
      _noPrivate(f);
    },
  );

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'unpaired width $width scale $scale has no overflow and 48px actions',
        (tester) async {
          final f = _Fixture();
          addTearDown(f.dispose);
          await f.pairing.initialize();
          tester.view.physicalSize = Size(width, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          await _pump(tester, f, scale: scale, navigationInset: 80);
          final primary = tester.getRect(
            find.byKey(const Key('choose-local-photo')),
          );
          expect(primary.height, greaterThanOrEqualTo(48));
          expect(primary.bottom, lessThan(700));
          await _scrollTo(tester, find.byKey(const Key('blank-local-canvas')));
          final blank = tester.getRect(
            find.byKey(const Key('blank-local-canvas')),
          );
          expect(blank.height, greaterThanOrEqualTo(48));
          await _scrollTo(
            tester,
            find.byKey(const Key('widget-connect-partner')),
          );
          expect(
            tester
                .getSize(find.byKey(const Key('widget-connect-partner')))
                .height,
            greaterThanOrEqualTo(48),
          );
          await _scrollTo(tester, find.byType(ExpansionTile));
          await tester.tap(find.text('How to add the widget'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
