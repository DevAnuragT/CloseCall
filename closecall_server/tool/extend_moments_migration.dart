import 'dart:convert';
import 'dart:io';

import 'package:closecall_server/src/widget/widget_schedule_schema.dart';
import 'package:serverpod_database/serverpod_database.dart';

import 'schedule_migration_sql.dart';

/// Preserve every installed SQL-only FK/check while extending the pinned
/// generator's new Moments table. Existing migration artifacts are immutable.
void main() {
  const previous = '20261007041835495-live-mood';
  const version = '20261010204723852-moments';
  const directory = 'migrations/$version';
  const encoder = JsonEncoder.withIndent('  ');
  final migrationFile = File('$directory/migration.json');
  final migration = DatabaseMigration.fromJson(
    jsonDecode(migrationFile.readAsStringSync()),
  );
  final created = migration.actions.where((a) => a.createTable != null).single;
  if (created.createTable!.name != 'closecall_moment') {
    throw StateError('Unexpected table.');
  }
  for (final action in migration.actions.where((a) => a.alterTable != null)) {
    final table = action.alterTable!;
    if (table.addColumns.isNotEmpty ||
        table.deleteColumns.isNotEmpty ||
        table.modifyColumns.isNotEmpty ||
        table.addIndexes.isNotEmpty ||
        table.deleteIndexes.isNotEmpty ||
        table.addForeignKeys.isNotEmpty ||
        table.deleteForeignKeys.any((name) => !name.contains('same_couple'))) {
      throw StateError('Unexpected migration action; review before extending.');
    }
  }
  final moment = created.createTable!.copyWith(
    foreignKeys: [
      ...created.createTable!.foreignKeys.where(
        (key) => !momentForeignKeys().any(
          (k) => k.constraintName == key.constraintName,
        ),
      ),
      ...momentForeignKeys(),
    ],
  );
  final extended = migration.copyWith(
    actions: [created.copyWith(createTable: moment)],
  );
  DatabaseDefinition? full;
  for (final filename in ['definition.json', 'definition_project.json']) {
    final old = DatabaseDefinition.fromJson(
      jsonDecode(File('migrations/$previous/$filename').readAsStringSync()),
    );
    final definition = old.copyWith(tables: [...old.tables, moment]);
    File(
      '$directory/$filename',
    ).writeAsStringSync(encoder.convert(definition.toJson()));
    full ??= definition;
  }
  migrationFile.writeAsStringSync(encoder.convert(extended.toJson()));
  const checks = '''
ALTER TABLE "closecall_moment"
  ADD CONSTRAINT "closecall_moment_valid"
  CHECK (length("text") <= 1000
    AND length("authorId") > 0
    AND "requestId" ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\$'
    AND "contentHash" ~ '^[0-9a-f]{64}\$'
    AND (("deletedAt" IS NOT NULL AND "text" = '' AND "storagePath" IS NULL)
      OR ("deletedAt" IS NULL AND
        (("kind" = 'text' AND length(btrim("text")) > 0 AND "durationMs" IS NULL AND "storagePath" IS NULL)
         OR ("kind" = 'voice' AND "durationMs" IS NOT NULL AND "durationMs" BETWEEN 1 AND 30000 AND "storagePath" IS NOT NULL))))
    AND "kind" IN ('text', 'voice'));
''';
  final originalSql = File('$directory/migration.sql').readAsStringSync();
  final versionTail = originalSql.substring(
    originalSql.indexOf('-- MIGRATION VERSION FOR closecall'),
  );
  final ddl = scheduleMigrationSql(
    extended,
    full!,
  ).replaceFirst('BEGIN;', '').replaceFirst('COMMIT;', '').trim();
  File(
    '$directory/migration.sql',
  ).writeAsStringSync('BEGIN;\n\n$ddl\n\n$checks\n$versionTail');
  final previousSql = File(
    'migrations/$previous/definition.sql',
  ).readAsStringSync().replaceAll(previous, version);
  File('$directory/definition.sql').writeAsStringSync(
    previousSql.replaceFirst('COMMIT;', '$ddl\n\n$checks\nCOMMIT;'),
  );
  stdout.writeln(
    'Moments migration extended; prior FK/CHECK constraints preserved.',
  );
}
