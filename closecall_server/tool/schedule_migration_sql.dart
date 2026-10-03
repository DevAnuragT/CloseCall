import 'package:serverpod_cli/src/database/dialects/postgres.dart';
import 'package:serverpod_database/serverpod_database.dart';

/// Local workaround for Serverpod CLI 4.0.3's composite source-column quoting:
/// it emits FOREIGN KEY("coupleId, assetId") instead of separately quoting
/// each column. Do NOT encode quote fragments into the JSON column names.
/// Runtime MigrationManager executes migration.sql, so installed artifacts
/// remain valid without changing the pinned CLI/global cache.
String scheduleMigrationSql(
  DatabaseMigration migration,
  DatabaseDefinition definition,
) {
  var sql = PostgresSqlGenerator().generateDatabaseMigrationSql(
    migration,
    definition,
    installedModules: [],
    removedModules: [],
  );
  for (final action in migration.actions) {
    final keys = [
      ...?action.createTable?.foreignKeys,
      ...?action.alterTable?.addForeignKeys,
    ];
    for (final key in keys.where((key) => key.columns.length > 1)) {
      String quote(String name) => '"${name.replaceAll('"', '""')}"';
      final broken = 'FOREIGN KEY("${key.columns.join(', ')}")';
      final corrected = 'FOREIGN KEY(${key.columns.map(quote).join(', ')})';
      sql = sql.replaceAll(broken, corrected);
    }
  }
  return sql;
}
