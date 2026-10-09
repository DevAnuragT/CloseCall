import 'package:flutter/material.dart';

import '../core/permissions/widget_readiness_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../features/auth/presentation/account_controller.dart';
import '../features/home/domain/dashboard_snapshot.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/media/presentation/media_controller.dart';
import '../features/mood/presentation/mood_controller.dart';
import '../features/pairing/presentation/pairing_controller.dart';
import '../features/pairing/presentation/pairing_screen.dart';
import '../features/widget/presentation/schedule_controller.dart';
import '../features/widget/presentation/widget_tab_screen.dart';
import 'moments_screen.dart';

/// Root navigation for the four intimate, glanceable product spaces.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.snapshot,
    this.pairing,
    this.account,
    this.media,
    this.mood,
    this.schedules,
    this.readiness,
  });

  final AccountController? account;
  final MediaController? media;
  final MoodController? mood;
  final ScheduleController? schedules;
  final WidgetReadinessController? readiness;

  /// Injectable for tests; falls back to deterministic mock data in demo mode.
  final DashboardSnapshot? snapshot;

  /// Non-null selects live mode, never substituting demo data on errors.
  final PairingController? pairing;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _openProfile() => _selectTab(3);

  void _selectTab(int index) {
    if (index < 0 || index >= _tabCount || index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pairing = widget.pairing;
    final liveMode = pairing != null;

    final tabs = <Widget>[
      if (!liveMode)
        _label(
          'Demo mode — sample data, not connected to a server.',
          HomeScreen(snapshot: widget.snapshot ?? MockDashboard.snapshot()),
        )
      else
        HomeScreen(
          pairing: pairing,
          mood: widget.mood,
          onOpenPairing: _openProfile,
        ),
      MomentsScreen(liveMode: liveMode),
      WidgetTabScreen(
        media: widget.media,
        pairing: pairing,
        liveMode: liveMode,
        schedules: widget.schedules,
        readiness: widget.readiness,
        onConnectPartner: _openProfile,
      ),
      if (pairing != null)
        PairingScreen(
          controller: pairing,
          account: widget.account,
          schedules: widget.schedules,
          readiness: widget.readiness,
        )
      else
        const _DemoProfileScreen(),
    ];
    final selectedIndex = _safeTabIndex(_index, tabs.length);

    return Scaffold(
      body: ColoredBox(
        color: AppColors.paper,
        child: IndexedStack(index: selectedIndex, children: tabs),
      ),
      bottomNavigationBar: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Primary navigation',
        child: NavigationBar(
          key: const Key('primary-navigation'),
          selectedIndex: selectedIndex,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
              tooltip: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: 'Moments',
              tooltip: 'Moments',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_customize_outlined),
              selectedIcon: Icon(Icons.dashboard_customize_rounded),
              label: 'Widget',
              tooltip: 'Widget',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Profile',
              tooltip: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String message, Widget child) => Column(
    children: [
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.plum,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );

  static const _tabCount = 4;

  int _safeTabIndex(int index, int tabCount) {
    if (tabCount == 0) return 0;
    return index.clamp(0, tabCount - 1).toInt();
  }
}

class _DemoProfileScreen extends StatelessWidget {
  const _DemoProfileScreen();

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
          Text(
            'Profile',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'A gentle preview of your private space.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite_rounded, color: AppColors.clay),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Connect to make it yours',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Demo mode keeps everything on this device. Sign in to manage your pairing and shared space.',
                  style: TextStyle(color: AppColors.inkMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
