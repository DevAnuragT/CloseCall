import 'dart:convert';
import 'dart:io';

import 'package:closecall_server/src/widget/widget_schedule_schema.dart';
import 'package:serverpod_database/serverpod_database.dart';

import 'schedule_migration_sql.dart';

const reminderEventPreviousVersion = '20261012083947841-reminders';
const reminderEventVersion = '20261014053004876-reminder-fcm';

const reminderEventChecks = r'''
ALTER TABLE "closecall_reminder_event_outbox"
  ADD CONSTRAINT "closecall_reminder_event_valid"
  CHECK ("eventType" = 'reminder_created'
    AND "attempts" >= 0
    AND "expiresAt" > "createdAt"
    AND (("leasedUntil" IS NULL AND "leaseOwner" IS NULL)
      OR ("leasedUntil" IS NOT NULL AND "leaseOwner" IS NOT NULL
        AND length(btrim("leaseOwner")) > 0)));
''';

void main(List<String> args) {
  if (args.any((arg) => arg != '--check')) {
    stderr.writeln(
      'Usage: dart run tool/extend_reminder_event_migration.dart [--check]',
    );
    exitCode = 64;
    return;
  }
  try {
    final artifacts = reminderEventMigrationArtifacts(Directory.current);
    final check = args.contains('--check');
    for (final entry in artifacts.entries) {
      final file = File(entry.key);
      if (check) {
        if (file.readAsStringSync() != entry.value) {
          throw StateError('Stale migration artifact: ${entry.key}');
        }
      } else {
        file.writeAsStringSync(entry.value);
      }
    }
    stdout.writeln(
      check
          ? 'Reminder event migration roundtrip verified.'
          : 'Reminder event migration extended; prior constraints preserved.',
    );
  } catch (error) {
    stderr.writeln('Reminder event migration extension failed: $error');
    exitCode = 1;
  }
}

Map<String, String> reminderEventMigrationArtifacts(Directory server) {
  final directory = '${server.path}/migrations/$reminderEventVersion';
  final previous = '${server.path}/migrations/$reminderEventPreviousVersion';
  const encoder = JsonEncoder.withIndent('  ');
  DatabaseDefinition definition(String path, String filename) =>
      DatabaseDefinition.fromJson(
        jsonDecode(File('$path/$filename').readAsStringSync()),
      );
  final prior = definition(previous, 'definition.json');
  final migration = DatabaseMigration.fromJson(
    jsonDecode(File('$directory/migration.json').readAsStringSync()),
  );
  final extended = extendReminderEventMigration(migration, prior);
  final created = extended.actions
      .where((action) => action.createTable != null)
      .map((action) => action.createTable!)
      .single;
  final result = <String, String>{};
  DatabaseDefinition? full;
  for (final filename in ['definition.json', 'definition_project.json']) {
    final old = definition(previous, filename);
    final next = old.copyWith(
      tables: [
        for (final table in old.tables)
          if (table.name == 'closecall_reminder')
            table.copyWith(indexes: [...table.indexes, reminderCoupleIndex()])
          else
            table,
        created,
      ],
    );
    result['$directory/$filename'] = encoder.convert(next.toJson());
    full ??= next;
  }
  result['$directory/migration.json'] = encoder.convert(extended.toJson());
  final originalSql = File('$directory/migration.sql').readAsStringSync();
  const marker = '-- MIGRATION VERSION FOR closecall';
  if (marker.allMatches(originalSql).length != 1 ||
      !originalSql.trimRight().endsWith('COMMIT;') ||
      !originalSql.contains(
        "VALUES ('closecall', '$reminderEventVersion', now())",
      )) {
    throw StateError('Unexpected migration version SQL.');
  }
  final versionTail = originalSql.substring(originalSql.indexOf(marker));
  final ddl = scheduleMigrationSql(
    extended,
    full!,
  ).replaceFirst('BEGIN;', '').replaceFirst('COMMIT;', '').trim();
  result['$directory/migration.sql'] =
      'BEGIN;\n\n$ddl\n\n$reminderEventChecks\n$versionTail';
  final previousSql = File('$previous/definition.sql')
      .readAsStringSync()
      .replaceAll(reminderEventPreviousVersion, reminderEventVersion);
  if ('COMMIT;'.allMatches(previousSql).length != 1) {
    throw StateError('Unexpected previous definition transaction.');
  }
  result['$directory/definition.sql'] = previousSql.replaceFirst(
    'COMMIT;',
    '$ddl\n\n$reminderEventChecks\nCOMMIT;',
  );
  return result;
}

DatabaseMigration extendReminderEventMigration(
  DatabaseMigration migration,
  DatabaseDefinition previous,
) {
  if (migration.warnings.isNotEmpty || migration.migrationApiVersion != 1) {
    throw StateError('Unexpected migration API or warnings.');
  }
  final creates = migration.actions
      .where((action) => action.createTable != null)
      .toList();
  if (creates.length != 1 ||
      creates.single.createTable!.name != 'closecall_reminder_event_outbox') {
    throw StateError('Expected exactly one reminder event outbox table.');
  }
  final priorByName = {for (final table in previous.tables) table.name: table};
  for (final action in migration.actions.where((a) => a.alterTable != null)) {
    final table = action.alterTable!;
    final prior = priorByName[table.name];
    if (prior == null ||
        table.addColumns.isNotEmpty ||
        table.deleteColumns.isNotEmpty ||
        table.modifyColumns.isNotEmpty ||
        table.addIndexes.any(
          (index) =>
              jsonEncode(index.toJson()) !=
              jsonEncode(reminderCoupleIndex().toJson()),
        ) ||
        table.addForeignKeys.isNotEmpty ||
        table.warnings.isNotEmpty ||
        table.addIndexes.length > 1 ||
        table.deleteIndexes.any(
          (name) => !prior.indexes.any(
            (index) =>
                index.indexName == name &&
                name == momentCoupleIndex().indexName,
          ),
        ) ||
        table.deleteForeignKeys.any(
          (name) => !prior.foreignKeys.any(
            (key) =>
                key.constraintName == name && name.contains('_same_couple_'),
          ),
        )) {
      throw StateError('Unexpected alteration of ${table.name}.');
    }
  }
  final table = creates.single.createTable!;
  if (table.schema != 'public' ||
      table.module != 'closecall' ||
      previous.tables.any((prior) => prior.name == table.name)) {
    throw StateError('Unexpected reminder event table definition.');
  }
  final keys = reminderEventForeignKeys();
  for (final key in keys) {
    if (!key.columns.every(
      (column) => table.columns.any((c) => c.name == column && !c.isNullable),
    )) {
      throw StateError('Unexpected composite FK columns.');
    }
  }
  return migration.copyWith(
    actions: [
      DatabaseMigrationAction(
        type: DatabaseMigrationActionType.alterTable,
        alterTable: TableMigration(
          name: 'closecall_reminder',
          schema: 'public',
          addColumns: [],
          deleteColumns: [],
          modifyColumns: [],
          addIndexes: [reminderCoupleIndex()],
          deleteIndexes: [],
          addForeignKeys: [],
          deleteForeignKeys: [],
          warnings: [],
        ),
      ),
      creates.single.copyWith(
        createTable: table.copyWith(
          foreignKeys: [
            ...table.foreignKeys.where(
              (key) => !keys.any(
                (extra) => extra.constraintName == key.constraintName,
              ),
            ),
            ...keys,
          ],
        ),
      ),
    ],
  );
}
