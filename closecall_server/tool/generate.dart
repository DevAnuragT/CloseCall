import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_style/dart_style.dart';
import 'package:yaml/yaml.dart';

/// Reproducible Serverpod 4.0.3 generation, followed by narrow AST extensions
/// for composite-FK schema verification and Moments' default page size.
/// Run from closecall_server:
///   ../.tooling/flutter/bin/dart run tool/generate.dart
/// CI (read-only drift check, followed by the usual analyze/tests):
///   ../.tooling/flutter/bin/dart run tool/generate.dart --check
///
/// The upstream Protocol constructor is factory/private, preventing an external
/// subclass; generated withServerpod has no serialization-manager override.
/// Extending its generated target getter binds production and test harness to
/// the SAME non-generated schema function. No handwritten generated patch is
/// required. This wrapper never reads passwords or copies private runtime data,
/// never changes the host CLI, and writes only server/test-tools/typed-client
/// generation outputs.
Future<void> main(List<String> args) async {
  if (args.any((arg) => arg != '--check')) {
    stderr.writeln('Usage: dart run tool/generate.dart [--check]');
    exitCode = 64;
    return;
  }
  try {
    final changed = await generateServer(
      Directory.current,
      check: args.contains('--check'),
    );
    if (args.contains('--check') && changed.isNotEmpty) {
      stderr.writeln(
        'Generated server files are stale. Run dart run tool/generate.dart.',
      );
      for (final file in changed) {
        stderr.writeln('  $file');
      }
      exitCode = 1;
      return;
    }
    stdout.writeln(
      args.contains('--check')
          ? 'Server generation roundtrip verified.'
          : 'Server generated with structured schedule schema extension.',
    );
  } catch (error) {
    stderr.writeln('Server generation failed: $error');
    exitCode = 1;
  }
}

/// CLI runs in disposable staging, so --check does not alter checked-in output
/// and normal generation cannot modify the client or private server config.
Future<List<String>> generateServer(
  Directory server, {
  required bool check,
}) async {
  server = server.absolute;
  final config = File('${server.path}/config/generator.yaml');
  final packages = File('${server.path}/.dart_tool/package_config.json');
  if (!config.existsSync() || !packages.existsSync()) {
    throw StateError('Run from closecall_server after dart pub get.');
  }
  final cache = Directory('${server.parent.path}/.tooling/pub-cache');
  if (!cache.existsSync()) {
    throw StateError('Repository-local CLI cache is required.');
  }
  final scratchRoot = Directory('${server.path}/.serverpod')
    ..createSync(recursive: true);
  final scratch = scratchRoot.createTempSync('generate-');
  try {
    final staged = Directory('${scratch.path}/closecall_server')..createSync();
    _copyDirectory(
      Directory('${server.path}/lib'),
      Directory('${staged.path}/lib'),
    );
    // Start generation from source, not from a copied patched protocol. This
    // prevents a skipped/stale generator write from passing the roundtrip.
    final previousOutput = Directory('${staged.path}/lib/src/generated');
    if (previousOutput.existsSync()) previousOutput.deleteSync(recursive: true);
    // Only nonsecret generation inputs. The CLI must never see passwords.yaml.
    for (final name in [
      'pubspec.yaml',
      'pubspec.lock',
      'analysis_options.yaml',
    ]) {
      final source = File('${server.path}/$name');
      if (source.existsSync()) source.copySync('${staged.path}/$name');
    }
    Directory('${staged.path}/config').createSync();
    final settings = Map<String, dynamic>.from(
      loadYaml(config.readAsStringSync()) as Map,
    );
    if (settings['type'] != 'server') {
      throw StateError('Expected server generator config.');
    }
    // Force BOTH output roots inside owned scratch even if configured paths
    // later change. JSON is valid YAML; preserve all other generation settings.
    settings['client_package_path'] = '../closecall_client';
    settings['server_test_tools_path'] = 'test/integration/test_tools';
    File(
      '${staged.path}/config/generator.yaml',
    ).writeAsStringSync(jsonEncode(settings));
    final client = Directory('${scratch.path}/closecall_client')..createSync();
    File('${client.path}/pubspec.yaml').writeAsStringSync('''
name: closecall_client
environment:
  sdk: ^3.12.2
dependencies:
  serverpod_client: 4.0.3
  serverpod_auth_core_client: 4.0.3
  serverpod_auth_idp_client: 4.0.3
''');
    // Rebase relative package roots; retain this stage as the server package,
    // use already-resolved dependencies read-only. No network/pub upgrade.
    final packageConfig =
        jsonDecode(packages.readAsStringSync()) as Map<String, dynamic>;
    for (final entry in packageConfig['packages'] as List) {
      entry['rootUri'] = entry['name'] == 'closecall_server'
          ? staged.uri.toString()
          : packages.uri.resolve(entry['rootUri'] as String).toString();
    }
    Directory('${staged.path}/.dart_tool').createSync();
    File(
      '${staged.path}/.dart_tool/package_config.json',
    ).writeAsStringSync(jsonEncode(packageConfig));
    final environment = {
      'PUB_CACHE': cache.absolute.path,
      'PATH':
          '${File(Platform.resolvedExecutable).parent.path}${Platform.isWindows ? ';' : ':'}${Platform.environment['PATH'] ?? ''}',
    };
    final version = await Process.run(
      Platform.resolvedExecutable,
      ['pub', 'global', 'run', 'serverpod_cli:serverpod_cli', '--version'],
      workingDirectory: staged.path,
      environment: environment,
    );
    if (version.exitCode != 0 ||
        !RegExp(r'\b4\.0\.3\b').hasMatch(version.stdout.toString())) {
      throw StateError('Repository-local Serverpod CLI 4.0.3 is required.');
    }
    final generated = await Process.run(
      Platform.resolvedExecutable,
      [
        'pub',
        'global',
        'run',
        'serverpod_cli:serverpod_cli',
        '--no-analytics',
        '--no-interactive',
        'generate',
        '--force',
        '--directory',
        staged.path,
      ],
      workingDirectory: staged.path,
      environment: environment,
    );
    if (generated.exitCode != 0) {
      throw StateError(
        'Pinned CLI generation failed (exit ${generated.exitCode}).\n'
        '${generated.stdout}\n${generated.stderr}',
      );
    }
    final protocol = File('${staged.path}/lib/src/generated/protocol.dart');
    protocol.writeAsStringSync(
      extendScheduleProtocol(protocol.readAsStringSync()),
    );
    for (final path in [
      '${client.path}/lib/src/protocol/client.dart',
      '${staged.path}/test/integration/test_tools/serverpod_test_tools.dart',
    ]) {
      final file = File(path);
      file.writeAsStringSync(extendMomentDefaults(file.readAsStringSync()));
    }
    final changes = <String>[];
    for (final directory in [
      'lib/src/generated',
      'test/integration/test_tools',
      // The pinned CLI generates the typed client beside the server. Copy it
      // through the same scratch boundary so server/client protocol drift is
      // caught by --check rather than relying on a hand-edited client.
      '../closecall_client/lib/src/protocol',
    ]) {
      final source = Directory('${staged.path}/$directory');
      if (!source.existsSync()) {
        throw StateError('Missing generated output $directory.');
      }
      final files = source.listSync(recursive: true).whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        final relative = file.path.substring(staged.path.length + 1);
        final target = File('${server.path}/$relative');
        final contents = file.readAsBytesSync();
        if (!target.existsSync() ||
            !_same(contents, target.readAsBytesSync())) {
          changes.add(relative);
          if (!check) {
            target.parent.createSync(recursive: true);
            target.writeAsBytesSync(contents);
          }
        }
      }
    }
    return changes;
  } finally {
    scratch.deleteSync(
      recursive: true,
    ); // Only this invocation's owned scratch.
  }
}

/// Fail closed if the pinned generated shape changes. Only the Protocol target
/// getter and its schema import/annotation are transformed; RPCs/serializers are
/// untouched. Idempotence also makes stale generated input safe to regenerate.
String extendScheduleProtocol(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: true).unit;
  final protocol = unit.declarations
      .whereType<ClassDeclaration>()
      .where(
        (declaration) => declaration.namePart.typeName.lexeme == 'Protocol',
      )
      .single;
  final getter = (protocol.body as BlockClassBody).members
      .whereType<MethodDeclaration>()
      .where((member) => member.name.lexeme == 'getTargetTableDefinitions')
      .single;
  final body = getter.body;
  if (body is! ExpressionFunctionBody ||
      getter.parameters?.parameters.isNotEmpty == true) {
    throw StateError('Unexpected generated Protocol schema getter.');
  }
  final expression = body.expression;
  final raw = source.substring(expression.offset, expression.end);
  if (raw != 'targetTableDefinitions' &&
      raw != 'withScheduleConstraints(targetTableDefinitions)') {
    throw StateError('Unexpected generated schema getter expression.');
  }
  final edits = <_Edit>[
    _Edit(
      expression.offset,
      expression.end,
      'withScheduleConstraints(targetTableDefinitions)',
    ),
  ];
  const uri = '../widget/widget_schedule_schema.dart';
  if (!unit.directives.whereType<ImportDirective>().any(
    (directive) => directive.uri.stringValue == uri,
  )) {
    final at = unit.directives.first.offset;
    edits.add(_Edit(at, at, "import '$uri';\n"));
  }
  const annotation =
      '// Schema extension generated by tool/generate.dart; do not patch by hand.\n';
  if (!source.contains(annotation)) {
    final at = source.indexOf('\n', source.indexOf('/*   To generate')) + 1;
    if (at == 0) throw StateError('Missing generated source annotation.');
    edits.add(_Edit(at, at, annotation));
  }
  edits.sort((a, b) => b.start.compareTo(a.start));
  for (final edit in edits) {
    source = source.replaceRange(edit.start, edit.end, edit.text);
  }
  return DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format(source);
}

class _Edit {
  _Edit(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

/// Serverpod 4.0.3 makes nonnullable optional endpoint parameters required in
/// generated callers. Restore the Moments contract's default through its AST;
/// every RPC continues sending an explicit integer over the wire.
String extendMomentDefaults(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: true).unit;
  final methods = unit.declarations
      .whereType<ClassDeclaration>()
      .expand(
        (c) =>
            (c.body as BlockClassBody).members.whereType<MethodDeclaration>(),
      )
      .where((m) => m.name.lexeme == 'listMoments');
  final method = methods.single;
  final parameter = method.parameters!.parameters
      .where((p) => RegExp(r'\blimit\b').hasMatch(p.toSource()))
      .single;
  final shape = parameter.toSource().replaceAll(RegExp(r'\s+'), ' ');
  if (shape != 'required int limit' && shape != 'int limit = 20') {
    throw StateError('Unexpected generated Moments limit parameter.');
  }
  source = source.replaceRange(
    parameter.offset,
    parameter.end,
    'int limit = 20',
  );
  return DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format(source);
}

void _copyDirectory(Directory source, Directory target) {
  target.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final name = entity.uri.pathSegments.where((part) => part.isNotEmpty).last;
    if (entity is File) entity.copySync('${target.path}/$name');
    if (entity is Directory) {
      _copyDirectory(entity, Directory('${target.path}/$name'));
    }
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
