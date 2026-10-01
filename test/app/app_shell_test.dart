import 'package:closecall/app/app_shell.dart';
import 'package:closecall/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots into the 4-tab shell starting on Home',
      (tester) async {
    await tester.pumpWidget(const CloseCallApp());

    // 'Home' appears only as the nav label; the greeting confirms the Home
    // tab is the active screen.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Thinking of'), findsOneWidget);

    // The other three destinations also exist (also as placeholder titles,
    // since IndexedStack keeps every tab mounted).
    expect(find.text('Moments'), findsWidgets);
    expect(find.text('Widget'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
  });

  testWidgets('tapping the Widget tab updates the selected index',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    // The unselected Widget destination shows the outlined icon.
    await tester.tap(find.byIcon(Icons.dashboard_customize_outlined));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });
}
