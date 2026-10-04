import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
                            onPressed: pairing.initialize,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry connection'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () async {
                            await pairing.session.signOut();
                            if (context.mounted) await pairing.initialize();
                          },
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
