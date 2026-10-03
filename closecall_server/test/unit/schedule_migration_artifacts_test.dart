import 'dart:convert';
import 'dart:io';

import 'package:closecall_server/src/generated/protocol.dart';
import 'package:closecall_server/src/widget/widget_schedule_schema.dart';
import 'package:serverpod_database/serverpod_database.dart' as db;
import 'package:test/test.dart';

import '../../tool/schedule_migration_sql.dart';

void main() {
  const version = '20261004000100000';
  const directory = 'migrations/$version';
  test(
    'repair JSON describes five correctly ordered composite drop/add actions',
    () {
      final migration = db.DatabaseMigration.fromJson(
        jsonDecode(File('$directory/migration.json').readAsStringSync()),
      );
      expect(migration.actions, hasLength(2));
      var count = 0;
      for (final action in migration.actions) {
        final table = action.alterTable!;
        final canonical = scheduleForeignKeys(table.name);
        expect(
          table.deleteForeignKeys.toSet(),
          canonical.map((key) => key.constraintName).toSet(),
        );
        expect(
          table.addForeignKeys.map((key) => key.toJson()),
          canonical.map((key) => key.toJson()),
        );
        count += table.addForeignKeys.length;
      }
      expect(count, 5);
    },
  );
  test(
    'fresh and incremental snapshots preserve canonical FK and SQL CHECK invariants',
    () {
      final migration = db.DatabaseMigration.fromJson(
        jsonDecode(File('$directory/migration.json').readAsStringSync()),
      );
      for (final file in ['definition.json', 'definition_project.json']) {
        final definition = db.DatabaseDefinition.fromJson(
          jsonDecode(File('$directory/$file').readAsStringSync()),
        );
        for (final name in [
          'closecall_widget_schedule',
          'closecall_widget_fallback',
        ]) {
          final table = definition.tables.singleWhere(
            (table) => table.name == name,
          );
          for (final key in scheduleForeignKeys(name)) {
            expect(
              table.foreignKeys
                  .singleWhere((k) => k.constraintName == key.constraintName)
                  .toJson(),
              key.toJson(),
            );
          }
        }
        final rendered = scheduleMigrationSql(migration, definition);
        for (final action in migration.actions) {
          for (final key in action.alterTable!.addForeignKeys) {
            expect(
              rendered.contains(
                'DROP CONSTRAINT IF EXISTS "${key.constraintName}"',
              ),
              isTrue,
            );
            expect(
              rendered.contains('ADD CONSTRAINT "${key.constraintName}"'),
              isTrue,
            );
          }
        }
      }
      for (final file in ['migration.sql', 'definition.sql']) {
        final sql = File('$directory/$file').readAsStringSync();
        expect(
          sql.contains('CHECK ("senderMemberId" <> "recipientMemberId")'),
          isTrue,
        );
        expect(sql.contains("INTERVAL '7 days'"), isTrue);
        expect(sql.contains(version), isTrue);
      }
    },
  );
  test(
    'runtime schema verification retains same-couple keys after generation',
    () {
      // tool/generate.dart extends the pinned generator output automatically.
      // A bare CLI overwrite must fail until the wrapper is run, never silently
      // accept an under-constrained runtime target definition.
      final targets = Protocol().getTargetTableDefinitions();
      for (final name in [
        'closecall_widget_schedule',
        'closecall_widget_fallback',
      ]) {
        final table = targets.singleWhere((table) => table.name == name);
        for (final canonical in scheduleForeignKeys(name)) {
          final actual = table.foreignKeys.singleWhere(
            (key) => key.constraintName == canonical.constraintName,
          );
          expect(actual.columns.toSet(), canonical.columns.toSet());
          expect(
            actual.referenceColumns.toSet(),
            canonical.referenceColumns.toSet(),
          );
          expect(actual.referenceTable, canonical.referenceTable);
        }
      }
    },
  );
}
