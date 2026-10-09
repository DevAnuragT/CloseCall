import 'dart:convert';

import 'package:closecall/core/push/widget_read_credential.dart';
import 'package:closecall/core/push/widget_read_credential_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _SecureStorage implements WidgetCredentialSecureStorage {
  final values = <String, String>{};
  int deletes = 0;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async {
    deletes++;
    values.remove(key);
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 7, 12);
  late _SecureStorage secure;
  late SecureWidgetReadCredentialStore store;
  setUp(() {
    secure = _SecureStorage();
    store = SecureWidgetReadCredentialStore(storage: secure, now: () => now);
  });

  Map<String, Object?> record() => {
    'version': 1,
    'credential': 'opaque-widget-token',
    'deviceId': 'installation',
    'userId': 'me',
    'coupleId': 'couple',
    'expiresAt': now.add(const Duration(hours: 24)).toIso8601String(),
  };

  test(
    'round-trip writes scope/token/expiry together in one secure key',
    () async {
      await store.write(
        WidgetReadCredential(
          credential: 'opaque-widget-token',
          deviceId: 'installation',
          userId: 'me',
          coupleId: 'couple',
          expiresAt: now.add(const Duration(hours: 24)),
        ),
      );
      expect(secure.values.keys, [SecureWidgetReadCredentialStore.key]);
      expect(jsonDecode(secure.values.values.single), record());
      final read = await store.read();
      expect(read!.matches('me', 'couple', 'installation'), isTrue);
      expect(read.credential, 'opaque-widget-token');
      expect(read.expiresAt, now.add(const Duration(hours: 24)));
      expect('$read', isNot(contains(read.credential)));
      await store.delete();
      expect(await store.read(), isNull);
    },
  );

  final corruptions = <String, Object?>{
    'credential': '',
    'deviceId': 42,
    'userId': ' ',
    'coupleId': null,
    'version': 2,
    'expiresAt': 'not-a-date',
  };
  for (final corruption in corruptions.entries) {
    test(
      'corrupt ${corruption.key} is deleted without exposing parse error',
      () async {
        final json = record()..[corruption.key] = corruption.value;
        secure.values[SecureWidgetReadCredentialStore.key] = jsonEncode(json);
        expect(await store.read(), isNull);
        expect(secure.values, isEmpty);
        expect(secure.deletes, 1);
      },
    );
  }

  for (final expiry in [
    now.subtract(const Duration(seconds: 1)).toIso8601String(),
    now.toIso8601String(),
    now.add(const Duration(days: 2)).toIso8601String(),
    '2026-10-08T12:00:00',
  ]) {
    test('invalid expiry $expiry fails closed', () async {
      final json = record()..['expiresAt'] = expiry;
      secure.values[SecureWidgetReadCredentialStore.key] = jsonEncode(json);
      expect(await store.read(), isNull);
      expect(secure.values, isEmpty);
    });
  }

  test('malformed/oversized JSON is removed', () async {
    for (final raw in [
      'not-json',
      '[]',
      '{"credential":"secret"}',
      'x' * 8193,
    ]) {
      secure.values[SecureWidgetReadCredentialStore.key] = raw;
      expect(await store.read(), isNull);
      expect(secure.values, isEmpty);
    }
  });

  test('invalid write never persists a secret', () async {
    await expectLater(
      store.write(
        WidgetReadCredential(
          credential: 'secret-value',
          deviceId: 'installation',
          userId: 'me',
          coupleId: 'couple',
          expiresAt: now,
        ),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => '$error',
          'error is redacted',
          isNot(contains('secret-value')),
        ),
      ),
    );
    expect(secure.values, isEmpty);
  });
}
