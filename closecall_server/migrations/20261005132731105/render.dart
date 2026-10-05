// Run from closecall_server with the pinned Dart SDK after create-migration.
// Preserve composite constraints unsupported by Serverpod's model DSL.
import 'dart:convert';
import 'dart:io';

import 'package:serverpod_cli/src/database/dialects/postgres.dart';
import 'package:serverpod_database/serverpod_database.dart';

import 'package:closecall_server/src/widget/widget_schedule_schema.dart';

const root = 'migrations/20261005132731105';

void main() {
  final encoder = const JsonEncoder.withIndent('  ');
  final definitions = <DatabaseDefinition>[];
  for (final name in ['definition.json', 'definition_project.json']) {
    final file = File('$root/$name');
    final definition = DatabaseDefinition.fromJson(
      jsonDecode(file.readAsStringSync()),
    );
    for (final table in definition.tables.where(
      (t) => t.name.startsWith('closecall_widget_'),
    )) {
      final keys = scheduleForeignKeys(table.name);
      table.foreignKeys.removeWhere(
        (k) => k.constraintName.contains('_same_couple_'),
      );
      table.foreignKeys.addAll(keys);
    }
    file.writeAsStringSync('${encoder.convert(definition.toJson())}\n');
    definitions.add(definition);
  }
  final migrationFile = File('$root/migration.json');
  final migration = DatabaseMigration.fromJson(
    jsonDecode(migrationFile.readAsStringSync()),
  );
  for (final action in migration.actions) {
    final table = action.createTable;
    if (table == null) continue;
    table.foreignKeys.removeWhere(
      (k) => k.constraintName.contains('_same_couple_'),
    );
    table.foreignKeys.addAll(scheduleForeignKeys(table.name));
  }
  migrationFile.writeAsStringSync('${encoder.convert(migration.toJson())}\n');
  const deliveryChecks = '''ALTER TABLE "closecall_widget_delivery"
  ADD CONSTRAINT "closecall_widget_delivery_valid" CHECK ("version" >= 0 AND (("version" = 0 AND "assetId" IS NULL AND "senderMemberId" IS NULL AND "sentAt" IS NULL) OR ("version" > 0 AND "assetId" IS NOT NULL AND "senderMemberId" IS NOT NULL AND "sentAt" IS NOT NULL AND "senderMemberId" <> "recipientMemberId")));
ALTER TABLE "closecall_widget_send"
  ADD CONSTRAINT "closecall_widget_send_valid" CHECK ("version" > 0 AND "senderMemberId" <> "recipientMemberId" AND "requestId" ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\$');
''';
  final installed =
      (jsonDecode(File('$root/definition.json').readAsStringSync())
              as Map)['installedModules']
          as List;
  final modules = installed
      .map((v) => DatabaseMigrationVersionModel.fromJson(v))
      .toList();
  var sql = PostgresSqlGenerator().generateDatabaseMigrationSql(
    migration,
    definitions.first,
    installedModules: modules,
    removedModules: [],
  );
  for (final action in migration.actions) {
    for (final key in action.createTable!.foreignKeys.where(
      (k) => k.columns.length > 1,
    )) {
      sql = sql.replaceAll(
        'FOREIGN KEY("${key.columns.join(', ')}")',
        'FOREIGN KEY(${key.columns.map((c) => '"$c"').join(', ')})',
      );
    }
  }
  File(
    '$root/migration.sql',
  ).writeAsStringSync(sql.replaceFirst('COMMIT;', '${deliveryChecks}COMMIT;'));
  var fresh = PostgresSqlGenerator().generateDatabaseDefinitionSql(
    definitions.first,
    installedModules: modules,
  );
  for (final table in definitions.first.tables) {
    for (final key in table.foreignKeys.where((k) => k.columns.length > 1)) {
      fresh = fresh.replaceAll(
        'FOREIGN KEY("${key.columns.join(', ')}")',
        'FOREIGN KEY(${key.columns.map((c) => '"$c"').join(', ')})',
      );
    }
  }
  fresh = fresh.replaceFirst(
    'COMMIT;',
    '''ALTER TABLE "closecall_widget_schedule"
  ADD CONSTRAINT "closecall_widget_schedule_distinct_members" CHECK ("senderMemberId" <> "recipientMemberId"),
  ADD CONSTRAINT "closecall_widget_schedule_valid_window" CHECK ("activeUntil" > "activeFrom" AND "activeUntil" - "activeFrom" <= INTERVAL '7 days');
$deliveryChecks
COMMIT;''',
  );
  File('$root/definition.sql').writeAsStringSync(fresh);
}
