import 'package:closecall/core/permissions/notification_permission_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  const widgets = MethodChannel('home_widget');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late AndroidWidgetPermissionService service;
  int status = PermissionStatus.denied.index;
  List<Map<String, Object>> installed = [];
  bool pinSupported = true;

  setUp(() {
    service = AndroidWidgetPermissionService();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    status = PermissionStatus.denied.index;
    installed = [];
    pinSupported = true;
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(permissions, (call) async {
      calls.add(call);
      return switch (call.method) {
        'checkPermissionStatus' => status,
        'requestPermissions' => {Permission.notification.value: status},
        'openAppSettings' => true,
        _ => throw StateError('Unexpected permission method'),
      };
    });
    messenger.setMockMethodCallHandler(widgets, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getInstalledWidgets' => installed,
        'isRequestPinWidgetSupported' => pinSupported,
        'requestPinWidget' => null,
        _ => throw StateError('Unexpected widget method'),
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(permissions, null);
    messenger.setMockMethodCallHandler(widgets, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Android requests only notification permission and maps its status',
    () async {
      for (final entry in {
        PermissionStatus.denied: NotificationAccess.denied,
        PermissionStatus.granted: NotificationAccess.granted,
        PermissionStatus.permanentlyDenied:
            NotificationAccess.permanentlyDenied,
        PermissionStatus.restricted: NotificationAccess.denied,
        PermissionStatus.limited: NotificationAccess.unknown,
        PermissionStatus.provisional: NotificationAccess.unknown,
      }.entries) {
        status = entry.key.index;
        expect(await service.notificationStatus(), entry.value);
        expect(await service.requestNotifications(), entry.value);
      }
      for (final call in calls) {
        if (call.method == 'checkPermissionStatus') {
          expect(call.arguments, Permission.notification.value);
        } else {
          expect(call.method, 'requestPermissions');
          expect(call.arguments, [Permission.notification.value]);
        }
      }
    },
  );

  test(
    'installed widgets must match our provider, not labels or other widgets',
    () async {
      installed = [
        {
          'widgetId': 1,
          'androidClassName': 'com.example.OtherProvider',
          'label': 'CloseCall',
        },
        {
          'widgetId': 2,
          'androidClassName': 'com.example.CloseCallWidgetProviderExtra',
        },
      ];
      expect(await service.hasInstalledWidget(), isFalse);
      installed.add({
        'widgetId': 3,
        'androidClassName': 'com.closecall.closecall.CloseCallWidgetProvider',
      });
      expect(await service.hasInstalledWidget(), isTrue);
      installed = [
        {'widgetId': 4, 'androidClassName': 'CloseCallWidgetProvider'},
      ];
      expect(await service.hasInstalledWidget(), isTrue);
    },
  );

  test(
    'pin support and request use home_widget without claiming installation',
    () async {
      expect(await service.canPinWidget(), isTrue);
      pinSupported = false;
      expect(await service.canPinWidget(), isFalse);
      await service.requestPinWidget();
      final pin = calls.last;
      expect(pin.method, 'requestPinWidget');
      expect(pin.arguments['android'], 'CloseCallWidgetProvider');
      expect(await service.hasInstalledWidget(), isFalse);
      expect(await service.openSettings(), isTrue);
      expect(calls.last.method, 'openAppSettings');
    },
  );

  for (final platform in TargetPlatform.values.where(
    (p) => p != TargetPlatform.android,
  )) {
    test('$platform is unsupported and never invokes plugins', () async {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        await service.notificationStatus(),
        NotificationAccess.unsupported,
      );
      expect(
        await service.requestNotifications(),
        NotificationAccess.unsupported,
      );
      expect(await service.hasInstalledWidget(), isFalse);
      expect(await service.canPinWidget(), isFalse);
      await service.requestPinWidget();
      expect(await service.openSettings(), isFalse);
      expect(calls, isEmpty);
    });
  }

  test(
    'prompt choice persists across store instances using one installation key',
    () async {
      final first = SharedPreferencesPermissionPromptStore();
      expect(await first.wasHandled(), isFalse);
      await first.markHandled();
      expect(
        await SharedPreferencesPermissionPromptStore().wasHandled(),
        isTrue,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), {
        SharedPreferencesPermissionPromptStore.handledKey,
      });
      expect(
        preferences.getBool(SharedPreferencesPermissionPromptStore.handledKey),
        isTrue,
      );
    },
  );

  test('memory stores are plugin-free and isolated by default', () async {
    final first = MemoryPermissionPromptStore();
    await first.markHandled();
    expect(await first.wasHandled(), isTrue);
    expect(await MemoryPermissionPromptStore().wasHandled(), isFalse);
    expect(calls, isEmpty);
  });
}
