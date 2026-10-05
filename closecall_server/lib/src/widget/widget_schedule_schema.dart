import 'package:serverpod/protocol.dart';

/// Same-couple relations cannot be expressed in Serverpod's single-column
/// model DSL. Keep these in migration JSON and runtime schema verification.
List<ForeignKeyDefinition> scheduleForeignKeys(String table) {
  final prefix = table;
  ForeignKeyDefinition key(String suffix, String column, String parent) =>
      ForeignKeyDefinition(
        constraintName: '${prefix}_same_couple_$suffix',
        columns: ['coupleId', column],
        referenceTable: parent,
        referenceTableSchema: 'public',
        referenceColumns: ['coupleId', 'id'],
        onUpdate: ForeignKeyAction.noAction,
        onDelete: ForeignKeyAction.cascade,
      );
  return [
    key('asset', 'assetId', 'closecall_media'),
    if (table != 'closecall_widget_fallback')
      key('sender', 'senderMemberId', 'closecall_couple_member'),
    key('recipient', 'recipientMemberId', 'closecall_couple_member'),
  ];
}

List<ForeignKeyDefinition> pushRegistrationForeignKeys() => [
  ForeignKeyDefinition(
    constraintName: 'closecall_push_registration_same_couple_member',
    columns: ['coupleId', 'memberId'],
    referenceTable: 'closecall_couple_member',
    referenceTableSchema: 'public',
    referenceColumns: ['coupleId', 'id'],
    onUpdate: ForeignKeyAction.noAction,
    onDelete: ForeignKeyAction.cascade,
  ),
];

List<TableDefinition> withScheduleConstraints(
  List<TableDefinition> tables,
) => tables.map((table) {
  final isScheduleTable = table.name == 'closecall_widget_schedule' ||
      table.name == 'closecall_widget_fallback' ||
      table.name == 'closecall_widget_delivery' ||
      table.name == 'closecall_widget_send';
  final isPushTable = table.name == 'closecall_push_device_registration';
  if (!isScheduleTable && !isPushTable) {
    return table;
  }
  // Serverpod 4.0.3's PostgresAnalyzer resolves conkey/confkey without WITH
  // ORDINALITY/ORDER BY and reports each side in physical column order. This
  // view is ONLY for runtime verification, not SQL/artifact generation. The
  // canonical definitions above retain correct paired FK column ordering.
  final additional = (isPushTable
          ? pushRegistrationForeignKeys()
          : scheduleForeignKeys(table.name))
      .map((key) {
    final parent = tables.singleWhere((t) => t.name == key.referenceTable);
    return key.copyWith(
      columns: table.columns
          .map((c) => c.name)
          .where(key.columns.contains)
          .toList(),
      referenceColumns: parent.columns
          .map((c) => c.name)
          .where(key.referenceColumns.contains)
          .toList(),
    );
  }).toList();
  return table.copyWith(
    foreignKeys: [
      ...table.foreignKeys.where(
        (key) => !additional.any((a) => a.constraintName == key.constraintName),
      ),
      ...additional,
    ],
  );
}).toList();
