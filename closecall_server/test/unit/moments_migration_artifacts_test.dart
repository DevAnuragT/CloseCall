import 'dart:convert';
import 'dart:io';

import 'package:closecall_server/src/generated/protocol.dart';
import 'package:closecall_server/src/widget/widget_schedule_schema.dart';
import 'package:serverpod_database/serverpod_database.dart' as db;
import 'package:test/test.dart';

void main() {
  const prior = 'migrations/20261007041835495-live-mood';
  const current = 'migrations/20261010204723852-moments';
  test(
    'Moments migration retains every prior table and SQL-only constraint',
    () {
      final migration = db.DatabaseMigration.fromJson(
        jsonDecode(File('$current/migration.json').readAsStringSync()),
      );
      expect(migration.actions, hasLength(1));
      expect(migration.actions.single.createTable!.name, 'closecall_moment');
      for (final filename in ['definition.json', 'definition_project.json']) {
        final old = db.DatabaseDefinition.fromJson(
          jsonDecode(File('$prior/$filename').readAsStringSync()),
        );
        final definition = db.DatabaseDefinition.fromJson(
          jsonDecode(File('$current/$filename').readAsStringSync()),
        );
        for (final table in old.tables) {
          expect(
            definition.tables.singleWhere((t) => t.name == table.name).toJson(),
            table.toJson(),
          );
        }
        final moment = definition.tables.singleWhere(
          (t) => t.name == 'closecall_moment',
        );
        expect(
          moment.foreignKeys
              .singleWhere(
                (k) =>
                    k.constraintName ==
                    momentForeignKeys().single.constraintName,
              )
              .toJson(),
          momentForeignKeys().single.toJson(),
        );
      }
      final oldSql = File('$prior/definition.sql').readAsStringSync();
      final sql = File('$current/definition.sql').readAsStringSync();
      for (final match in RegExp(
        r'ALTER TABLE "[^"]+"\s+ADD CONSTRAINT [^;]+;',
      ).allMatches(oldSql)) {
        expect(sql, contains(match.group(0)!));
      }
      for (final filename in ['definition.sql', 'migration.sql']) {
        final sql = File('$current/$filename').readAsStringSync();
        expect(sql, contains('FOREIGN KEY("coupleId", "authorMemberId")'));
        expect(sql, contains('closecall_moment_valid'));
        expect(sql, contains('BETWEEN 1 AND 30000'));
        expect(sql, isNot(contains('DROP CONSTRAINT')));
      }
      final runtime = Protocol().getTargetTableDefinitions().singleWhere(
        (t) => t.name == 'closecall_moment',
      );
      final key = runtime.foreignKeys.singleWhere(
        (k) => k.constraintName == momentForeignKeys().single.constraintName,
      );
      expect(key.columns.toSet(), {'coupleId', 'authorMemberId'});
      expect(key.referenceColumns.toSet(), {'coupleId', 'id'});
    },
  );
}
