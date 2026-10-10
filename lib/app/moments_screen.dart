import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// A calm landing place for shared memories while the moments backend is
/// being connected. The live state deliberately stays empty rather than
/// presenting sample content as if it belonged to a couple.
class MomentsScreen extends StatelessWidget {
  const MomentsScreen({super.key, this.liveMode = false});

  final bool liveMode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      label: 'Shared moments page',
                      child: ExcludeSemantics(
                        child: Text(
                          'Moments',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Small things worth keeping close.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _RoundIcon(
                icon: Icons.add_rounded,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      liveMode
                          ? 'Shared moments are coming soon.'
                          : 'Moments are preview-only in demo mode.',
                    ),
                  ),
                ),
                tooltip: 'Add a moment',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _IntroCard(liveMode: liveMode),
          const SizedBox(height: AppSpacing.lg),
          if (liveMode) ...[
            const _ComingSoonCard(),
          ] else ...[
            const _DemoMoment(
              icon: Icons.wb_sunny_rounded,
              title: 'A little hello',
              subtitle: 'A place for the ordinary moments that feel special.',
              color: AppColors.cream,
            ),
            const SizedBox(height: AppSpacing.md),
            const _DemoMoment(
              icon: Icons.favorite_rounded,
              title: 'Made for two',
              subtitle: 'Private by default, just like your conversations.',
              color: Color(0xFFF8E5E5),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.liveMode});

  final bool liveMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.plum,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.blush.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  liveMode
                      ? 'A shared space, just for you two'
                      : 'Moments made for two',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  liveMode
                      ? 'Private memories will gather here as you make them.'
                      : 'A quiet preview of your private shared scrapbook.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.cream),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.clay),
          SizedBox(height: AppSpacing.md),
          Text(
            'Your first moment is waiting',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Shared moments are being connected. Your private space will appear here when it is ready.',
            style: TextStyle(color: AppColors.inkMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DemoMoment extends StatelessWidget {
  const _DemoMoment({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.plum),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.plum,
      ),
    );
  }
}
