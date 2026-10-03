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
  if (file.existsSync()) {
    stdout.writeln('Local Serverpod passwords already exist; kept unchanged.');
    return;
  }
  final random = Random.secure();
  String secret() =>
      base64UrlEncode(List<int>.generate(64, (_) => random.nextInt(256)));
  final content = StringBuffer(
    '# Generated local secrets. Never commit or reuse in production.\n',
  );
  for (final mode in ['development', 'test']) {
    content.writeln('$mode:');
    for (final key in [
      'database',
      'serviceSecret',
      'jwtHmacSha512PrivateKey',
      'jwtRefreshTokenHashPepper',
    ]) {
      content.writeln("  $key: '${secret()}'");
    }
  }
  // Create exclusively, so concurrent setup cannot truncate existing secrets.
  try {
    file.createSync(exclusive: true);
  } on FileSystemException {
    if (file.existsSync()) {
      stdout.writeln('Another setup created passwords; kept unchanged.');
      return;
    }
    rethrow;
  }
  if (!Platform.isWindows) {
    final result = Process.runSync('chmod', ['600', file.path]);
    if (result.exitCode != 0) {
      throw StateError('Cannot restrict permissions on local password file.');
    }
  }
  file.writeAsStringSync(content.toString(), flush: true);
  stdout.writeln('Created ignored local Serverpod passwords.');
}
