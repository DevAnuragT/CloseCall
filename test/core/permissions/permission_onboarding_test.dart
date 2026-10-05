import 'dart:async';

import 'package:closecall/core/permissions/notification_permission_service.dart';
import 'package:closecall/core/permissions/permission_onboarding.dart';
import 'package:closecall/core/permissions/widget_readiness_controller.dart';
import 'package:closecall/core/theme/app_theme.dart';
import 'package:closecall/features/auth/presentation/auth_gate.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';

class _Permissions implements WidgetPermissionService {
  NotificationAccess access = NotificationAccess.denied;
  NotificationAccess requested = NotificationAccess.granted;
  Completer<NotificationAccess>? pendingRead;
  Completer<NotificationAccess>? pendingRequest;
  int requests = 0;

  @override
  Future<NotificationAccess> notificationStatus() async =>
      pendingRead?.future ?? access;
  @override
  Future<NotificationAccess> requestNotifications() async {
    requests++;
    return access = await (pendingRequest?.future ?? Future.value(requested));
  }

  @override
  Future<bool> hasInstalledWidget() async => false;
  @override
  Future<bool> canPinWidget() async => false;
  @override
  Future<void> requestPinWidget() async {}
  @override
  Future<bool> openSettings() async => true;
}

void main() {
  late _Permissions service;
  late MemoryPermissionPromptStore store;
  late WidgetReadinessController controller;

  setUp(() {
    service = _Permissions();
    store = MemoryPermissionPromptStore();
    controller = WidgetReadinessController(
      service: service,
      promptStore: store,
    );
  });
  tearDown(() => controller.dispose());

  Future<void> show(
    WidgetTester tester, {
    Widget? child,
    GlobalKey<NavigatorState>? navigatorKey,
    double scale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: PermissionOnboarding(
        controller: controller,
        child: child ?? const Scaffold(body: Text('Account home')),
      ),
    ),
  );

  testWidgets('first-launch Allow is the only OS request and is remembered', (
    tester,
  ) async {
    await tester.runAsync(controller.initialize);
    await show(tester);
    await tester.pumpAndSettle();
    expect(find.text('Allow CloseCall notifications?'), findsOneWidget);
    expect(service.requests, 0);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('permission-allow')));
      await controller.refresh();
    });
    await tester.pumpAndSettle();
    expect(service.requests, 1);
    expect(store.handled, isTrue);
    expect(find.text('Account home'), findsOneWidget);
    service.access = NotificationAccess.denied;
    await tester.runAsync(controller.refresh);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Not now persists once across resume and a new controller', (
    tester,
  ) async {
    await tester.runAsync(controller.initialize);
    await show(tester);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('permission-not-now')));
      await controller.refresh();
    });
    await tester.pumpAndSettle();
    expect(service.requests, 0);
    expect(store.handled, isTrue);
    await tester.runAsync(() async {
      controller.setForeground(false);
      controller.setForeground(true);
      await controller.refresh();
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.runAsync(() async {
      controller = WidgetReadinessController(
        service: service,
        promptStore: store,
      );
      await controller.initialize();
    });
    await show(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('denial does not block auth home or repeat on identity reset', (
    tester,
  ) async {
    service.requested = NotificationAccess.denied;
    final auth = FakeAuth()..change('me');
    final pairing = PairingController(session: auth, repository: FakeCouples());
    await tester.runAsync(pairing.initialize);
    controller.bindPairing(pairing);
    await tester.runAsync(controller.initialize);
    await show(
      tester,
      child: AuthGate(
        pairing: pairing,
        emailBuilder: (_) => const Text('Email sign in'),
        signedInBuilder: (_) => const Scaffold(body: Text('Account home')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('permission-allow')));
      await controller.refresh();
    });
    await tester.pumpAndSettle();
    expect(find.text('Account home'), findsOneWidget);
    expect(controller.notificationAccess, NotificationAccess.denied);
    await tester.runAsync(() async {
      auth.change(null);
      await controller.refresh();
    });
    await tester.pumpAndSettle();
    expect(find.text('Email sign in'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.requests, 1);
    await tester.pumpWidget(const SizedBox());
    controller.bindPairing(null);
    pairing.dispose();
    auth.dispose();
  });

  testWidgets('permission return never pops a route opened after the button', (
    tester,
  ) async {
    await tester.runAsync(() async {
      service.pendingRequest = Completer<NotificationAccess>();
    });
    final navigator = GlobalKey<NavigatorState>();
    await tester.runAsync(controller.initialize);
    await show(tester, navigatorKey: navigator);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('permission-allow')));
      await Future<void>.value();
    });
    await tester.pump();
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Email verification')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      service.pendingRequest!.complete(NotificationAccess.granted);
      await controller.refresh();
    });
    await tester.pumpAndSettle();
    expect(find.text('Email verification'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a slow first check does not interrupt email interaction', (
    tester,
  ) async {
    late Future<void> initializing;
    await tester.runAsync(() async {
      service.pendingRead = Completer<NotificationAccess>();
      initializing = controller.initialize();
      await Future<void>.value();
    });
    await show(tester, child: const Scaffold(body: TextField()));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'hello@example.test');
    await tester.runAsync(() async {
      service.pendingRead!.complete(NotificationAccess.denied);
      await initializing;
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();
    expect(store.handled, isTrue);
    expect(service.requests, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('teardown removes only the invitation without navigator errors', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.runAsync(controller.initialize);
    await show(
      tester,
      navigatorKey: navigator,
      child: const Scaffold(body: Text('Account home')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Replacement home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('invitation fits width $width at text scale 2', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(controller.initialize);
      await show(tester, scale: 2);
      await tester.pumpAndSettle();
      expect(find.text('Allow CloseCall notifications?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('permission-not-now')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
