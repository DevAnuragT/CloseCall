import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationAccess {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  unsupported,
}

abstract interface class WidgetPermissionService {
  Future<NotificationAccess> notificationStatus();
  Future<NotificationAccess> requestNotifications();
  Future<bool> hasInstalledWidget();
  Future<bool> canPinWidget();
  Future<void> requestPinWidget();
  Future<bool> openSettings();
}

/// These are device capabilities, not consent to display a partner's photos.
/// No plugin is invoked on web or on platforms without our Android widget.
class AndroidWidgetPermissionService implements WidgetPermissionService {
  static const providerName = 'CloseCallWidgetProvider';

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  NotificationAccess _access(PermissionStatus status) => switch (status) {
    PermissionStatus.granted => NotificationAccess.granted,
    PermissionStatus.permanentlyDenied => NotificationAccess.permanentlyDenied,
    PermissionStatus.denied ||
    PermissionStatus.restricted => NotificationAccess.denied,
    _ => NotificationAccess.unknown,
  };

  @override
  Future<NotificationAccess> notificationStatus() async => _supported
      ? _access(await Permission.notification.status)
      : NotificationAccess.unsupported;

  @override
  Future<NotificationAccess> requestNotifications() async => _supported
      ? _access(await Permission.notification.request())
      : NotificationAccess.unsupported;

  @override
  Future<bool> hasInstalledWidget() async {
    if (!_supported) return false;
    final widgets = await HomeWidget.getInstalledWidgets();
    return widgets.any((widget) {
      final name = widget.androidClassName;
      return name == providerName || name?.endsWith('.$providerName') == true;
    });
  }

  @override
  Future<bool> canPinWidget() async =>
      _supported && await HomeWidget.isRequestPinWidgetSupported() == true;

  @override
  Future<void> requestPinWidget() async {
    if (!_supported) return;
    await HomeWidget.requestPinWidget(androidName: providerName);
  }

  @override
  Future<bool> openSettings() async => _supported && await openAppSettings();
}

abstract interface class PermissionPromptStore {
  Future<bool> wasHandled();
  Future<void> markHandled();
}

/// Plugin-free default for tests/demo. Production supplies the persistent store.
class MemoryPermissionPromptStore implements PermissionPromptStore {
  bool handled = false;

  @override
  Future<bool> wasHandled() async => handled;

  @override
  Future<void> markHandled() async => handled = true;
}

/// One installation key, deliberately independent of accounts and couples.
class SharedPreferencesPermissionPromptStore implements PermissionPromptStore {
  static const handledKey = 'closecall.notification_prompt.handled.v1';

  @override
  Future<bool> wasHandled() async =>
      (await SharedPreferences.getInstance()).getBool(handledKey) ?? false;

  @override
  Future<void> markHandled() async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(handledKey, true)) {
      throw StateError('Could not save notification prompt choice.');
    }
  }
}
