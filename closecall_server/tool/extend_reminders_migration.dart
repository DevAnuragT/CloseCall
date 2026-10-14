import 'dart:convert';
import 'dart:io';

import 'package:closecall_server/src/widget/widget_schedule_schema.dart';
import 'package:serverpod_database/serverpod_database.dart';

import 'schedule_migration_sql.dart';

const remindersPreviousVersion = '20261010204723852-moments';
const remindersVersion = '20261012083947841-reminders';

/// Serverpod cannot represent CHECKs or composite FKs in model YAML. Rebuild
/// only this pending migration, retaining the installed definition verbatim and
/// adding the two generated tables plus the composite Moments parent index.
/// Run from closecall_server; --check is read-only. Repeated runs are identical.
void main(List<String> args) {
  if (args.any((arg) => arg != '--check')) {
    stderr.writeln(
      'Usage: dart run tool/extend_reminders_migration.dart [--check]',
    );
    exitCode = 64;
    return;
  }
  try {
    final artifacts = remindersMigrationArtifacts(Directory.current);
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
          ? 'Reminders migration roundtrip verified.'
          : 'Reminders migration extended; prior FK/CHECK constraints preserved.',
    );
  } catch (error) {
    stderr.writeln('Reminders migration extension failed: $error');
    exitCode = 1;
  }
}

const remindersChecks = r'''
ALTER TABLE "closecall_reminder"
  ADD CONSTRAINT "closecall_reminder_valid"
  CHECK (length("creatorId") > 0
    AND length(btrim("title")) BETWEEN 1 AND 120
    AND "title" !~ '[[:cntrl:]]'
    AND "kind" IN ('call', 'dateNight', 'birthday', 'anniversary', 'event')
    AND "requestId" ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
ALTER TABLE "closecall_moment_event_outbox"
  ADD CONSTRAINT "closecall_moment_event_valid"
  CHECK ("eventType" = 'moment_created'
    AND "attempts" >= 0
    AND "expiresAt" > "createdAt"
    AND (("leasedUntil" IS NULL AND "leaseOwner" IS NULL)
      OR ("leasedUntil" IS NOT NULL AND "leaseOwner" IS NOT NULL
        AND length(btrim("leaseOwner")) > 0)));
''';

/// Compute every output before writing anything, failing closed on unexpected
/// generator actions (including unknown constraint drops or mixed payloads).
Map<String, String> remindersMigrationArtifacts(Directory server) {
  final directory = '${server.path}/migrations/$remindersVersion';
  final previous = '${server.path}/migrations/$remindersPreviousVersion';
  const encoder = JsonEncoder.withIndent('  ');
  DatabaseDefinition definition(String directory, String filename) =>
      DatabaseDefinition.fromJson(
        jsonDecode(File('$directory/$filename').readAsStringSync()),
      );
  final old = definition(previous, 'definition.json');
  final migration = DatabaseMigration.fromJson(
    jsonDecode(File('$directory/migration.json').readAsStringSync()),
  );
  final extended = extendRemindersMigration(migration, old);
  final created = extended.actions
      .where((action) => action.createTable != null)
      .map((action) => action.createTable!)
      .toList();
  final result = <String, String>{};
  DatabaseDefinition? full;
  for (final filename in ['definition.json', 'definition_project.json']) {
    final prior = definition(previous, filename);
    final next = prior.copyWith(
      tables: [
        for (final table in prior.tables)
          if (table.name == 'closecall_moment')
            table.copyWith(indexes: [...table.indexes, momentCoupleIndex()])
          else
            table,
        ...created,
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
        "VALUES ('closecall', '$remindersVersion', now())",
      )) {
    throw StateError('Unexpected migration version SQL.');
  }
  final versionTail = originalSql.substring(originalSql.indexOf(marker));
  final ddl = scheduleMigrationSql(
    extended,
    full!,
  ).replaceFirst('BEGIN;', '').replaceFirst('COMMIT;', '').trim();
  result['$directory/migration.sql'] =
      'BEGIN;\n\n$ddl\n\n$remindersChecks\n$versionTail';
  final previousSql = File(
    '$previous/definition.sql',
  ).readAsStringSync().replaceAll(remindersPreviousVersion, remindersVersion);
  if ('COMMIT;'.allMatches(previousSql).length != 1) {
    throw StateError('Unexpected previous definition transaction.');
  }
  result['$directory/definition.sql'] = previousSql.replaceFirst(
    'COMMIT;',
    '$ddl\n\n$remindersChecks\nCOMMIT;',
  );
  return result;
}

DatabaseMigration extendRemindersMigration(
  DatabaseMigration migration,
  DatabaseDefinition previous,
) {
  if (migration.warnings.isNotEmpty || migration.migrationApiVersion != 1) {
    throw StateError('Unexpected migration API or warnings.');
  }
  final newKeys = {
    'closecall_moment_event_outbox': momentEventForeignKeys(),
    'closecall_reminder': reminderForeignKeys(),
  };
  final hasPendingDrops = migration.actions.any(
    (action) => action.alterTable?.deleteForeignKeys.isNotEmpty == true,
  );
  if (!hasPendingDrops) {
    final alterActions = migration.actions
        .where((action) => action.alterTable != null)
        .toList();
    final createActions = migration.actions
        .where((action) => action.createTable != null)
        .toList();
    if (alterActions.length != 1 ||
        createActions.length != newKeys.length ||
        alterActions.single.alterTable!.name != 'closecall_moment' ||
        alterActions.single.alterTable!.addIndexes.length != 1 ||
        jsonEncode(
              alterActions.single.alterTable!.addIndexes.single.toJson(),
            ) !=
            jsonEncode(momentCoupleIndex().toJson()) ||
        alterActions.single.alterTable!.deleteIndexes.isNotEmpty ||
        alterActions.single.alterTable!.addForeignKeys.isNotEmpty ||
        alterActions.single.alterTable!.deleteForeignKeys.isNotEmpty ||
        createActions.any((action) {
          final table = action.createTable!;
          final keys = newKeys[table.name];
          return keys == null ||
              keys.any(
                (key) =>
                    table.foreignKeys
                        .where(
                          (foreignKey) =>
                              foreignKey.constraintName == key.constraintName,
                        )
                        .length !=
                    1,
              );
        })) {
      throw StateError('Unexpected already-extended migration.');
    }
    return migration;
  }
  final created = <String, DatabaseMigrationAction>{};
  final altered = <String>{};
  for (final action in migration.actions) {
    if (action.type == DatabaseMigrationActionType.createTable &&
        action.createTable != null &&
        action.alterTable == null &&
        action.deleteTable == null) {
      final table = action.createTable!;
      final keys = newKeys[table.name];
      if (keys == null ||
          table.schema != 'public' ||
          table.module != 'closecall' ||
          created.containsKey(table.name) ||
          previous.tables.any((prior) => prior.name == table.name)) {
        throw StateError('Unexpected new table ${table.name}.');
      }
      for (final key in keys) {
        if (!key.columns.every(
          (column) =>
              table.columns.any((c) => c.name == column && !c.isNullable),
        )) {
          throw StateError('Unexpected composite FK columns on ${table.name}.');
        }
        final existing = table.foreignKeys.where(
          (fk) => fk.constraintName == key.constraintName,
        );
        if (existing.length > 1 ||
            existing.any(
              (fk) => jsonEncode(fk.toJson()) != jsonEncode(key.toJson()),
            )) {
          throw StateError('Conflicting composite FK ${key.constraintName}.');
        }
      }
      created[table.name] = action.copyWith(
        createTable: table.copyWith(
          foreignKeys: [
            ...table.foreignKeys.where(
              (fk) =>
                  !keys.any((key) => key.constraintName == fk.constraintName),
            ),
            ...keys,
          ],
        ),
      );
      continue;
    }
    if (action.type != DatabaseMigrationActionType.alterTable ||
        action.alterTable == null ||
        action.createTable != null ||
        action.deleteTable != null) {
      throw StateError('Unexpected migration action; review before extending.');
    }
    final table = action.alterTable!;
    final prior = previous.tables.where((prior) => prior.name == table.name);
    if (!altered.add(table.name) || table.deleteForeignKeys.isEmpty) {
      throw StateError('Unexpected alteration of ${table.name}.');
    }
    if (prior.length != 1 ||
        table.schema != prior.single.schema ||
        table.addColumns.isNotEmpty ||
        table.deleteColumns.isNotEmpty ||
        table.modifyColumns.isNotEmpty ||
        table.deleteIndexes.isNotEmpty ||
        table.addForeignKeys.isNotEmpty ||
        table.warnings.isNotEmpty ||
        table.addIndexes.any(
          (index) =>
              table.name != 'closecall_moment' ||
              jsonEncode(index.toJson()) !=
                  jsonEncode(momentCoupleIndex().toJson()),
        ) ||
        table.addIndexes.length > 1 ||
        table.deleteForeignKeys.any(
          (name) => !prior.single.foreignKeys.any(
            (key) =>
                key.constraintName == name && name.contains('_same_couple_'),
          ),
        )) {
      throw StateError('Unexpected alteration of ${table.name}.');
    }
  }
  if (created.length != newKeys.length) {
    throw StateError(
        'Expected exactly the Reminder and MomentEventOutbox tables.',
    );
  }
  final expectedAltered = {
    for (final table in previous.tables)
      if (table.foreignKeys.any(
        (key) => key.constraintName.contains('_same_couple_'),
      ))
        table.name,
  };
  if (!setEquals(altered, expectedAltered)) {
    throw StateError('Unexpected set of altered tables.');
  }
  final moment = previous.tables.singleWhere(
    (t) => t.name == 'closecall_moment',
  );
  if (moment.indexes.any((i) => i.indexName == momentCoupleIndex().indexName)) {
    throw StateError(
      'Parent index already exists in installed Moments migration.',
    );
  }
  return migration.copyWith(
    actions: [
      DatabaseMigrationAction(
        type: DatabaseMigrationActionType.alterTable,
        alterTable: TableMigration(
          name: moment.name,
          schema: moment.schema,
          addColumns: [],
          deleteColumns: [],
          modifyColumns: [],
          addIndexes: [momentCoupleIndex()],
          deleteIndexes: [],
          addForeignKeys: [],
          deleteForeignKeys: [],
          warnings: [],
        ),
      ),
      for (final name in newKeys.keys) created[name]!,
    ],
  );
}

bool setEquals<T>(Set<T> first, Set<T> second) =>
    first.length == second.length && first.containsAll(second);
