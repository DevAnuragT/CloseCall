import 'dart:async';
import 'package:closecall_client/closecall_client.dart';
import 'package:closecall/features/auth/presentation/account_controller.dart';
import 'package:closecall/features/auth/presentation/auth_gate.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/live_fakes.dart';

void main() {
  late FakeAuth auth;
  late PairingController pairing;
  late AccountController account;
  setUp(() {
    auth = FakeAuth();
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
}
