import 'dart:math';

/// Matches lib/features/pairing/domain/pairing_code.dart in the Flutter app.
abstract final class InviteCode {
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 6;

  static String generate() {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '').trim();

  static bool isValid(String normalized) =>
      normalized.length == length &&
      normalized.split('').every(alphabet.contains);
}
