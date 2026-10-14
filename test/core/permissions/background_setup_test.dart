import 'package:closecall/core/permissions/background_reliability_service.dart';
import 'package:closecall/core/permissions/background_setup_prompt.dart';
import 'package:closecall/core/permissions/notification_permission_service.dart';
import 'package:closecall/core/permissions/widget_readiness_controller.dart';
import 'package:closecall/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Permissions implements WidgetPermissionService {
  NotificationAccess access = NotificationAccess.granted;

  @override
  Future<NotificationAccess> notificationStatus() async => access;
  @override
  Future<NotificationAccess> requestNotifications() async => access;
  @override
  Future<bool> hasInstalledWidget() async => false;
  @override
  Future<bool> canPinWidget() async => false;
  @override
  Future<void> requestPinWidget() async {}
  @override
  Future<bool> openSettings() async => true;
}

class _Background implements BackgroundReliabilityService {
  bool exempt = false;
  String vendor = 'xiaomi';
  int batteryRequests = 0;
  int autostartOpens = 0;

  @override
  Future<BackgroundStatus> status() async => BackgroundStatus(
    ignoringBatteryOptimizations: exempt,
    manufacturer: vendor,
    hasVendorAutostartScreen: isKnownVendor(vendor),
  );

  @override
  Future<bool> requestBatteryExemption() async {
    batteryRequests++;
    exempt = true;
    return true;
  }

  @override
  Future<String> openAutostart() async {
    autostartOpens++;
    return isKnownVendor(vendor) ? 'vendor' : 'app';
  }
}

void main() {
  late _Background background;
  late MemoryBackgroundSetupStore store;
  late WidgetReadinessController controller;

  setUp(() {
    background = _Background();
    store = MemoryBackgroundSetupStore();
    controller = WidgetReadinessController(
      service: _Permissions(),
      background: background,
      backgroundStore: store,
    );
  });
  tearDown(() => controller.dispose());

  Future<void> show(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: BackgroundSetupPrompt(
        controller: controller,
        child: const Scaffold(body: Text('Account home')),
      ),
    ),
  );

  test(
    'controller only invites once the device is ready and unhandled',
    () async {
      expect(controller.shouldPromptBackground, isFalse);
      await controller.initialize();
      expect(controller.shouldPromptBackground, isTrue);
      expect(controller.backgroundStatus?.manufacturer, 'xiaomi');
      await controller.deferBackgroundPrompt();
      expect(controller.shouldPromptBackground, isFalse);
      expect(store.handled, isTrue);
    },
  );

  test('invitation waits while the notification prompt is pending', () async {
    final denied = WidgetReadinessController(
      service: _Permissions()..access = NotificationAccess.denied,
      background: background,
      backgroundStore: MemoryBackgroundSetupStore(),
    );
    addTearDown(denied.dispose);
    await denied.initialize();
    expect(denied.shouldPrompt, isTrue);
    expect(denied.shouldPromptBackground, isFalse);
  });

  test(
    'no invitation without a background service or after handling',
    () async {
      final none = WidgetReadinessController(service: _Permissions());
      addTearDown(none.dispose);
      await none.initialize();
      expect(none.backgroundSupported, isFalse);
      expect(none.shouldPromptBackground, isFalse);

      store.handled = true;
      final handled = WidgetReadinessController(
        service: _Permissions(),
        background: background,
        backgroundStore: store,
      );
      addTearDown(handled.dispose);
      await handled.initialize();
      expect(handled.shouldPromptBackground, isFalse);
    },
  );

  test(
    'actions persist the choice, call the OS and refresh battery state',
    () async {
      await controller.initialize();
      await controller.requestBackgroundExemption();
      expect(background.batteryRequests, 1);
      expect(controller.backgroundStatus?.ignoringBatteryOptimizations, isTrue);
      await controller.openAutostartSettings();
      expect(background.autostartOpens, 1);
      expect(store.handled, isTrue);
    },
  );

  test('a failing background service never blocks readiness', () async {
    final failing = WidgetReadinessController(
      service: _Permissions(),
      background: _Failing(),
    );
    addTearDown(failing.dispose);
    await failing.initialize();
    expect(failing.initialised, isTrue);
    expect(failing.error, isNull);
    expect(failing.shouldPromptBackground, isFalse);
  });

  testWidgets('dialog explains both steps and Done is remembered', (
    tester,
  ) async {
    await tester.runAsync(controller.initialize);
    await show(tester);
    await tester.pumpAndSettle();
    expect(find.text('Keep CloseCall working when closed'), findsOneWidget);
    expect(find.text('2. Turn on “Autostart” for CloseCall'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('background-battery-action')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(background.batteryRequests, 1);
    expect(find.byKey(const Key('background-battery-done')), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('background-setup-done')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.handled, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unknown vendors get the app-settings fallback copy', (
    tester,
  ) async {
    background.vendor = 'pixel';
    await tester.runAsync(controller.initialize);
    await show(tester);
    await tester.pumpAndSettle();
    expect(find.text('2. Open CloseCall’s app settings'), findsOneWidget);
    expect(find.textContaining('Unrestricted'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Failing implements BackgroundReliabilityService {
  @override
  Future<BackgroundStatus> status() async => throw StateError('unavailable');
  @override
  Future<bool> requestBatteryExemption() async => false;
  @override
  Future<String> openAutostart() async => 'none';
}
