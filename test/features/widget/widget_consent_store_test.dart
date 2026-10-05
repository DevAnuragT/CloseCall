import 'dart:async';

import 'package:closecall/features/widget/data/shared_preferences_widget_consent_store.dart';
import 'package:closecall/features/widget/data/widget_consent_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake only the preference transport, not the adapter's encoding/queue.
class TestAsyncPreferences implements SharedPreferencesAsync {
  TestAsyncPreferences({this.pendingSet});

  final values = <String, String>{};
  final Completer<void>? pendingSet;
  final calls = <String>[];

  @override
  Future<String?> getString(String key) async {
    calls.add('read');
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    calls.add('write');
    if (pendingSet != null) await pendingSet!.future;
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    calls.add('remove');
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'SharedPreferencesAsync adapter round-trips scoped consent across instances',
    () async {
      final preferences = TestAsyncPreferences();
      final store = SharedPreferencesWidgetConsentStore(
        preferences: preferences,
      );
      await store.write(
        const WidgetDeviceConsent(
          userId: 'user',
          coupleId: 'couple',
          enabled: true,
        ),
      );
      final restarted = SharedPreferencesWidgetConsentStore(
        preferences: preferences,
      );
      final restored = (await restarted.read())!;
      expect(restored.matches('user', 'couple'), isTrue);
      expect(restored.enabled, isTrue);
      await restarted.write(
        const WidgetDeviceConsent(
          userId: 'user',
          coupleId: 'couple',
          enabled: false,
        ),
      );
      expect((await store.read())!.enabled, isFalse);
      await store.write(null);
      expect(await restarted.read(), isNull);
    },
  );

  test('adapter reads and clears serialize behind delayed writes', () async {
    final preferences = TestAsyncPreferences(pendingSet: Completer<void>());
    final store = SharedPreferencesWidgetConsentStore(preferences: preferences);
    final write = store.write(
      const WidgetDeviceConsent(
        userId: 'user',
        coupleId: 'couple',
        enabled: true,
      ),
    );
    final clear = store.write(null);
    final read = store.read();
    await Future<void>.value();
    expect(preferences.calls, ['write']);
    preferences.pendingSet!.complete();
    await Future.wait([write, clear]);
    expect(await read, isNull);
    expect(preferences.calls, ['write', 'remove', 'read']);
  });

  test('corrupt preferences do not create a device opt-in', () async {
    final preferences = TestAsyncPreferences();
    preferences.values[SharedPreferencesWidgetConsentStore.key] = '{bad-json';
    final store = SharedPreferencesWidgetConsentStore(preferences: preferences);
    expect(await store.read(), isNull);
  });
}
