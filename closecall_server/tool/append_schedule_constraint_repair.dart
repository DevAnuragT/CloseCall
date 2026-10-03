import 'dart:convert';
import 'dart:io';

import 'package:closecall_server/src/widget/widget_schedule_schema.dart';

/// Builds ONLY the new, reviewed repair artifacts. Never alters an installed
/// migration. The official action model has no custom-SQL/check action; CHECKs
/// therefore live in SQL, while composite FKs are also modeled in JSON.
void main() {
  const old = '20261003161232234';
  const version = '20261004000100000';
  final destination = Directory('migrations/$version');
  if (destination.existsSync()) {
    throw StateError('Repair artifacts already exist.');
  }
  destination.createSync();
  const encoder = JsonEncoder.withIndent('  ');
  const tables = ['closecall_widget_schedule', 'closecall_widget_fallback'];
  final actions = <Map<String, dynamic>>[];
  final sql = StringBuffer(
    'BEGIN;\n\n-- Idempotent, versioned same-couple invariant repair.\n',
  );
  for (final table in tables) {
    final keys = scheduleForeignKeys(table);
    actions.add({
      '__className__': 'serverpod.DatabaseMigrationAction',
      'type': 'alterTable',
      'alterTable': {
        '__className__': 'serverpod.TableMigration',
        'name': table,
        'schema': 'public',
        'addColumns': [],
        'deleteColumns': [],
        'modifyColumns': [],
        'addIndexes': [],
        'deleteIndexes': [],
        'warnings': [],
        'deleteForeignKeys': keys.map((k) => k.constraintName).toList(),
        'addForeignKeys': keys.map((k) => k.toJson()).toList(),
      },
    });
    for (final key in keys) {
      sql.writeln(
        'ALTER TABLE "$table" DROP CONSTRAINT IF EXISTS "${key.constraintName}";',
      );
    }
    for (final key in keys) {
      final columns = key.columns.map((c) => '"$c"').join(', ');
      sql.writeln(
        'ALTER TABLE "$table" ADD CONSTRAINT "${key.constraintName}" '
        'FOREIGN KEY ($columns) REFERENCES "${key.referenceTable}" ("coupleId", "id") '
        'ON DELETE CASCADE ON UPDATE NO ACTION;',
      );
    }
  }
  const checks = '''
ALTER TABLE "closecall_widget_schedule" DROP CONSTRAINT IF EXISTS "closecall_widget_schedule_distinct_members";
ALTER TABLE "closecall_widget_schedule" DROP CONSTRAINT IF EXISTS "closecall_widget_schedule_valid_window";
ALTER TABLE "closecall_widget_schedule"
  ADD CONSTRAINT "closecall_widget_schedule_distinct_members" CHECK ("senderMemberId" <> "recipientMemberId"),
  ADD CONSTRAINT "closecall_widget_schedule_valid_window" CHECK ("activeUntil" > "activeFrom" AND "activeUntil" - "activeFrom" <= INTERVAL '7 days');
''';
  sql.write(checks);
  sql.writeln(
    "INSERT INTO serverpod_migrations (module, version, timestamp) VALUES ('closecall', '$version', now()) "
    "ON CONFLICT (module) DO UPDATE SET version = '$version', timestamp = now();\nCOMMIT;",
  );
  File('${destination.path}/migration.sql').writeAsStringSync(sql.toString());
  File('${destination.path}/migration.json').writeAsStringSync(
    encoder.convert({
      '__className__': 'serverpod.DatabaseMigration',
      'actions': actions,
      'warnings': [],
      'migrationApiVersion': 1,
    }),
  );
  for (final file in ['definition.json', 'definition_project.json']) {
    final definition =
        jsonDecode(File('migrations/$old/$file').readAsStringSync())
            as Map<String, dynamic>;
    for (final table in definition['tables'] as List) {
      if (tables.contains(table['name'])) {
        final keys = scheduleForeignKeys(table['name'] as String);
        final foreign = table['foreignKeys'] as List;
        foreign.removeWhere(
          (key) => keys.any((k) => k.constraintName == key['constraintName']),
        );
        foreign.addAll(keys.map((key) => key.toJson()));
      }
    }
    File(
      '${destination.path}/$file',
    ).writeAsStringSync(encoder.convert(definition));
  }
  final base = File(
    'migrations/$old/definition.sql',
  ).readAsStringSync().replaceAll(old, version);
  // Fresh installs need the same FK/check SQL, not only the incremental actions.
  final constraintSql = sql
      .toString()
      .split("INSERT INTO serverpod_migrations")
      .first
      .replaceFirst('BEGIN;\n', '');
  File(
    '${destination.path}/definition.sql',
  ).writeAsStringSync(base.replaceFirst('COMMIT;', '$constraintSql\nCOMMIT;'));
  final registry = File('migrations/migration_registry.txt');
  if (!registry.readAsStringSync().split('\n').contains(version)) {
    registry.writeAsStringSync('$version\n', mode: FileMode.append);
  }
  stdout.writeln(
    'Appended constraint repair $version. Previous migrations unchanged.',
  );
}
