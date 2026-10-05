import 'dart:async';
import 'package:closecall_client/closecall_client.dart';
import 'package:closecall/features/auth/presentation/account_controller.dart';
import 'package:closecall/features/auth/data/session_restoration.dart';
import 'package:closecall/features/auth/presentation/auth_gate.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/live_fakes.dart';

class _RecoveringAuth extends FakeAuth {
  Object? initializationFailure;
  Object? signOutFailure;
  bool clearBeforeFailure = true;
  Completer<void>? pendingSignOut;

  @override
  Future<void> initialize() async {
    if (initializationFailure != null) throw initializationFailure!;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    if (pendingSignOut != null) await pendingSignOut!.future;
    if (signOutFailure == null || clearBeforeFailure) change(null);
    if (signOutFailure != null) throw signOutFailure!;
  }
}

void main() {
  late _RecoveringAuth auth;
  late PairingController pairing;
  late AccountController account;
  setUp(() {
    auth = _RecoveringAuth();
    pairing = PairingController(session: auth, repository: FakeCouples());
    account = AccountController(auth);
  });
  tearDown(() {
    account.dispose();
    pairing.dispose();
    auth.dispose();
  });

  testWidgets(
    'email gate follows auth state with dev guest disabled and removes private routes',
    (tester) async {
      await pairing.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            pairing: pairing,
            emailBuilder: (_) =>
                const Text('Injected email login / register / reset'),
            signedInBuilder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const Scaffold(body: Text('private editor')),
                  ),
                ),
                child: const Text('signed-in shell'),
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Injected email login / register / reset'),
        findsOneWidget,
      );
      expect(find.text('Continue as development guest'), findsNothing);
      auth.change('me');
      await tester.pumpAndSettle();
      await tester.tap(find.text('signed-in shell'));
      await tester.pumpAndSettle();
      expect(find.text('private editor'), findsOneWidget);
      auth.change(null);
      await tester.pumpAndSettle();
      expect(find.text('private editor'), findsNothing);
      expect(
        find.text('Injected email login / register / reset'),
        findsOneWidget,
      );
    },
  );

  test(
    'account result after identity changes cannot change current account',
    () async {
      auth.pendingAccount = Completer<AccountState?>();
      auth.change('old');
      auth.change(null);
      auth.pendingAccount!.complete(
        AccountState(userId: 'old', isGuest: false, email: 'old@example.test'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(account.account, isNull);
      expect(account.error, isNull);
      expect(account.busy, isFalse);
    },
  );

  test('development guest sign-in is explicitly disabled by default', () async {
    await pairing.initialize();
    await pairing.signIn();
    expect(auth.userId, isNull);
    expect(pairing.error.toString(), contains('disabled'));
  });

  testWidgets(
    'email account has no guest warning or destructive guest confirmation',
    (tester) async {
      auth.account = AccountState(
        userId: 'me',
        isGuest: false,
        email: 'me@example.test',
      );
      auth.change('me');
      await pairing.initialize();
      await account.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PairingScreen(controller: pairing, account: account),
          ),
        ),
      );
      expect(find.textContaining('Development guest account'), findsNothing);
      expect(find.text('Email account: me@example.test'), findsOneWidget);
      await tester.ensureVisible(find.text('Sign out of this device'));
      await tester.tap(find.text('Sign out of this device'));
      await tester.pumpAndSettle();
      expect(auth.signOuts, 1);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('unknown account retains conservative sign-out warning', (
    tester,
  ) async {
    auth.change('me');
    await pairing.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PairingScreen(controller: pairing, account: account),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Sign out of this device'));
    await tester.tap(find.text('Sign out of this device'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(auth.signOuts, 0);
  });

  Future<void> showPausedGate(WidgetTester tester) async {
    auth.initializationFailure = const SessionValidationException();
    await pairing.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          pairing: pairing,
          emailBuilder: (_) => const Text('email sign-in'),
          signedInBuilder: (_) => const Text('private space'),
        ),
      ),
    );
    expect(find.text('Connection paused'), findsOneWidget);
    expect(find.text('private space'), findsNothing);
  }

  testWidgets('offline identity is not allowed through the private auth gate', (
    tester,
  ) async {
    auth.change('me');
    await showPausedGate(tester);
    expect(auth.userId, 'me');
    expect(pairing.initialized, isFalse);
  });

  testWidgets(
    'email start-over confirms, disables in flight, and handles local-only sign-out',
    (tester) async {
      auth.account = AccountState(
        userId: 'me',
        isGuest: false,
        email: 'me@example.test',
      );
      auth.change('me');
      await showPausedGate(tester);
      await tester.tap(find.text('Start over with sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('same email'), findsOneWidget);
      expect(find.textContaining('cannot be recovered'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.signOuts, 0);

      auth.pendingSignOut = Completer<void>();
      auth.signOutFailure = const LocalSignOutException();
      await tester.tap(find.text('Start over with sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out and continue'));
      await tester.pump();
      expect(pairing.busy, isTrue);
      expect(find.text('Start over with sign in'), findsNothing);
      expect(find.text('Retry connection'), findsNothing);
      auth.pendingSignOut!.complete();
      await tester.pumpAndSettle();
      expect(auth.signOuts, 1);
      expect(find.text('email sign-in'), findsOneWidget);
      expect(find.text('Connection paused'), findsNothing);
      expect(
        find.textContaining('Server revocation could not be confirmed'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown/offline account start-over warns of guest access loss', (
    tester,
  ) async {
    auth.change('me');
    auth.accountFailure = StateError('Synthetic offline error');
    await showPausedGate(tester);
    await tester.tap(find.text('Start over with sign in'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('cannot be recovered after sign-out'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.userId, 'me');
    expect(auth.signOuts, 0);
  });

  testWidgets(
    'failed local clear returns to retryable paused state without an unhandled error',
    (tester) async {
      auth.change('me');
      auth.signOutFailure = const SessionValidationException();
      auth.clearBeforeFailure = false;
      await showPausedGate(tester);
      await tester.tap(find.text('Start over with sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out and continue'));
      await tester.pumpAndSettle();
      expect(find.text('Connection paused'), findsOneWidget);
      expect(auth.userId, 'me');
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Start over with sign in'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no cached identity does not prove a failed local reset succeeded',
    (tester) async {
      auth.signOutFailure = const SessionValidationException();
      auth.clearBeforeFailure = false;
      await showPausedGate(tester);
      await tester.tap(find.text('Start over with sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out and continue'));
      await tester.pumpAndSettle();
      expect(pairing.initialized, isFalse);
      expect(find.text('Connection paused'), findsOneWidget);
      expect(find.text('email sign-in'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale reset confirmation cannot sign out a switched account', (
    tester,
  ) async {
    auth.change('old');
    await showPausedGate(tester);
    await tester.tap(find.text('Start over with sign in'));
    await tester.pumpAndSettle();
    auth.change('new');
    await tester.pump();
    await tester.tap(find.text('Sign out and continue'));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);
    expect(auth.userId, 'new');
  });
}
