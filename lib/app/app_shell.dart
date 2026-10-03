import 'package:flutter/material.dart';

import '../features/home/domain/dashboard_snapshot.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/pairing/presentation/pairing_controller.dart';
import '../features/pairing/presentation/pairing_screen.dart';
import '../features/widget/presentation/widget_tab_screen.dart';
import 'placeholder_screen.dart';

/// Root navigation: the four product tabs (Home, Moments, Widget, Profile).
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.snapshot, this.pairing});

  /// Injectable for tests; falls back to deterministic mock data.
  final DashboardSnapshot? snapshot;

  /// Non-null selects live mode. Widget editor remains a local-only feature.
  final PairingController? pairing;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pairing = widget.pairing;

    final tabs = <Widget>[
      if (pairing == null)
        _label(
          'Demo mode — sample data, not connected to a server.',
          HomeScreen(snapshot: widget.snapshot ?? MockDashboard.snapshot()),
        )
      else
        ListenableBuilder(
          listenable: pairing,
          builder: (context, _) => PlaceholderScreen(
            title: pairing.error != null
                ? 'Server unavailable'
                : pairing.busy
                ? 'Connecting'
                : pairing.couple?.isComplete == true
                ? 'Paired'
                : 'Welcome',
            icon: Icons.favorite_rounded,
            message: pairing.error != null
                ? 'Server request failed: ${pairing.error}. Open Profile to retry.'
                : 'Manage live pairing in Profile. '
                      'Mood, reminders, and shared widget data are not connected yet.',
          ),
        ),
      const PlaceholderScreen(
        title: 'Moments',
        icon: Icons.auto_awesome_rounded,
        message: 'Your private shared scrapbook lives here.',
      ),
      _label(
        'Local widget editor — not synced to your partner.',
        const WidgetTabScreen(),
      ),
      if (pairing != null)
        PairingScreen(controller: pairing)
      else
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

  Widget _label(String message, Widget child) => Column(
    children: [
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(message, style: const TextStyle(fontSize: 12)),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
