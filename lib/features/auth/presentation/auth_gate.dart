import 'package:flutter/material.dart';
import '../data/auth_session.dart';
import '../../pairing/presentation/pairing_controller.dart';

/// The nested navigator is discarded on identity change, including open editors.
/// Email UI is injected so fake-auth tests never initialize platform plugins.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.pairing,
    required this.emailBuilder,
    required this.signedInBuilder,
  });
  final PairingController pairing;
  final WidgetBuilder emailBuilder;
  final WidgetBuilder signedInBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  PairingController get pairing => widget.pairing;
  WidgetBuilder get emailBuilder => widget.emailBuilder;
  WidgetBuilder get signedInBuilder => widget.signedInBuilder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([pairing, pairing.session]),
    builder: (context, _) {
      // Keep the private shell visible while an already signed-in session is
      // being validated. Individual features stay inert until pairing loads,
      // so startup never needs to block the whole app behind a connection
      // screen. The sign-in surface remains the only gate for signed-out
      // users.
      // Render the shell while the SDK restores cached auth and validates it.
      // The auth widget itself has a prominent "Connecting" state; exposing
      // it during every cold start makes a valid local session feel signed
      // out. If restoration proves there is no session, the next rebuild
      // replaces this shell with the sign-in surface.
      if (pairing.userId != null && !pairing.initialized) {
        return signedInBuilder(context);
      }
      if (pairing.userId == null) {
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                emailBuilder(context),
                if (pairing.initialized && pairing.error != null)
                  Text(
                    pairing.error is LocalSignOutException
                        ? 'Signed out of this device. Server revocation could '
                              'not be confirmed; sign in again when online.'
                        : 'Sign-in needs attention. Please try again when online.',
                  ),
                if (pairing.allowDevGuest)
                  TextButton(
                    onPressed: pairing.busy ? null : pairing.signIn,
                    child: const Text('Continue as development guest'),
                  ),
              ],
            ),
          ),
        );
      }
      return Navigator(
        key: ValueKey('${pairing.userId}:${pairing.authRevision}'),
        onGenerateRoute: (_) => MaterialPageRoute(builder: signedInBuilder),
      );
    },
  );
}
