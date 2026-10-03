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
