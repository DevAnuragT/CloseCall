import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
  bool _resetting = false;
  PairingController get pairing => widget.pairing;
  WidgetBuilder get emailBuilder => widget.emailBuilder;
  WidgetBuilder get signedInBuilder => widget.signedInBuilder;

  Future<void> _startOver() async {
    if (_resetting || pairing.busy) return;
    setState(() => _resetting = true);
    try {
      final id = pairing.userId;
      var knownEmail = false;
      if (id != null) {
        try {
          final account = await pairing.session.currentAccount();
          knownEmail = account?.userId == id && account?.isGuest == false;
        } catch (_) {
          // Unknown/offline account status needs the conservative warning.
        }
      }
      if (!mounted || pairing.userId != id) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start over with email sign-in?'),
          content: Text(
            knownEmail
                ? 'This signs out of this device, not your account. Sign in with '
                      'the same email to recover your space.'
                : 'Account status could not be confirmed. A device-only guest '
                      'account cannot be recovered after sign-out. Guest data '
                      'will not be linked to a new email account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out and continue'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted && pairing.userId == id) {
        await pairing.signOut();
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([pairing, pairing.session]),
    builder: (context, _) {
      if (!pairing.initialized) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.plum.withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.blush.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_off_rounded,
                          color: AppColors.clay,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        pairing.busy ? 'Connecting you' : 'Connection paused',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        pairing.busy
                            ? 'Checking your private CloseCall space…'
                            : 'We could not validate this session. Your account data is still safe; try again or start a fresh sign-in.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          height: 1.45,
                        ),
                      ),
                      if (pairing.error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Connection failed',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      if (pairing.busy)
                        const CircularProgressIndicator()
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _resetting ? null : pairing.initialize,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry connection'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _resetting ? null : _startOver,
                          child: const Text('Start over with sign in'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
