// Offline checks of the exact Cloud CLI 1.0.1 preparation/ZIP behavior.
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:serverpod_cloud_cli/command_logger/command_logger.dart';
import 'package:serverpod_cloud_cli/command_runner/commands/deploy/prepare_project_files.dart';
import 'package:serverpod_cloud_cli/project_zipper/project_zipper.dart';
import 'package:serverpod_cloud_cli/util/pubspec_validator.dart';

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main(List<String> args) async {
  final root = Directory(args.single);
  final server = Directory('${root.path}/closecall_server');
  final validator = TenantProjectPubspec.fromProjectDir(server);
  require(
    validator.projectDependencyIssues().isEmpty,
    'Cloud pubspec validation',
  );
  final preparer = TenantProject.prepare(
    server,
    tenantProjectPubspec: validator,
  );
  require(preparer.isWorkspace, 'Expected the deployment-only workspace');
  require(
    preparer.includedPackagePaths.toSet().containsAll([
      'closecall_server',
      'closecall_shared',
    ]),
    'Shared path dependency was omitted',
  );

  // Poison runtime directories after preparation. Exact ZIP allowlisting must
  // reject new files and logs regardless of location or suffix.
  final poisonPaths = [
    'closecall_server/lib/new_unreviewed.dart',
    'closecall_shared/lib/private_credentials.dart',
    'closecall_server/config/passwords.yaml',
    'closecall_server/config/production.yaml',
    'closecall_server/.env',
    'closecall_server/lib/src/generated/runtime.log',
  ];
  for (final path in poisonPaths) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('EXCLUSION TEST; NOT A REAL SECRET');
  }
  final bytes = await ProjectZipper.zipProject(
    logger: CommandLogger.create(),
    rootDirectory: preparer.rootDirectory,
    beneath: preparer.includedSubPaths,
    fileContentModifier: (path, read) async {
      if (path.endsWith('/pubspec.yaml') || path == 'pubspec.yaml') {
        return preparer.filterPubspecYaml(await read());
      }
      if (path == 'pubspec.lock') {
        return preparer.filterPubspecLock(await read());
      }
      return null;
    },
  );
  final names = ZipDecoder()
      .decodeBytes(bytes)
      .files
      .map((f) => f.name)
      .toSet();
  require(
    names.contains('.scloud/scloud_server_dir'),
    'Cloud server-dir metadata omitted',
  );
  require(
    names.contains('closecall_server/bin/main.dart'),
    'Server entrypoint omitted',
  );
  require(
    names.contains('closecall_server/lib/src/generated/protocol.yaml'),
    'Generated protocol omitted',
  );
  require(
    names.any((name) => name.startsWith('closecall_shared/lib/')),
    'Shared runtime omitted',
  );
  require(
    names.any((name) => name.endsWith('/migration_registry.txt')),
    'Migrations omitted',
  );
  for (final name in names) {
    require(
      !poisonPaths.contains(name),
      'Excluded file leaked into archive: $name',
    );
    require(
      !name.contains('/config/'),
      'Local config leaked into archive: $name',
    );
    require(
      !name.contains('.dart_tool') && !name.contains('.deploy-manifest'),
      'Local metadata leaked: $name',
    );
    require(
      name == 'pubspec.yaml' ||
          name == 'pubspec.lock' ||
          name == '.scloud/scloud_server_dir' ||
          name.startsWith('closecall_server/') ||
          name.startsWith('closecall_shared/lib/') ||
          name == 'closecall_shared/pubspec.yaml',
      'Non-runtime archive entry: $name',
    );
  }
  stdout.writeln(
    'Cloud CLI offline archive checks passed (${names.length} entries).',
  );
}
