import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/presentation/account_controller.dart';
import '../../couple/data/couple_repository.dart';
import '../../couple/domain/couple.dart';
import 'pairing_controller.dart';

/// Profile and the live pairing controls. Server identifiers intentionally do
/// not appear here; this is a people-facing surface, not a debug console.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key, required this.controller, this.account});

  final PairingController controller;
  final AccountController? account;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final listenable = account == null
        ? widget.controller
        : Listenable.merge([widget.controller, account]);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final c = widget.controller;
        final couple = c.couple;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              const _ProfileHeader(),
              const SizedBox(height: AppSpacing.md),
              _AccountCard(account: account),
              const SizedBox(height: AppSpacing.md),
              _ConnectionCard(controller: c),
              if (c.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorCard(
                  message: _errorMessage(c.error!),
                  onRetry: c.busy ? null : c.retry,
                ),
              ],
              if (!c.initialized && !c.busy && c.error == null) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: c.initialize,
                  icon: const Icon(Icons.wifi_rounded),
                  label: const Text('Connect to server'),
                ),
              ],
              if (c.initialized && c.userId == null && c.allowDevGuest) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: c.busy ? null : c.signIn,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue as development guest'),
                ),
              ],
              if (c.initialized && c.userId != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _PairingSection(
                  controller: c,
                  couple: couple,
                  codeController: _code,
                ),
                const SizedBox(height: AppSpacing.lg),
                _SignOutSection(
                  busy: c.busy,
                  onPressed: () => _confirmSignOut(context),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    if (widget.account?.guestOrUnknown == false) {
      await widget.controller.signOut();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.account != null && widget.account!.account == null
              ? 'Sign out with unknown account status?'
              : 'Lose guest account access?',
        ),
        content: const Text(
          'A device-only guest account cannot be recovered after sign-out. '
          'Guest data will not be linked to a new email account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await widget.controller.signOut();
  }

  String _errorMessage(Object error) {
    if (error is PairingException) {
      return switch (error.error) {
        PairingError.invalidCode => 'Enter a valid invite code.',
        PairingError.codeNotFound => 'That invite code was not found.',
        PairingError.alreadyPaired =>
          'You are already paired. Refresh your pairing to see the latest state.',
        PairingError.cannotPairWithSelf => 'You cannot join your own invite.',
      };
    }
    return 'We could not reach the pairing service. Please try again. ($error)';
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Your private space for two.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 16),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.cream,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.favorite_rounded, color: AppColors.clay),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final AccountController? account;

  @override
  Widget build(BuildContext context) {
    final state = account?.account;
    final isGuest = account == null || state?.isGuest == true;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow('ACCOUNT'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const _LeadingIcon(icon: Icons.person_outline_rounded),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGuest ? 'Device-only guest' : 'Email account',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (isGuest)
                      const Text(
                        'Development guest account — device-only access.',
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          height: 1.35,
                        ),
                      )
                    else
                      Text(
                        'Email account: ${state?.email ?? 'Email registered'}',
                        style: const TextStyle(color: AppColors.inkMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (isGuest && account != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Signing out, deleting the app, or losing this device can permanently lose access. There is no guest recovery yet.',
              style: TextStyle(
                color: AppColors.inkMuted,
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ],
          if (account?.account == null &&
              account != null &&
              !account!.busy) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Account status is unknown. Refresh before signing out.',
              style: TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          ],
          if (account?.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Account status unavailable: ${account!.error}',
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
          if (account != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: account!.busy ? null : account!.refresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh account status'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.controller});

  final PairingController controller;

  @override
  Widget build(BuildContext context) {
    final couple = controller.couple;
    final complete = couple?.isComplete == true;
    return _SurfaceCard(
      color: complete
          ? AppColors.blush.withValues(alpha: 0.15)
          : AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionEyebrow('YOUR CONNECTION')),
              _StatusPill(
                label: complete ? 'Connected' : 'Not paired',
                color: complete ? AppColors.success : AppColors.clay,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            !controller.hasLoadedPairing
                ? 'Checking your pairing…'
                : complete
                ? 'Paired with your partner'
                : couple == null
                ? 'Not paired yet'
                : 'Waiting for your partner',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            complete
                ? 'Your shared space is ready for the little things.'
                : 'Invite your person or join their private space below.',
            style: const TextStyle(color: AppColors.inkMuted, height: 1.35),
          ),
          if (controller.busy) ...[
            const SizedBox(height: AppSpacing.lg),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ],
      ),
    );
  }
}

class _PairingSection extends StatelessWidget {
  const _PairingSection({
    required this.controller,
    required this.couple,
    required this.codeController,
  });

  final PairingController controller;
  final Couple? couple;
  final TextEditingController codeController;

  @override
  Widget build(BuildContext context) {
    final hasInvite = controller.inviteCode != null;
    final isComplete = couple?.isComplete == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasInvite) ...[
          _InviteCard(code: controller.inviteCode!),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (controller.hasLoadedPairing && couple == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: controller.busy ? null : controller.createInvite,
              icon: const Icon(Icons.mail_outline_rounded),
              label: const Text('Create invite'),
            ),
          ),
        if (controller.hasLoadedPairing && !isComplete) ...[
          if (couple == null) const SizedBox(height: AppSpacing.md),
          TextField(
            controller: codeController,
            enabled: !controller.busy,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Partner invite code',
              hintText: 'e.g. ABC123',
              prefixIcon: Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: controller.busy
                  ? null
                  : () => controller.join(codeController.text),
              icon: const Icon(Icons.link_rounded),
              label: const Text('Join by code'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: controller.busy ? null : controller.refresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh pairing'),
        ),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      color: AppColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow('YOUR PRIVATE INVITE'),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Share this invite code privately:',
            style: TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            code,
            key: const Key('invite-code'),
            style: const TextStyle(
              color: AppColors.plum,
              fontSize: 30,
              letterSpacing: 4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pairing-error'),
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(height: 1.35)),
                const SizedBox(height: AppSpacing.xs),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutSection extends StatelessWidget {
  const _SignOutSection({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: busy ? null : onPressed,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Sign out of this device'),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: child,
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.inkMuted,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.plum),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
