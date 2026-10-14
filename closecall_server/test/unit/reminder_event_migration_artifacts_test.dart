import 'dart:convert';
import 'dart:io';

import 'package:closecall_server/src/widget/widget_schedule_schema.dart';
import 'package:serverpod_database/serverpod_database.dart' as db;
import 'package:test/test.dart';

import '../../tool/extend_reminder_event_migration.dart';

void main() {
  const current = 'migrations/20261014053004876-reminder-fcm';

  test('Reminder event migration preserves prior constraints', () {
    final definition = db.DatabaseDefinition.fromJson(
      jsonDecode(File('$current/definition.json').readAsStringSync()),
    );
    final outbox = definition.tables.singleWhere(
      (table) => table.name == 'closecall_reminder_event_outbox',
    );
    expect(
      outbox.foreignKeys.map((key) => key.constraintName),
      containsAll(reminderEventForeignKeys().map((key) => key.constraintName)),
    );
    final reminder = definition.tables.singleWhere(
      (table) => table.name == 'closecall_reminder',
    );
    expect(
      reminder.indexes.map((index) => index.indexName),
      contains(reminderCoupleIndex().indexName),
    );
    final sql = File('$current/migration.sql').readAsStringSync();
    expect(sql, isNot(contains('DROP CONSTRAINT')));
    expect(sql, contains('closecall_reminder_couple_id_unique'));
    expect(sql, contains('closecall_reminder_event_same_couple_reminder'));
    expect(sql, contains('closecall_reminder_event_same_couple_recipient'));
    expect(sql, contains('closecall_reminder_event_valid'));
  });

  test('Reminder event migration extension is deterministic', () {
    final directory = Directory.current;
    expect(
      reminderEventMigrationArtifacts(directory),
      reminderEventMigrationArtifacts(directory),
    );
  });
}
