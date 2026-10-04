import 'package:flutter/material.dart';
import '../../pairing/presentation/pairing_controller.dart';

/// The nested navigator is discarded on identity change, including open editors.
/// Email UI is injected so fake-auth tests never initialize platform plugins.
class AuthGate extends StatelessWidget {
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([pairing, pairing.session]),
    builder: (context, _) {
      if (!pairing.initialized) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pairing.busy) const CircularProgressIndicator(),
                if (pairing.error != null)
                  Text('Connection failed: ${pairing.error}'),
                if (!pairing.busy)
                  TextButton(
                    onPressed: pairing.initialize,
                    child: const Text('Retry connection'),
                  ),
              ],
            ),
          ),
        );
      }
      if (pairing.userId == null) {
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                emailBuilder(context),
                if (pairing.error != null)
                  Text('Sign-in failed: ${pairing.error}'),
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
