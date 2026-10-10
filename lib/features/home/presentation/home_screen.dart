import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../mood/domain/mood.dart';
import '../../mood/presentation/mood_controller.dart';
import '../../pairing/presentation/pairing_controller.dart';
import '../../reminders/domain/reminder.dart';
import '../../widget/domain/widget_schedule_resolver.dart';
import '../domain/dashboard_snapshot.dart';

/// The emotional first screen. Demo snapshots remain available for previews,
/// while live mode only renders state that came from the pairing controller.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.snapshot,
    this.pairing,
    this.mood,
    this.onOpenPairing,
  }) : assert(snapshot != null || pairing != null);

  final DashboardSnapshot? snapshot;
  final PairingController? pairing;
  final MoodController? mood;
  final VoidCallback? onOpenPairing;

  @override
  Widget build(BuildContext context) {
    final livePairing = pairing;
    if (livePairing != null) {
      return ListenableBuilder(
        listenable: livePairing,
        builder: (context, _) => _LiveHome(
          controller: livePairing,
          mood: mood,
          onOpenPairing: onOpenPairing,
        ),
      );
    }
    return _DemoHome(snapshot: snapshot!);
  }
}

class _DemoHome extends StatelessWidget {
  const _DemoHome({required this.snapshot});

  final DashboardSnapshot snapshot;

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
          const _DemoBanner(),
          const SizedBox(height: AppSpacing.xl),
          _Header(
            eyebrow: 'Thinking of',
            title: snapshot.partnerNickname,
            icon: Icons.favorite_rounded,
          ),
          const SizedBox(height: AppSpacing.xl),
          _PartnerMoodCard(mood: snapshot.partnerMood),
          const SizedBox(height: AppSpacing.lg),
          _WidgetPreviewCard(widget: snapshot.widget),
          const SizedBox(height: AppSpacing.lg),
          _ReminderCard(reminder: snapshot.nextReminder),
          const SizedBox(height: AppSpacing.xl),
          const _QuickActions(),
        ],
      ),
    );
  }
}

class _LiveHome extends StatelessWidget {
  const _LiveHome({required this.controller, this.mood, this.onOpenPairing});

  final PairingController controller;
  final MoodController? mood;
  final VoidCallback? onOpenPairing;

  @override
  Widget build(BuildContext context) {
    final couple = controller.couple;
    final paired = couple?.isComplete == true;
    final waiting = !controller.hasLoadedPairing || couple == null || !paired;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.blush,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          await controller.refresh();
          if (mood != null) await mood!.refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _Header(
              eyebrow: paired ? 'Your little corner' : 'Welcome to CloseCall',
              title: paired
                  ? 'Close, even from far away'
                  : 'Make it yours together',
              icon: paired
                  ? Icons.favorite_rounded
                  : Icons.auto_awesome_rounded,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (controller.busy) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: AppSpacing.md),
            ],
            if (controller.error != null) ...[
              _LiveNotice(
                title: 'We could not refresh your space',
                message:
                    'Your existing pairing is safe. Open Profile to try again.',
                icon: Icons.cloud_off_rounded,
                color: AppColors.error,
                onPressed: controller.busy ? null : controller.retry,
                actionLabel: 'Try again',
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (waiting)
              _PairingWelcomeCard(
                hasLoadedPairing: controller.hasLoadedPairing,
                onOpenPairing: onOpenPairing,
              )
            else ...[
              _PairedHero(nickname: couple.partnerNickname),
              const SizedBox(height: AppSpacing.lg),
              const _LiveFeatureCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Shared moments',
                message:
                    'Your private scrapbook is coming together. Moments are not connected yet.',
              ),
              const SizedBox(height: AppSpacing.md),
              if (mood != null) MoodCard(controller: mood!),
              if (mood == null)
                const _LiveFeatureCard(
                  icon: Icons.mood_rounded,
                  title: 'Mood check-in',
                  message: 'Mood is unavailable until your space reconnects.',
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const _PrivacyNote(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.eyebrow,
    required this.title,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final IconData icon;

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
                eyebrow,
                style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, color: AppColors.clay),
        ),
      ],
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined, size: 16, color: AppColors.plum),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              'Demo mode · sample data, not connected',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.plum,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PairingWelcomeCard extends StatelessWidget {
  const _PairingWelcomeCard({
    required this.hasLoadedPairing,
    this.onOpenPairing,
  });

  final bool hasLoadedPairing;
  final VoidCallback? onOpenPairing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.blush.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.blush.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.blush,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            hasLoadedPairing ? 'Start with an invite' : 'Connecting your space',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasLoadedPairing
                ? 'Create an invite for your person, or join theirs with a private code.'
                : 'We are checking your pairing status. Your private space will be ready soon.',
            style: const TextStyle(color: AppColors.inkMuted, height: 1.4),
          ),
          if (onOpenPairing != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onOpenPairing,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Open pairing'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PairedHero extends StatelessWidget {
  const _PairedHero({this.nickname});

  final String? nickname;

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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.blush.withValues(alpha: 0.24),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paired',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  nickname == null || nickname!.trim().isEmpty
                      ? 'Your partner is connected.'
                      : '${nickname!.trim()} is connected.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
        ],
      ),
    );
  }
}

class _LiveFeatureCard extends StatelessWidget {
  const _LiveFeatureCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
          Icon(icon, color: AppColors.clay),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
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

/// Live mood entry point. It stays on Home so setting a mood is one tap away,
/// while the paired partner's latest state is visible in the same card.
class MoodCard extends StatelessWidget {
  const MoodCard({required this.controller, super.key});

  final MoodController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = controller.snapshot;
        if (snapshot == null && controller.loading) {
          return _SoftCard(
            child: Semantics(
              liveRegion: true,
              label: 'Checking in on your moods',
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: Text('Checking in on your moods…')),
                ],
              ),
            ),
          );
        }
        if (snapshot == null && controller.error != null) {
          return _SoftCard(
            child: _MoodError(
              onRetry: controller.refresh,
              saving: controller.saving,
            ),
          );
        }
        final ownMood = snapshot?.own?.mood;
        final partnerMood = snapshot?.partner;
        return _SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _CardLabel('Mood check-in')),
                  IconButton(
                    key: const Key('mood-refresh'),
                    tooltip: 'Refresh moods',
                    onPressed: controller.loading || controller.saving
                        ? null
                        : controller.refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                  if (controller.loading || controller.saving)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (controller.loading && snapshot != null)
                Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Semantics(
                    liveRegion: true,
                    label: 'Updating mood check-in',
                    child: Text(
                      'Updating your mood check-in…',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                ),
              if (controller.error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Your mood could not be saved. Check your connection and try again.',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
                TextButton(
                  onPressed: controller.saving ? null : controller.refresh,
                  child: const Text('Retry'),
                ),
              ],
              if (partnerMood == null)
                const _MoodEmptyState()
              else
                _PartnerMoodLine(mood: partnerMood),
              const SizedBox(height: AppSpacing.md),
              Text(
                ownMood == null
                    ? 'How are you feeling?'
                    : 'You feel ${ownMood.label.toLowerCase()}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (controller.saving)
                Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Semantics(
                    liveRegion: true,
                    label: 'Saving your mood',
                    child: Text(
                      'Saving your mood…',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                )
              else if (ownMood != null)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Visible to your partner',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Choose one to let your partner know.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final mood in MoodKind.values)
                    _MoodChoice(
                      mood: mood,
                      selected: ownMood == mood,
                      saving: controller.saving,
                      onSelected: () => controller.setMood(mood),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PartnerMoodLine extends StatelessWidget {
  const _PartnerMoodLine({required this.mood});

  final MoodCheckIn mood;

  @override
  Widget build(BuildContext context) {
    final relativeTime = _relativeMoodTime(mood.createdAt);
    return Row(
      children: [
        Text(mood.mood.emoji, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Semantics(
            label: 'Partner feels ${mood.mood.label}, $relativeTime',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Partner feels',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
                ),
                Text(
                  mood.mood.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  relativeTime,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MoodEmptyState extends StatelessWidget {
  const _MoodEmptyState();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your partner has not shared a mood yet',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your partner has not shared a mood yet.',
            style: TextStyle(color: AppColors.inkMuted),
          ),
          Text(
            'Send yours to break the ice.',
            style: TextStyle(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _MoodChoice extends StatelessWidget {
  const _MoodChoice({
    required this.mood,
    required this.selected,
    required this.saving,
    required this.onSelected,
  });

  final MoodKind mood;
  final bool selected;
  final bool saving;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected
          ? '${mood.label} is selected'
          : 'Set your mood to ${mood.label}',
      child: Semantics(
        button: true,
        selected: selected,
        label: '${mood.label} mood',
        hint: selected ? 'Selected' : 'Double tap to select',
        child: ChoiceChip(
          key: ValueKey('mood-choice-${mood.key}'),
          label: Text('${mood.emoji} ${mood.label}'),
          selected: selected,
          onSelected: saving || selected ? null : (_) => onSelected(),
          showCheckmark: true,
          checkmarkColor: AppColors.plum,
          selectedColor: (AppColors.mood[mood.key] ?? AppColors.blush)
              .withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _MoodError extends StatelessWidget {
  const _MoodError({required this.onRetry, required this.saving});

  final VoidCallback onRetry;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.error),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mood is unavailable offline. Reconnect to see and share the latest check-in.',
                style: TextStyle(color: AppColors.inkMuted),
              ),
              TextButton(
                onPressed: saving ? null : onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _relativeMoodTime(DateTime createdAt) {
  final elapsed = DateTime.now().toUtc().difference(createdAt.toUtc());
  if (elapsed.isNegative || elapsed.inSeconds < 60) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  if (elapsed.inDays == 1) return 'yesterday';
  return '${elapsed.inDays}d ago';
}

class _LiveNotice extends StatelessWidget {
  const _LiveNotice({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
                TextButton(onPressed: onPressed, child: Text(actionLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 15,
          color: AppColors.inkMuted,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            'Your space is private by design',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Rounded, soft card used across the demo dashboard.
class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: child,
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.inkMuted,
        fontSize: 12,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PartnerMoodCard extends StatelessWidget {
  const _PartnerMoodCard({required this.mood});
  final MoodCheckIn? mood;

  @override
  Widget build(BuildContext context) {
    final m = mood;
    if (m == null) {
      return const _SoftCard(
        child: Text('No mood yet — send yours to break the ice 💛'),
      );
    }
    final accent = AppColors.mood[m.mood.key] ?? AppColors.blush;
    return _SoftCard(
      color: accent.withValues(alpha: 0.18),
      child: Row(
        children: [
          Text(m.mood.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardLabel('Partner feels'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  m.mood.label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
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

class _WidgetPreviewCard extends StatelessWidget {
  const _WidgetPreviewCard({required this.widget});
  final WidgetResolution widget;

  @override
  Widget build(BuildContext context) {
    final isFallback = widget.isFallback;
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: _CardLabel('On their home screen')),
              _Badge(
                label: isFallback ? 'Default' : 'Scheduled',
                color: isFallback ? AppColors.inkMuted : AppColors.clay,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.assetId,
                style: const TextStyle(color: AppColors.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});
  final Reminder? reminder;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    if (r == null) {
      return const _SoftCard(child: Text('Nothing scheduled yet.'));
    }
    return _SoftCard(
      child: Row(
        children: [
          Text(r.kind.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardLabel('Coming up'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  r.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
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

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = [
    (icon: Icons.mood_rounded, label: 'Mood'),
    (icon: Icons.mic_rounded, label: 'Voice'),
    (icon: Icons.photo_rounded, label: 'Memory'),
    (icon: Icons.schedule_rounded, label: 'Widget'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final a in _actions)
          Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(a.icon, color: AppColors.blush),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(a.label, style: const TextStyle(fontSize: 13)),
            ],
          ),
      ],
    );
  }
}
