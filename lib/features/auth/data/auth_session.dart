import 'package:flutter/foundation.dart';

/// Minimal injectable authentication boundary for pairing UI and tests.
abstract class AuthSession extends ChangeNotifier {
  String? get userId;
  Future<void> initialize();
  Future<void> signInAnonymously();
  Future<void> signOut();
}
