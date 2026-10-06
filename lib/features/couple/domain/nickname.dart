/// One to forty Unicode code points, or blank to clear. Mirrors server rules.
String? normalizeNickname(String? value) {
  if (value == null) return null;
  if (value.length > 1024 ||
      RegExp(
        r'[\x00-\x1f\x7f-\x9f\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]',
      ).hasMatch(value)) {
    throw const NicknameValidationException();
  }
  final normalized = value
      .replaceAll(
        RegExp(r'[ \u00a0\u1680\u2000-\u200a\u202f\u205f\u3000]+'),
        ' ',
      )
      .trim();
  if (normalized.isEmpty) return null;
  if (normalized.runes.length > 40) {
    throw const NicknameValidationException();
  }
  return normalized;
}

class NicknameValidationException implements Exception {
  const NicknameValidationException();
}

class NicknameScopeException implements Exception {
  const NicknameScopeException();
}
