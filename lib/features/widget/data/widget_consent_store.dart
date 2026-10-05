import 'dart:convert';

/// Consent is deliberately keyed by stable identities, never auth revisions.
class WidgetDeviceConsent {
  const WidgetDeviceConsent({
    required this.userId,
    required this.coupleId,
    required this.enabled,
  });

  final String userId;
  final String coupleId;
  final bool enabled;

  bool matches(String user, String couple) =>
      userId == user && coupleId == couple;

  String encode() =>
      jsonEncode({'userId': userId, 'coupleId': coupleId, 'enabled': enabled});

  static WidgetDeviceConsent? decode(String? value) {
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map ||
          json['userId'] is! String ||
          json['coupleId'] is! String ||
          json['enabled'] is! bool) {
        return null;
      }
      return WidgetDeviceConsent(
        userId: json['userId'] as String,
        coupleId: json['coupleId'] as String,
        enabled: json['enabled'] as bool,
      );
    } on FormatException {
      return null;
    }
  }
}

abstract interface class WidgetConsentStore {
  Future<WidgetDeviceConsent?> read();
  Future<void> write(WidgetDeviceConsent? consent);
}

/// Plugin-free default. Production explicitly supplies persistent storage.
class MemoryWidgetConsentStore implements WidgetConsentStore {
  WidgetDeviceConsent? value;

  @override
  Future<WidgetDeviceConsent?> read() async => value;

  @override
  Future<void> write(WidgetDeviceConsent? consent) async => value = consent;
}
