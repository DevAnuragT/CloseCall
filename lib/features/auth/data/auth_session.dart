import 'package:flutter/foundation.dart';
import 'package:closecall_client/closecall_client.dart';

/// Minimal injectable authentication boundary for pairing UI and tests.
abstract class AuthSession extends ChangeNotifier {
  String? get userId;
  Future<void> initialize();
  Future<void> signInAnonymously();
  Future<void> signOut();

  /// Unknown status stays conservative; test sessions need no native plugins.
  Future<AccountState?> currentAccount() async => null;
}

class SessionValidationException implements Exception {
  const SessionValidationException();

  @override
  String toString() => 'Unable to validate this session. Retry when online.';
}

/// Only thrown after persisted credentials and the local identity are cleared.
class LocalSignOutException implements Exception {
  const LocalSignOutException();

  @override
  String toString() =>
      'Signed out of this device. Server revocation could not be confirmed.';
}
