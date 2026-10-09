/// Device-scoped widget read authority, never a user-session credential.
/// Deliberately has no credential-bearing toString/error representation.
class WidgetReadCredential {
  const WidgetReadCredential({
    required this.credential,
    required this.deviceId,
    required this.userId,
    required this.coupleId,
    required this.expiresAt,
  });

  final String credential;
  final String deviceId;
  final String userId;
  final String coupleId;
  final DateTime expiresAt;

  static const lifetime = Duration(hours: 24);
  static const renewalWindow = Duration(hours: 1);
  // Small transport/clock skew allowance, not an extension of server authority.
  static const clockSkew = Duration(minutes: 5);

  bool validAt(DateTime now) =>
      _validText(credential, 4096) &&
      _validText(deviceId, 256) &&
      _validText(userId, 256) &&
      _validText(coupleId, 256) &&
      expiresAt.isAfter(now) &&
      !expiresAt.isAfter(now.add(lifetime + clockSkew));

  bool matches(String user, String couple, String device) =>
      userId == user && coupleId == couple && deviceId == device;

  bool needsRenewal(DateTime now) => expiresAt.difference(now) < renewalWindow;

  static bool _validText(String text, int maxLength) =>
      text.isNotEmpty && text.trim() == text && text.length <= maxLength;
}
