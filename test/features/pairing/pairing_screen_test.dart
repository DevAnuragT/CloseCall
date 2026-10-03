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

class FakeRepository implements CoupleRepository, PairingCodeReader {
  Couple? current;
  Object? failure;
  Completer<Couple?>? pending;
  String? joinedCode;
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
    await controller.initialize();
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
    await controller.refresh();
    expect(controller.couple?.isComplete, isTrue);
    session.setIdentity(null);
    await tester.pumpAndSettle();
    expect(find.text('Continue as development guest'), findsOneWidget);
    expect(find.text('ABC123'), findsNothing);
    expect(controller.couple, isNull);
  });

  testWidgets('configured failure stays visible and Retry reconnects', (
    tester,
  ) async {
    session.initializationError = StateError('offline');
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PairingScreen(controller: controller)),
      ),
    );
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Continue as development guest'), findsNothing);
    session.initializationError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Continue as development guest'), findsOneWidget);
  });

  testWidgets('loading disables mutations and typed errors are actionable', (
    tester,
  ) async {
    session.setIdentity('me');
    repository.pending = Completer<Couple?>();
    final initializing = controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PairingScreen(controller: controller)),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    repository.pending!.complete(null);
    await initializing;
    await tester.pumpAndSettle();
    repository.failure = const PairingException(PairingError.codeNotFound);
    await tester.enterText(find.byType(TextField), 'BAD123');
    await tester.tap(find.text('Join by code'));
    await tester.pumpAndSettle();
    expect(find.text('That invite code was not found.'), findsOneWidget);
  });

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
    expect(find.textContaining('not connected yet'), findsOneWidget);
  });
}
