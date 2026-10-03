import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Creates local-only secrets; never prints them or replaces existing secrets.
void main() {
  final config = Directory('closecall_server/config');
  if (!config.existsSync()) {
    stderr.writeln('Run this command from the CloseCall repository root.');
    exitCode = 1;
    return;
  }
  final file = File('${config.path}/passwords.yaml');
  // Append mode leaves under an exclusive OS lock. FileMode.append never
  // truncates an existing password file, including during concurrent setup.
  final handle = file.openSync(mode: FileMode.append);
  handle.lockSync(FileLock.exclusive);
  try {
    if (!Platform.isWindows) {
      final result = Process.runSync('chmod', ['600', file.path]);
      if (result.exitCode != 0) {
        throw StateError('Cannot restrict permissions on local password file.');
      }
    }
    final existing = file.readAsStringSync();
    final updated = addMissingLocalSecrets(existing);
    if (updated != existing) {
      handle.setPositionSync(0);
      handle.writeStringSync(updated);
      handle.truncateSync(utf8.encode(updated).length);
      handle.flushSync();
    }
  } finally {
    handle.unlockSync();
    handle.closeSync();
  }
  stdout.writeln(
    'Ignored local Serverpod secrets ready; existing keys preserved.',
  );
}

/// Preserves existing text and inserts only absent local keys. Refuses unusual
/// inline mode mappings rather than risk changing a user's credentials.
String addMissingLocalSecrets(String existing) {
  final random = Random.secure();
  String secret() =>
      base64UrlEncode(List<int>.generate(64, (_) => random.nextInt(256)));
  var result = existing.isEmpty
      ? '# Generated local secrets. Never commit or reuse in production.\n'
      : existing;
  const keys = [
    'database',
    'serviceSecret',
    'jwtHmacSha512PrivateKey',
    'jwtRefreshTokenHashPepper',
    'emailSecretHashPepper',
  ];
  RegExp header(String mode) =>
      RegExp('^(?:$mode|"$mode"|\'$mode\'):([^\\n]*)', multiLine: true);
  String? section(String text, String mode) {
    final matches = header(mode).allMatches(text).toList();
    if (matches.isEmpty) return null;
    if (matches.length != 1 ||
        !RegExp(r'^\s*(#.*)?$').hasMatch(matches.single.group(1)!)) {
      throw StateError(
        'Use a standard block mapping for local password modes.',
      );
    }
    final match = matches.single;
    final next = RegExp(
      r'^(?!#)\S[^\n]*:',
      multiLine: true,
    ).firstMatch(text.substring(match.end));
    final end = next == null ? text.length : match.end + next.start;
    return text.substring(match.end, end);
  }

  bool containsKey(String? block, String key) =>
      block != null &&
      RegExp(
        '^[ \\t]+(?:$key|"$key"|\'$key\'):',
        multiLine: true,
      ).hasMatch(block);
  final shared = section(result, 'shared');
  for (final mode in ['development', 'test']) {
    final block = section(result, mode);
    if (block != null &&
        RegExp(
          r'^(?: {3,}|\t)[^#\s][^\n]*:',
          multiLine: true,
        ).hasMatch(block)) {
      throw StateError('Use two-space indentation for local password keys.');
    }
    final additions = StringBuffer();
    for (final key in keys) {
      if (!containsKey(block, key) && !containsKey(shared, key)) {
        additions.writeln("  $key: '${secret()}'");
      }
    }
    if (additions.isEmpty) continue;
    if (block == null) {
      if (!result.endsWith('\n')) result += '\n';
      result += '$mode:\n$additions';
    } else {
      final start = header(mode).firstMatch(result)!.end;
      // Insert directly after the mode header; existing lines remain intact.
      result =
          '${result.substring(0, start)}\n$additions'
          '${result.substring(start).replaceFirst(RegExp(r'^\n'), '')}';
    }
  }
  return result;
}
