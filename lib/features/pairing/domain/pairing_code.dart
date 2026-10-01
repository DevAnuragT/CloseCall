import 'dart:math';

/// Generation and normalization of couple pairing codes.
///
/// Codes use an unambiguous uppercase charset (no `0/O`, `1/I/L`) so they're
/// easy to read aloud and retype. The canonical form is 6 characters; the
/// display form groups them as `ABC-DEF`.
abstract final class PairingCode {
  /// Characters allowed in a code. Deliberately excludes `0 O 1 I L`.
  static const String charset = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int length = 6;

  /// Generates a random code. Pass a seeded [Random] for deterministic tests.
  static String generate({Random? random}) {
    final rng = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(charset[rng.nextInt(charset.length)]);
    }
    return buffer.toString();
  }

  /// Normalizes user input to canonical form: trims, uppercases, and strips
  /// spaces and hyphens. Does not validate — call [isValid] for that.
  static String normalize(String input) {
    return input
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .trim();
  }

  /// Whether [input], once normalized, is a well-formed code.
  static bool isValid(String input) {
    final code = normalize(input);
    if (code.length != length) return false;
    return code.split('').every(charset.contains);
  }

  /// Formats a code for display as two groups of three (`ABC-DEF`).
  /// Returns the normalized input unchanged if it isn't the canonical length.
  static String format(String input) {
    final code = normalize(input);
    if (code.length != length) return code;
    return '${code.substring(0, 3)}-${code.substring(3)}';
  }
}
