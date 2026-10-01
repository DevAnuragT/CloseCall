import 'package:flutter/material.dart';

import '../features/home/domain/dashboard_snapshot.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/widget/presentation/widget_tab_screen.dart';
import 'placeholder_screen.dart';

/// Root navigation: the four product tabs (Home, Moments, Widget, Profile).
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.snapshot});

  /// Injectable for tests; falls back to deterministic mock data.
  final DashboardSnapshot? snapshot;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot ?? MockDashboard.snapshot();

    final tabs = <Widget>[
      HomeScreen(snapshot: snapshot),
      const PlaceholderScreen(
        title: 'Moments',
        icon: Icons.auto_awesome_rounded,
        message: 'Your private shared scrapbook lives here.',
      ),
      const WidgetTabScreen(),
      const PlaceholderScreen(
        title: 'Profile',
        icon: Icons.favorite_rounded,
        message: 'Your pairing, nickname, anniversary, and theme.',
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'Moments',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_customize_outlined),
            selectedIcon: Icon(Icons.dashboard_customize_rounded),
            label: 'Widget',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
