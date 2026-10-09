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
  test(
    'FCM outbox migration preserves its composite integrity and retry schema',
    () {
      const version = '20261006120000000-fcm-outbox';
      final migration = db.DatabaseMigration.fromJson(
        jsonDecode(
          File('migrations/$version/migration.json').readAsStringSync(),
        ),
      );
      expect(
        migration.actions.map((action) => action.alterTable?.name),
        containsAll(<String>['closecall_widget_send', 'closecall_push_outbox']),
      );
      final definition = db.DatabaseDefinition.fromJson(
        jsonDecode(
          File('migrations/$version/definition.json').readAsStringSync(),
        ),
      );
      final outbox = definition.tables.singleWhere(
        (table) => table.name == 'closecall_push_outbox',
      );
      expect(
        outbox.foreignKeys.map((key) => key.constraintName),
        containsAll(<String>[
          'closecall_push_outbox_same_couple_send',
          'closecall_push_outbox_same_couple_recipient',
        ]),
      );
      final sql = File('migrations/$version/migration.sql').readAsStringSync();
      expect(sql, contains('closecall_push_outbox_valid'));
      expect(sql, contains('closecall_push_outbox_send_version_unique'));
      expect(sql, contains(version));
      final runtime = Protocol().getTargetTableDefinitions().singleWhere(
        (table) => table.name == 'closecall_push_outbox',
      );
      expect(
        runtime.foreignKeys.map((key) => key.constraintName),
        containsAll(<String>[
          'closecall_push_outbox_same_couple_send',
          'closecall_push_outbox_same_couple_recipient',
        ]),
      );
    },
  );
  test(
    'widget credential migration preserves all prior constraints and adds scoped cascade',
    () {
      const prior = 'migrations/20261006120000000-fcm-outbox';
      const current = 'migrations/20261006224415374-widget-device-credentials';
      final migration = db.DatabaseMigration.fromJson(
        jsonDecode(File('$current/migration.json').readAsStringSync()),
      );
      expect(migration.actions, hasLength(1));
      expect(
        migration.actions.single.createTable!.name,
        'closecall_widget_device_credential',
      );
      for (final filename in ['definition.json', 'definition_project.json']) {
        final old = db.DatabaseDefinition.fromJson(
          jsonDecode(File('$prior/$filename').readAsStringSync()),
        );
        final definition = db.DatabaseDefinition.fromJson(
          jsonDecode(File('$current/$filename').readAsStringSync()),
        );
        for (final table in old.tables) {
          final actual = definition.tables.singleWhere(
            (t) => t.name == table.name,
          );
          expect(
            actual.foreignKeys.map((k) => k.toJson()),
            table.foreignKeys.map((k) => k.toJson()),
          );
          expect(
            actual.indexes.map((i) => i.toJson()),
            table.indexes.map((i) => i.toJson()),
          );
        }
        final credential = definition.tables.singleWhere(
          (t) => t.name == 'closecall_widget_device_credential',
        );
        expect(
          credential.columns.map((c) => c.name),
          isNot(contains('credential')),
        );
        final key = credential.foreignKeys.singleWhere(
          (k) =>
              k.constraintName ==
              'closecall_widget_credential_same_couple_member',
        );
        expect(key.toJson(), widgetCredentialForeignKeys().single.toJson());
        expect(credential.indexes.every((i) => i.isUnique), isTrue);
      }
      final oldSql = File('$prior/definition.sql').readAsStringSync();
      final sql = File('$current/definition.sql').readAsStringSync();
      // SQL-only CHECK definitions must survive the fresh-install snapshot.
      for (final match in RegExp(
        r'ALTER TABLE "[^"]+"\s+ADD CONSTRAINT [^;]+;',
      ).allMatches(oldSql)) {
        expect(sql, contains(match.group(0)!));
      }
      for (final filename in ['definition.sql', 'migration.sql']) {
        final sql = File('$current/$filename').readAsStringSync();
        expect(sql, contains('FOREIGN KEY("coupleId", "memberId")'));
        expect(sql, contains('closecall_widget_credential_valid'));
        expect(sql, contains("INTERVAL '24 hours'"));
        expect(sql, contains("'^[0-9a-f]{64}\$'"));
      }
      final runtime = Protocol().getTargetTableDefinitions().singleWhere(
        (t) => t.name == 'closecall_widget_device_credential',
      );
      final actual = runtime.foreignKeys.singleWhere(
        (k) =>
            k.constraintName ==
            widgetCredentialForeignKeys().single.constraintName,
      );
      expect(actual.columns.toSet(), {'coupleId', 'memberId'});
      expect(actual.referenceColumns.toSet(), {'coupleId', 'id'});
      expect(actual.onDelete, widgetCredentialForeignKeys().single.onDelete);
    },
  );
}
