import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Battery-optimization state is readable; vendor autostart state is not, so
/// the UI treats autostart as a guided step rather than a verified status.
class BackgroundStatus {
  const BackgroundStatus({
    required this.ignoringBatteryOptimizations,
    required this.manufacturer,
    required this.hasVendorAutostartScreen,
  });

  final bool ignoringBatteryOptimizations;
  final String manufacturer;
  final bool hasVendorAutostartScreen;
}

abstract interface class BackgroundReliabilityService {
  Future<BackgroundStatus> status();
  Future<bool> requestBatteryExemption();

  /// Returns `vendor`, `app` or `none` depending on the screen that opened.
  Future<String> openAutostart();
}

class AndroidBackgroundReliabilityService
    implements BackgroundReliabilityService {
  static const _channel = MethodChannel('closecall/background_reliability');

  @override
  Future<BackgroundStatus> status() async {
    final map = await _channel.invokeMapMethod<String, Object?>('status');
    return BackgroundStatus(
      ignoringBatteryOptimizations:
          map?['ignoringBatteryOptimizations'] == true,
      manufacturer: map?['manufacturer'] as String? ?? '',
      hasVendorAutostartScreen: map?['hasVendorAutostartScreen'] == true,
    );
  }

  @override
  Future<bool> requestBatteryExemption() async =>
      await _channel.invokeMethod<bool>('requestBatteryExemption') == true;

  @override
  Future<String> openAutostart() async =>
      await _channel.invokeMethod<String>('openAutostart') ?? 'none';
}

abstract interface class BackgroundSetupStore {
  Future<bool> wasHandled();
  Future<void> markHandled();
}

class MemoryBackgroundSetupStore implements BackgroundSetupStore {
  bool handled = false;

  @override
  Future<bool> wasHandled() async => handled;

  @override
  Future<void> markHandled() async => handled = true;
}

/// One installation key, independent of accounts and couples.
class SharedPreferencesBackgroundSetupStore implements BackgroundSetupStore {
  static const handledKey = 'closecall.background_setup.handled.v1';

  @override
  Future<bool> wasHandled() async =>
      (await SharedPreferences.getInstance()).getBool(handledKey) ?? false;

  @override
  Future<void> markHandled() async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(handledKey, true)) {
      throw StateError('Could not save background setup choice.');
    }
  }
}

/// Plain-language names for the vendor setting, for dialog copy.
String autostartSettingLabel(String manufacturer) => switch (manufacturer) {
  'xiaomi' => 'Autostart',
  'oppo' || 'realme' || 'oneplus' => 'Auto-launch / Startup manager',
  'vivo' => 'Background app management',
  'huawei' || 'honor' => 'App launch',
  'samsung' => 'Sleeping apps',
  _ => 'Battery and background settings',
};

@visibleForTesting
bool isKnownVendor(String manufacturer) =>
    autostartSettingLabel(manufacturer) != 'Battery and background settings';
