import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'widget_read_credential.dart';

abstract interface class WidgetReadCredentialStore {
  Future<WidgetReadCredential?> read();
  Future<void> write(WidgetReadCredential value);
  Future<void> delete();
}

/// Injectable raw secure-storage boundary; tests need no platform channels.
abstract interface class WidgetCredentialSecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterWidgetCredentialSecureStorage
    implements WidgetCredentialSecureStorage {
  const FlutterWidgetCredentialSecureStorage();
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Scope, token and expiry are one secure record. There is no preferences copy,
/// logging, or migration through plaintext storage.
class SecureWidgetReadCredentialStore implements WidgetReadCredentialStore {
  SecureWidgetReadCredentialStore({
    this.storage = const FlutterWidgetCredentialSecureStorage(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const key = 'closecall.widget.read_credential.v1';
  final WidgetCredentialSecureStorage storage;
  final DateTime Function() _now;

  @override
  Future<WidgetReadCredential?> read() async {
    final raw = await storage.read(key);
    if (raw == null) return null;
    WidgetReadCredential? result;
    try {
      if (raw.length > 8192) throw const FormatException();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1) throw const FormatException();
      final expiry = DateTime.parse(json['expiresAt'] as String);
      if (!expiry.isUtc) throw const FormatException();
      result = WidgetReadCredential(
        credential: json['credential'] as String,
        deviceId: json['deviceId'] as String,
        userId: json['userId'] as String,
        coupleId: json['coupleId'] as String,
        expiresAt: expiry,
      );
      if (!result.validAt(_now().toUtc())) result = null;
    } catch (_) {
      // Parse errors can contain input values; never surface those errors.
      result = null;
    }
    if (result == null) await delete();
    return result;
  }

  @override
  Future<void> write(WidgetReadCredential value) async {
    if (!value.validAt(_now().toUtc())) {
      throw const FormatException('Invalid widget read credential.');
    }
    await storage.write(
      key,
      jsonEncode({
        'version': 1,
        'credential': value.credential,
        'deviceId': value.deviceId,
        'userId': value.userId,
        'coupleId': value.coupleId,
        'expiresAt': value.expiresAt.toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<void> delete() => storage.delete(key);
}
