import 'dart:convert';
import 'dart:io';

import 'package:closecall_server/src/widget/widget_schedule_schema.dart';
import 'package:serverpod_database/serverpod_database.dart';

import 'schedule_migration_sql.dart';

/// Run after pinned `create-migration --tag widget-device-credentials`.
/// Extend only this new migration; retain all previously installed SQL-only
/// checks and composite constraints which the model DSL cannot represent.
void main() {
  const previous = '20261006120000000-fcm-outbox';
  const version = '20261006224415374-widget-device-credentials';
  const directory = 'migrations/$version';
  const encoder = JsonEncoder.withIndent('  ');
  final migrationFile = File('$directory/migration.json');
  final migration = DatabaseMigration.fromJson(
    jsonDecode(migrationFile.readAsStringSync()),
  );
  final created = migration.actions.where((a) => a.createTable != null).single;
  if (created.createTable!.name != 'closecall_widget_device_credential') {
    throw StateError('Unexpected new table.');
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
      throw StateError('Unexpected migration action. Review before extending.');
    }
  }
  final credentialTable = created.createTable!.copyWith(
    foreignKeys: [
      ...created.createTable!.foreignKeys.where(
        (key) => !widgetCredentialForeignKeys().any(
          (canonical) => canonical.constraintName == key.constraintName,
        ),
      ),
      ...widgetCredentialForeignKeys(),
    ],
  );
  final extendedMigration = migration.copyWith(
    actions: [created.copyWith(createTable: credentialTable)],
  );
  DatabaseDefinition? full;
  for (final filename in ['definition.json', 'definition_project.json']) {
    final old = DatabaseDefinition.fromJson(
      jsonDecode(File('migrations/$previous/$filename').readAsStringSync()),
    );
    final definition = old.copyWith(tables: [...old.tables, credentialTable]);
    File(
      '$directory/$filename',
    ).writeAsStringSync(encoder.convert(definition.toJson()));
    full ??= definition;
  }
  migrationFile.writeAsStringSync(encoder.convert(extendedMigration.toJson()));
  const checks = '''
ALTER TABLE "closecall_widget_device_credential"
  ADD CONSTRAINT "closecall_widget_credential_valid"
  CHECK ("credentialHash" ~ '^[0-9a-f]{64}\$'
    AND length("deviceId") BETWEEN 1 AND 128
    AND "deviceId" !~ '[[:space:][:cntrl:]]'
    AND length("userIdentifier") > 0
    AND "expiresAt" > "createdAt"
    AND "expiresAt" - "createdAt" <= INTERVAL '24 hours');
''';
  final originalSql = File('$directory/migration.sql').readAsStringSync();
  final versionTail = originalSql.substring(
    originalSql.indexOf('-- MIGRATION VERSION FOR closecall'),
  );
  final ddl = scheduleMigrationSql(
    extendedMigration,
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
    'Credential migration extended; existing FK/CHECK constraints preserved.',
  );
}
