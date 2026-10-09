import 'dart:ui' show Tristate;

import 'package:closecall/app/app_shell.dart';
import 'package:closecall/main.dart';
import 'package:closecall/core/theme/app_theme.dart';
import 'package:closecall/features/couple/data/couple_repository.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/live_fakes.dart';

void main() {
  testWidgets('App boots into the 4-tab shell starting on Home', (
    tester,
  ) async {
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

  testWidgets('tapping the Widget tab updates the selected index', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));

    // The unselected Widget destination shows the outlined icon.
    await tester.tap(find.byIcon(Icons.dashboard_customize_outlined));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets('navigation destinations expose labels and selected state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AppShell()),
    );

    final home = find.bySemanticsLabel(RegExp(r'^Home'));
    final moments = find.bySemanticsLabel(RegExp(r'^Moments'));
    expect(home, findsOneWidget);
    expect(moments, findsOneWidget);
    expect(
      tester.getSemantics(home).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(moments).flagsCollection.isSelected,
      Tristate.isFalse,
    );

    await tester.tap(moments);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(moments).flagsCollection.isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('ignores navigation indexes outside the four-tab range', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AppShell()),
    );

    final bar = tester.widget<NavigationBar>(
      find.byKey(const Key('primary-navigation')),
    );
    bar.onDestinationSelected!(-1);
    bar.onDestinationSelected!(4);
    await tester.pump();

    expect(
      tester
          .widget<NavigationBar>(find.byKey(const Key('primary-navigation')))
          .selectedIndex,
      0,
    );
  });

  testWidgets('keeps all navigation destinations usable on a small screen', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AppShell()),
    );

    for (final label in ['Home', 'Moments', 'Widget', 'Profile']) {
      expect(find.bySemanticsLabel(RegExp('^$label')), findsOneWidget);
    }
    expect(
      tester.getBottomRight(find.byType(NavigationBar)).dy,
      lessThanOrEqualTo(640),
    );
  });

  for (final pending in [false, true]) {
    testWidgets(
      'Widget ${pending ? 'View invite' : 'Connect partner'} opens Profile pairing',
      (tester) async {
        final auth = FakeAuth()..change('me');
        final repository = _ShellCouples(pending);
        final pairing = PairingController(
          session: auth,
          repository: repository,
        );
        await pairing.initialize();
        addTearDown(() {
          pairing.dispose();
          auth.dispose();
        });
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: AppShell(pairing: pairing),
          ),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Widget'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const Key('choose-local-photo'))).bottom,
          lessThan(700),
        );
        expect(find.text('Preview · illustration'), findsOneWidget);
        expect(find.textContaining('Private server photos'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        final action = find.byKey(const Key('widget-connect-partner'));
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          3,
        );
        final inviteField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Partner invite code',
        );
        expect(inviteField, findsOneWidget);
        await tester.ensureVisible(inviteField);
        await tester.pumpAndSettle();
        await tester.enterText(inviteField, 'ABC123');
        expect(
          tester.widget<TextField>(inviteField).controller!.text,
          'ABC123',
        );
        if (pending) expect(find.text('ABC123'), findsWidgets);
      },
    );
  }
}

class _ShellCouples extends FakeCouples implements PairingCodeReader {
  _ShellCouples(this.pending) {
    couple = pending
        ? Couple(id: 'pending-secret-id', memberIds: ['me'])
        : null;
  }
  final bool pending;
  @override
  String? get currentInviteCode => pending ? 'ABC123' : null;
}
