import 'dart:async';

import 'package:closecall/app/app_shell.dart';
import 'package:closecall/features/auth/data/auth_session.dart';
import 'package:closecall/features/couple/data/couple_repository.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSession extends AuthSession {
  String? identity;
  Object? initializationError;
  int signIns = 0;
  @override
  String? get userId => identity;
  void setIdentity(String? value) {
    identity = value;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {
    if (initializationError != null) throw initializationError!;
  }

  @override
  Future<void> signInAnonymously() async {
    signIns++;
    setIdentity('me');
  }

  @override
  Future<void> signOut() async => setIdentity(null);
}

class FakeRepository
    implements CoupleRepository, PairingCodeReader, UnpairRepository {
  Couple? current;
  Object? failure;
  Completer<Couple?>? pending;
  String? joinedCode;
  int unpairCalls = 0;
  @override
  String? currentInviteCode;
  @override
  Future<Couple?> coupleForUser(String userId) async {
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return current;
  }

  @override
  Future<PairingResult> createCouple(String userId) async {
    current = Couple(id: 'couple', memberIds: [userId]);
    currentInviteCode = 'ABC123';
    return PairingResult(couple: current!, code: currentInviteCode!);
  }

  @override
  Future<Couple> joinByCode(String userId, String code) async {
    if (failure != null) throw failure!;
    joinedCode = code;
    currentInviteCode = null;
    return current = Couple(id: 'couple', memberIds: [userId, 'partner']);
  }

  @override
  Future<void> unpair(String userId, String coupleId) async {
    unpairCalls++;
    current = Couple(id: coupleId, memberIds: ['partner']);
    currentInviteCode = 'NEW123';
  }
}

void main() {
  late FakeSession session;
  late FakeRepository repository;
  late PairingController controller;
  setUp(() {
    session = FakeSession();
    repository = FakeRepository();
    controller = PairingController(
      session: session,
      repository: repository,
      allowDevGuest: true,
    );
  });
  tearDown(() {
    controller.dispose();
    session.dispose();
  });

  testWidgets('guest warning, invite, join, refresh and auth-driven reset', (
    tester,
  ) async {
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PairingScreen(controller: controller)),
      ),
    );
    expect(find.textContaining('device-only access'), findsOneWidget);
    await tester.tap(find.text('Continue as development guest'));
    await tester.pumpAndSettle();
    expect(find.text('Not paired yet'), findsOneWidget);
    await tester.tap(find.text('Create invite'));
    await tester.pumpAndSettle();
    expect(find.text('ABC123'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'OTHER1');
    await tester.ensureVisible(find.text('Join by code'));
    await tester.tap(find.text('Join by code'));
    await tester.pumpAndSettle();
    expect(repository.joinedCode, 'OTHER1');
    expect(find.text('Paired with your partner'), findsOneWidget);
    await tester.runAsync(controller.initialize);
    expect(controller.couple?.isComplete, isTrue);
    session.setIdentity(null);
    await tester.pumpAndSettle();
    expect(find.text('Continue as development guest'), findsOneWidget);
    expect(find.text('ABC123'), findsNothing);
    expect(controller.couple, isNull);
  });

  testWidgets('profile exposes confirmed unpair and keeps sign-in', (
    tester,
  ) async {
    session.setIdentity('me');
    repository.current = Couple(id: 'couple', memberIds: ['me', 'partner']);
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PairingScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unpair from partner'), findsOneWidget);
    await tester.tap(find.text('Unpair from partner'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This device will lose access to the shared space, Moments, photos '
        'and widget updates. Shared history remains available to your '
        'partner, and they can invite someone new.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Unpair').last);
    await tester.pumpAndSettle();
    expect(repository.unpairCalls, 1);
    expect(session.userId, 'me');
  });

  testWidgets('configured failure stays visible and pull refresh reconnects', (
    tester,
  ) async {
    session.initializationError = StateError('offline');
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PairingScreen(controller: controller)),
      ),
    );
    expect(find.textContaining('could not sync your pairing'), findsOneWidget);
    expect(find.text('Continue as development guest'), findsNothing);
    session.initializationError = null;
    expect(find.text('Retry'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Continue as development guest'), findsOneWidget);
  });

  testWidgets(
    'background pairing refresh keeps the surface calm and errors actionable',
    (tester) async {
      session.setIdentity('me');
      repository.pending = Completer<Couple?>();
      final initializing = controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PairingScreen(controller: controller)),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      repository.pending!.complete(null);
      await initializing;
      await tester.pumpAndSettle();
      repository.failure = const PairingException(PairingError.codeNotFound);
      await tester.enterText(find.byType(TextField), 'BAD123');
      await tester.tap(find.text('Join by code'));
      await tester.pumpAndSettle();
      expect(find.text('That invite code was not found.'), findsOneWidget);
    },
  );

  test(
    'late response after sign-out cannot restore another auth state',
    () async {
      session.setIdentity('me');
      repository.pending = Completer<Couple?>();
      final initializing = controller.initialize();
      await Future<void>.delayed(Duration.zero);
      session.setIdentity(null);
      repository.pending!.complete(
        Couple(id: 'old', memberIds: ['me', 'partner']),
      );
      await initializing;
      expect(controller.couple, isNull);
      expect(controller.inviteCode, isNull);
    },
  );

  test(
    'read failure after guest sign-in retries without a new guest',
    () async {
      await controller.initialize();
      repository.failure = StateError('offline');
      await controller.signIn();
      expect(session.signIns, 1);
      expect(controller.error, isNotNull);
      repository.failure = null;
      await controller.retry();
      expect(session.signIns, 1);
      expect(controller.error, isNull);
    },
  );

  testWidgets('live shell never presents mock mood/reminder as live data', (
    tester,
  ) async {
    session.setIdentity('me');
    repository.current = Couple(id: 'couple', memberIds: ['me', 'partner']);
    await controller.initialize();
    await tester.pumpWidget(MaterialApp(home: AppShell(pairing: controller)));
    expect(find.text('Paired'), findsOneWidget);
    expect(find.text('Call tonight'), findsNothing);
    expect(find.text('morning_surprise.jpg'), findsNothing);
    expect(find.textContaining('Reconnect your shared space'), findsOneWidget);
  });
}
