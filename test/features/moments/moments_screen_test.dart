import 'dart:async';

import 'package:closecall_client/closecall_client.dart' as api;
import 'package:closecall/app/moments_screen.dart';
import 'package:closecall/core/theme/app_theme.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/moments/presentation/moments_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import 'moments_fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeCouples couples;
  late PairingController pairing;
  late FakeMoments repository;
  late FakeMomentAudio audio;
  late MomentsController moments;
  setUp(() async {
    auth = FakeAuth()..change('me');
    couples = FakeCouples();
    pairing = PairingController(session: auth, repository: couples);
    await pairing.initialize();
    repository = FakeMoments();
    audio = FakeMomentAudio();
    moments = MomentsController(
      pairing: pairing,
      repository: repository,
      audio: audio,
    );
  });
  tearDown(() async {
    moments.dispose();
    pairing.dispose();
    auth.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 800),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: MomentsScreen(liveMode: true, controller: moments),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'loading, empty and feed refresh state are visible without an inline retry',
    (tester) async {
      repository.pendingList = Completer<List<api.MomentEntry>>();
      final refresh = moments.refresh();
      await mount(tester);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      repository.pendingList!.completeError(StateError('sensitive detail'));
      await refresh;
      await tester.pump();
      expect(find.textContaining('Couldn’t load'), findsOneWidget);
      expect(find.textContaining('sensitive detail'), findsNothing);
      expect(find.text('Retry loading moments'), findsNothing);
      repository.pendingList = null;
      await tester.drag(
        find.byKey(const Key('moments-feed')),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Retry loading moments'), findsNothing);
    },
  );

  testWidgets(
    'composer publishes through explicit retry and scope loss erases text',
    (tester) async {
      await moments.refresh();
      await mount(tester);
      await tester.tap(find.text('Add a moment'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('moment-text')));
      await tester.enterText(
        find.byKey(const Key('moment-text')),
        'Keep this hello',
      );
      repository.createFailure = StateError('lost response');
      await tester.ensureVisible(find.text('Publish moment'));
      await tester.tap(find.text('Publish moment'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Couldn’t confirm'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('moment-text'))).readOnly,
        isTrue,
      );
      expect(repository.requestIds, hasLength(1));
      repository.createFailure = null;
      await tester.ensureVisible(find.text('Retry publication'));
      await tester.tap(find.text('Retry publication'));
      await tester.pumpAndSettle();
      expect(find.text('Keep this hello'), findsOneWidget);
      expect(repository.requestIds.toSet(), hasLength(1));
      await tester.ensureVisible(find.text('Add a moment'));
      await tester.tap(find.text('Add a moment'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('moment-text')));
      await tester.enterText(
        find.byKey(const Key('moment-text')),
        'Unsaved secret',
      );
      auth.change(null);
      await tester.pump();
      expect(find.byKey(const Key('moment-text')), findsNothing);
      expect(find.text('Unsaved secret'), findsNothing);
      expect(find.text('Connect with your partner'), findsOneWidget);
    },
  );

  testWidgets(
    'voice card requires tap and shows loading and explicit playback retry',
    (tester) async {
      final entry = testMoment(kind: 'voice', author: 'partner');
      repository.entries = [entry];
      couples.couple = couples.couple!.copyWith(partnerNickname: 'Sunshine');
      await pairing.refresh();
      await moments.refresh();
      await mount(tester);
      await tester.ensureVisible(find.text('Play voice · 1s'));
      expect(repository.downloads, isEmpty);
      expect(find.text('Sunshine'), findsOneWidget);
      repository.pendingDownload = Completer();
      await tester.tap(find.text('Play voice · 1s'));
      await tester.pump();
      expect(find.text('Cancel voice loading'), findsOneWidget);
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      expect(repository.downloads, [entry.momentId]);
      await tester.runAsync(() async {
        repository.pendingDownload!.completeError(StateError('offline'));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Couldn’t play this voice moment'),
        findsOneWidget,
      );
      repository.pendingDownload = null;
      await tester.ensureVisible(find.text('Play voice · 1s'));
      await tester.tap(find.text('Play voice · 1s'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.text('Stop voice'), findsOneWidget);
      expect(audio.played, hasLength(1));
    },
  );

  testWidgets(
    'initial feed retries transient failures without a retry button',
    (tester) async {
      repository.listFailures = 2;
      moments.start();
      await mount(tester);
      await tester.pumpAndSettle();

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1000)),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
      expect(repository.listCalls, greaterThanOrEqualTo(2));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Retry'), findsNothing);
    },
  );

  testWidgets(
    '320px screen and 2x text keep composer, cards and actions usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      repository.entries = [
        testMoment(
          author: 'partner',
          kind: 'voice',
          text: 'A warm thought on a small screen.',
        ),
      ];
      couples.couple = Couple(
        id: 'couple',
        memberIds: ['me', 'partner'],
        partnerNickname: 'A very long affectionate partner nickname',
      );
      await pairing.refresh();
      await moments.refresh();
      moments.openComposer();
      await mount(tester, scale: 2);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Record voice'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('moments-feed')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      audio.recordFailure = StateError('permission denied');
      await tester.tap(find.text('Record voice'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Microphone unavailable'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Cancel moment'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('moments-feed')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel moment'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Play voice · 1s'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('moments-feed')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(audio.played, isEmpty);
    },
  );

  testWidgets('delete confirmation cannot send after a partner scope change', (
    tester,
  ) async {
    repository.entries = [testMoment()];
    await moments.refresh();
    await mount(tester);
    await tester.ensureVisible(find.text('Delete moment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete moment'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this moment?'), findsOneWidget);
    couples.couple = Couple(id: 'couple', memberIds: ['me', 'new-partner']);
    await pairing.refresh();
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deletions, isEmpty);
  });

  test('relative timestamps describe recent moments', () {
    final now = DateTime.utc(2026, 10, 11, 12);
    expect(relativeMomentTime(now, now: now), 'Just now');
    expect(
      relativeMomentTime(now.subtract(const Duration(minutes: 3)), now: now),
      '3m ago',
    );
    expect(
      relativeMomentTime(now.subtract(const Duration(days: 1)), now: now),
      'Yesterday',
    );
  });
}
