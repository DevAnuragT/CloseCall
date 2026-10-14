import 'dart:convert';
import 'dart:io';

import 'package:closecall_server/src/widget/widget_schedule_schema.dart';
import 'package:serverpod_database/serverpod_database.dart' as db;
import 'package:test/test.dart';

import '../../tool/extend_reminders_migration.dart';

void main() {
  const prior = 'migrations/20261010204723852-moments';
  const current = 'migrations/20261012083947841-reminders';

  test('Reminders migration retains prior artifacts and adds invariants', () {
    final old = db.DatabaseDefinition.fromJson(
      jsonDecode(File('$prior/definition.json').readAsStringSync()),
    );
    final definition = db.DatabaseDefinition.fromJson(
      jsonDecode(File('$current/definition.json').readAsStringSync()),
    );
    for (final table in old.tables) {
      final actual = definition.tables.singleWhere((t) => t.name == table.name);
      if (table.name == 'closecall_moment') {
        expect(
          actual
              .copyWith(
                indexes: [
                  for (final index in actual.indexes)
                    if (index.indexName != momentCoupleIndex().indexName) index,
                ],
              )
              .toJson(),
          table.toJson(),
        );
      } else {
        expect(actual.toJson(), table.toJson());
      }
    }
    final moment = definition.tables.singleWhere(
      (table) => table.name == 'closecall_moment',
    );
    expect(
      moment.indexes.any(
        (index) =>
            jsonEncode(index.toJson()) ==
            jsonEncode(momentCoupleIndex().toJson()),
      ),
      isTrue,
    );
    final outbox = definition.tables.singleWhere(
      (table) => table.name == 'closecall_moment_event_outbox',
    );
    final reminder = definition.tables.singleWhere(
      (table) => table.name == 'closecall_reminder',
    );
    expect(
      outbox.foreignKeys.map((key) => key.constraintName),
      containsAll(momentEventForeignKeys().map((key) => key.constraintName)),
    );
    expect(
      reminder.foreignKeys.map((key) => key.constraintName),
      contains(reminderForeignKeys().single.constraintName),
    );

    final priorSql = File('$prior/definition.sql').readAsStringSync();
    final migrationSql = File('$current/migration.sql').readAsStringSync();
    final sql = File('$current/definition.sql').readAsStringSync();
    for (final match in RegExp(
      r'ALTER TABLE [^;]+(?:;|\n)',
    ).allMatches(priorSql)) {
      if (match.group(0)!.contains('ADD CONSTRAINT')) {
        expect(sql, contains(match.group(0)!));
      }
    }
    expect(migrationSql, isNot(contains('DROP CONSTRAINT')));
    expect(sql, contains('closecall_reminder_valid'));
    expect(sql, contains('closecall_moment_event_valid'));
    expect(sql, contains('closecall_reminder_same_couple_creator'));
    expect(sql, contains('closecall_moment_event_same_couple_moment'));
    expect(sql, contains('closecall_moment_event_same_couple_recipient'));
  });

  test('Reminders migration extension is deterministic and fails closed', () {
    final directory = Directory.current;
    final first = remindersMigrationArtifacts(directory);
    final second = remindersMigrationArtifacts(directory);
    expect(second, first);
    final migration = db.DatabaseMigration.fromJson(
      jsonDecode(File('$current/migration.json').readAsStringSync()),
    );
    expect(
      () => extendRemindersMigration(
        migration.copyWith(
          warnings: [
            db.DatabaseMigrationWarning(
              message: 'unexpected',
              type: db.DatabaseMigrationWarningType.tableDropped,
              table: 'unexpected',
              columns: const [],
              destructive: true,
            ),
          ],
        ),
        db.DatabaseDefinition.fromJson(
          jsonDecode(File('$prior/definition.json').readAsStringSync()),
        ),
      ),
      throwsStateError,
    );
  });
}
