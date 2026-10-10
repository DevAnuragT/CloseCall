import 'dart:async';

import 'package:closecall/features/couple/data/couple_repository.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/auth/data/auth_session.dart';
import 'package:closecall/features/mood/data/mood_repository.dart';
import 'package:closecall/features/mood/data/serverpod_mood_repository.dart';
import 'package:closecall/features/mood/domain/mood.dart';
import 'package:closecall/features/mood/presentation/mood_controller.dart';
import 'package:closecall/features/home/presentation/home_screen.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/core/theme/app_theme.dart';
import 'package:closecall_client/closecall_client.dart' as api;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Serverpod mood repository maps own and partner state', () async {
    final now = DateTime.utc(2026, 10, 7, 12);
    final repository = ServerpodMoodRepository.withCalls(
      userId: () => 'me',
      current: () async => api.MoodState(
        ownMood: 'happy',
        ownUpdatedAt: now,
        partnerUserId: 'partner',
        partnerMood: 'tired',
        partnerUpdatedAt: now.add(const Duration(minutes: 1)),
      ),
      set: (mood) async => api.MoodState(
        ownMood: mood,
        ownUpdatedAt: now,
        partnerUserId: 'partner',
      ),
    );

    final current = await repository.currentMood();
    expect(current.own?.mood, MoodKind.happy);
    expect(current.partner?.userId, 'partner');
    expect(current.partner?.mood, MoodKind.tired);
    expect(
      (await repository.setMood(MoodKind.excited)).own?.mood,
      MoodKind.excited,
    );
  });

  test(
    'Serverpod mood repository refuses calls without an authenticated user',
    () async {
      final repository = ServerpodMoodRepository.withCalls(
        userId: () => null,
        current: () async => throw StateError('must not call'),
        set: (_) async => throw StateError('must not call'),
      );
      await expectLater(repository.currentMood(), throwsStateError);
      await expectLater(repository.setMood(MoodKind.happy), throwsStateError);
    },
  );

  testWidgets('mood card shows partner context and sends one choice', (
    tester,
  ) async {
    final auth = _MoodAuth();
    final pairing = PairingController(
      session: auth,
      repository: _MoodCouples(),
    );
    await pairing.initialize();
    final mood = MoodController(
      pairing: pairing,
      repository: _MoodRepository(),
    );
    mood.start();
    await tester.pumpAndSettle();
    addTearDown(() {
      mood.dispose();
      pairing.dispose();
      auth.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: MoodCard(controller: mood)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Partner feels'), findsOneWidget);
    expect(find.text('Tired'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(MoodKind.values.length));

    await tester.tap(find.byKey(const ValueKey('mood-choice-excited')));
    await tester.pumpAndSettle();
    expect((mood.repository as _MoodRepository).lastMood, MoodKind.excited);
    expect((mood.repository as _MoodRepository).setCalls, 1);

    // A selected choice is feedback, not another submission target.
    await tester.tap(find.byKey(const ValueKey('mood-choice-excited')));
    await tester.pumpAndSettle();
    expect((mood.repository as _MoodRepository).setCalls, 1);
    expect(find.byTooltip('Excited is selected'), findsOneWidget);
  });

  testWidgets('mood card presents a loading state', (tester) async {
    final auth = _MoodAuth();
    final pairing = PairingController(
      session: auth,
      repository: _MoodCouples(),
    );
    await pairing.initialize();
    final repository = _DelayedMoodRepository();
    final mood = MoodController(pairing: pairing, repository: repository);
    mood.start();
    addTearDown(() {
      mood.dispose();
      pairing.dispose();
      auth.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: MoodCard(controller: mood)),
      ),
    );
    await tester.pump();

    expect(find.text('Checking in on your moods…'), findsOneWidget);

    repository.current.complete(const MoodSnapshot());
    await tester.pumpAndSettle();
    expect(find.text('How are you feeling?'), findsOneWidget);
    expect(
      find.textContaining('Your partner has not shared a mood yet'),
      findsOneWidget,
    );
  });

  testWidgets('mood card presents an error state with a retry action', (
    tester,
  ) async {
    final auth = _MoodAuth();
    final pairing = PairingController(
      session: auth,
      repository: _MoodCouples(),
    );
    await pairing.initialize();
    final mood = MoodController(
      pairing: pairing,
      repository: _FailingMoodRepository(),
    );
    mood.start();
    addTearDown(() {
      mood.dispose();
      pairing.dispose();
      auth.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: MoodCard(controller: mood)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Mood is unavailable offline'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('mood card remains usable at a narrow width', (tester) async {
    tester.view.physicalSize = const Size(240, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final auth = _MoodAuth();
    final pairing = PairingController(
      session: auth,
      repository: _MoodCouples(),
    );
    await pairing.initialize();
    final mood = MoodController(
      pairing: pairing,
      repository: _MoodRepository(
        at: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );
    mood.start();
    addTearDown(() {
      mood.dispose();
      pairing.dispose();
      auth.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: MoodCard(controller: mood)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tired'), findsOneWidget);
    expect(find.text('2h ago'), findsOneWidget);
    expect(find.byTooltip('Set your mood to Excited'), findsOneWidget);
  });

  testWidgets('paired home exposes pull to refresh and mood refresh action', (
    tester,
  ) async {
    final auth = _MoodAuth();
    final pairing = PairingController(
      session: auth,
      repository: _MoodCouples(),
    );
    await pairing.initialize();
    final mood = MoodController(
      pairing: pairing,
      repository: _MoodRepository(at: DateTime.now()),
    )..start();
    addTearDown(() {
      mood.dispose();
      pairing.dispose();
      auth.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeScreen(pairing: pairing, mood: mood),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byKey(const Key('mood-refresh')), findsOneWidget);
    expect(find.byTooltip('Refresh moods'), findsOneWidget);
  });
}

class _MoodAuth extends AuthSession {
  @override
  String? get userId => 'me';
  @override
  Future<void> initialize() async {}
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<void> signOut() async {}
}

class _MoodCouples implements CoupleRepository {
  @override
  Future<Couple?> coupleForUser(String userId) async =>
      Couple(id: 'couple', memberIds: ['me', 'partner']);
  @override
  Future<PairingResult> createCouple(String userId) async =>
      throw UnimplementedError();
  @override
  Future<Couple> joinByCode(String userId, String code) async =>
      (await coupleForUser(userId))!;
}

class _MoodRepository implements MoodRepository {
  _MoodRepository({DateTime? at}) : _at = at ?? DateTime.utc(2026, 10, 7);

  MoodKind? lastMood;
  int setCalls = 0;
  final DateTime _at;

  @override
  Future<MoodSnapshot> currentMood() async => MoodSnapshot(
    partner: MoodCheckIn(
      userId: 'partner',
      mood: MoodKind.tired,
      createdAt: _at,
    ),
  );

  @override
  Future<MoodSnapshot> setMood(MoodKind mood) async {
    setCalls++;
    lastMood = mood;
    return MoodSnapshot(
      own: MoodCheckIn(userId: 'me', mood: mood, createdAt: _at),
      partner: MoodCheckIn(
        userId: 'partner',
        mood: MoodKind.tired,
        createdAt: _at,
      ),
    );
  }
}

class _DelayedMoodRepository implements MoodRepository {
  final current = Completer<MoodSnapshot>();

  @override
  Future<MoodSnapshot> currentMood() => current.future;

  @override
  Future<MoodSnapshot> setMood(MoodKind mood) => Future<MoodSnapshot>.value(
    MoodSnapshot(
      own: MoodCheckIn(userId: 'me', mood: mood, createdAt: DateTime.now()),
    ),
  );
}

class _FailingMoodRepository implements MoodRepository {
  @override
  Future<MoodSnapshot> currentMood() async =>
      throw StateError('offline for test');

  @override
  Future<MoodSnapshot> setMood(MoodKind mood) async =>
      throw StateError('offline for test');
}
