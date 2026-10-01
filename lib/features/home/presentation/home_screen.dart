import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../mood/domain/mood.dart';
import '../../reminders/domain/reminder.dart';
import '../../widget/domain/widget_schedule_resolver.dart';
import '../domain/dashboard_snapshot.dart';

/// The emotional first screen: how your partner feels, what's on their home
/// screen right now, and what's coming up — all glanceable.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: AppSpacing.screen,
        children: [
          _Greeting(nickname: snapshot.partnerNickname),
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

class _Greeting extends StatelessWidget {
  const _Greeting({required this.nickname});
  final String nickname;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thinking of',
          style: TextStyle(color: AppColors.inkMuted, fontSize: 16),
        ),
        Text(
          nickname,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Rounded, soft card used across the dashboard.
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
      style: TextStyle(
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardLabel('Partner feels'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                m.mood.label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
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
              const _CardLabel('On their home screen'),
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
                style: TextStyle(color: AppColors.inkMuted),
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
                    color: AppColors.ink,
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

/// The four quick actions from the product spec. Wired to real flows later;
/// for now they surface the intent and keep the dashboard tappable.
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

