import 'dart:convert';
import 'dart:io';

import 'package:serverpod_database/serverpod_database.dart';

import 'schedule_migration_sql.dart';

/// Keeps the generated mood migration compatible with the repository's
/// SQL-only same-couple constraints. The Serverpod model generator cannot
/// represent those constraints and otherwise proposes dropping them.
void main() {
  const previous = '20261006224415374-widget-device-credentials';
  const version = '20261007041835495-live-mood';
  const directory = 'migrations/$version';
  const encoder = JsonEncoder.withIndent('  ');

  final migrationFile = File('$directory/migration.json');
  final migration = DatabaseMigration.fromJson(
    jsonDecode(migrationFile.readAsStringSync()),
  );
  final moodAction = migration.actions.firstWhere(
    (action) => action.alterTable?.name == 'closecall_couple_member',
  );
  final moodColumnNames = moodAction.alterTable!.addColumns
      .map((column) => column.name)
      .toSet();
  if (moodColumnNames.length != 2 ||
      !moodColumnNames.containsAll({'currentMood', 'moodUpdatedAt'})) {
    throw StateError('Unexpected mood migration columns.');
  }
  final extendedMigration = migration.copyWith(actions: [moodAction]);

  DatabaseDefinition? full;
  for (final filename in ['definition.json', 'definition_project.json']) {
    final old = DatabaseDefinition.fromJson(
      jsonDecode(File('migrations/$previous/$filename').readAsStringSync()),
    );
    final member = old.tables.singleWhere(
      (table) => table.name == 'closecall_couple_member',
    );
    final moodColumns = moodAction.alterTable!.addColumns;
    final updatedMember = member.copyWith(
      columns: [...member.columns, ...moodColumns],
    );
    final definition = old.copyWith(
      tables: [
        for (final table in old.tables)
          if (table.name == member.name) updatedMember else table,
      ],
    );
    File(
      '$directory/$filename',
    ).writeAsStringSync(encoder.convert(definition.toJson()));
    full ??= definition;
  }

  migrationFile.writeAsStringSync(encoder.convert(extendedMigration.toJson()));
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
  ).writeAsStringSync('BEGIN;\n\n$ddl\n\n$versionTail');

  final previousSql = File(
    'migrations/$previous/definition.sql',
  ).readAsStringSync().replaceAll(previous, version);
  File(
    '$directory/definition.sql',
  ).writeAsStringSync(previousSql.replaceFirst('COMMIT;', '$ddl\n\nCOMMIT;'));
  stdout.writeln('Mood migration extended; same-couple constraints preserved.');
}
