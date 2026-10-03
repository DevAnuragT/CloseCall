import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../../scripts/bootstrap_serverpod.dart' as bootstrap;

String _secret() =>
    base64UrlEncode(List.generate(32, (_) => Random.secure().nextInt(256)));

void main() {
  test('bootstrap adds absent local secrets, preserves all existing keys', () {
    final shared = _secret();
    final retained = {
      for (final mode in ['development', 'test', 'production']) mode: _secret(),
    };
    final source =
        '# Keep comments\nshared:\n  serviceSecret: $shared\n'
        'development:\n  database: ${retained['development']}\n'
        'test:\n  database: ${retained['test']}\n'
        'production:\n  database: ${retained['production']}\n';
    final updated = bootstrap.addMissingLocalSecrets(source);
    final parsed = loadYaml(updated) as YamlMap;
    for (final mode in ['development', 'test']) {
      final values = parsed[mode] as YamlMap;
      expect(values['database'] == retained[mode], isTrue);
      expect(values.containsKey('serviceSecret'), isFalse);
      final pepper = values['emailSecretHashPepper'] as String;
      expect(base64Url.decode(pepper).length == 64, isTrue);
    }
    expect((parsed['production'] as YamlMap).length, 1);
    expect(updated.contains('# Keep comments'), isTrue);
    expect(bootstrap.addMissingLocalSecrets(updated) == updated, isTrue);
  });

  test(
    'bootstrap refuses inline mode mappings without altering credentials',
    () {
      expect(
        () => bootstrap.addMissingLocalSecrets('test: {}\n'),
        throwsStateError,
      );
    },
  );

  test(
    'on-disk bootstrap is repeatable and never emits credential values',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'closecall-bootstrap-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final config = Directory('${temp.path}/closecall_server/config')
        ..createSync(recursive: true);
      final file = File('${config.path}/passwords.yaml');
      final retained = _secret();
      file.writeAsStringSync('development:\n  database: $retained\n');
      final script = File('../scripts/bootstrap_serverpod.dart').absolute.path;
      final first = await Process.run(Platform.resolvedExecutable, [
        script,
      ], workingDirectory: temp.path);
      expect(first.exitCode, 0);
      expect(first.stdout.toString().contains(retained), isFalse);
      final initial = file.readAsStringSync();
      final parsed = loadYaml(initial) as YamlMap;
      expect(parsed.keys.toSet(), {'development', 'test'});
      expect(parsed['development']['database'] == retained, isTrue);
      final second = await Process.run(Platform.resolvedExecutable, [
        script,
      ], workingDirectory: temp.path);
      expect(second.exitCode, 0);
      expect(file.readAsStringSync() == initial, isTrue);
    },
  );

  test('quoted keys and top-level comments never hide existing secrets', () {
    final database = _secret();
    final pepper = _secret();
    final testPepper = _secret();
    final source =
        '"development":\n# Database: preserved\n  "database": $database\n'
        '  "emailSecretHashPepper": $pepper\n'
        'test:\n  emailSecretHashPepper: $testPepper\n';
    final updated =
        loadYaml(bootstrap.addMissingLocalSecrets(source)) as YamlMap;
    expect(updated['development']['database'] == database, isTrue);
    expect(updated['development']['emailSecretHashPepper'] == pepper, isTrue);
    expect(updated['test']['emailSecretHashPepper'] == testPepper, isTrue);
  });
}
