import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../couple/domain/couple.dart';

/// Stores only the last pairing snapshot for the current signed-in identity.
/// It is a UI cache, never an authorization token; every server read remains
/// authoritative and can replace or clear it.
abstract interface class PairingCache {
  Future<CachedPairing?> read(String userId);
  Future<void> write(String userId, Couple couple, String? inviteCode);
  Future<void> clear(String userId);
}

class CachedPairing {
  const CachedPairing({required this.couple, this.inviteCode});

  final Couple couple;
  final String? inviteCode;
}

class SharedPreferencesPairingCache implements PairingCache {
  SharedPreferencesPairingCache({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  String _key(String userId) => 'closecall.pairing.cache.v1.$userId';

  @override
  Future<CachedPairing?> read(String userId) async {
    try {
      final raw = await _preferences.getString(_key(userId));
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final couple = Couple.fromJson(json['couple'] as Map<String, dynamic>);
      if (!couple.isComplete || !couple.memberIds.contains(userId)) return null;
      return CachedPairing(
        couple: couple,
        inviteCode: json['invite_code'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String userId, Couple couple, String? inviteCode) async {
    if (!couple.isComplete || !couple.memberIds.contains(userId)) return;
    try {
      await _preferences.setString(
        _key(userId),
        jsonEncode({'couple': couple.toJson(), 'invite_code': inviteCode}),
      );
    } catch (_) {}
  }

  @override
  Future<void> clear(String userId) async {
    try {
      await _preferences.remove(_key(userId));
    } catch (_) {}
  }
}
