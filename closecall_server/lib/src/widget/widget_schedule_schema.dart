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

List<ForeignKeyDefinition> pushOutboxForeignKeys() => [
  ForeignKeyDefinition(
    constraintName: 'closecall_push_outbox_same_couple_send',
    columns: ['coupleId', 'sendId'],
    referenceTable: 'closecall_widget_send',
    referenceTableSchema: 'public',
    referenceColumns: ['coupleId', 'id'],
    onUpdate: ForeignKeyAction.noAction,
    onDelete: ForeignKeyAction.cascade,
  ),
  ForeignKeyDefinition(
    constraintName: 'closecall_push_outbox_same_couple_recipient',
    columns: ['coupleId', 'recipientMemberId'],
    referenceTable: 'closecall_couple_member',
    referenceTableSchema: 'public',
    referenceColumns: ['coupleId', 'id'],
    onUpdate: ForeignKeyAction.noAction,
    onDelete: ForeignKeyAction.cascade,
  ),
];

List<ForeignKeyDefinition> widgetCredentialForeignKeys() => [
  ForeignKeyDefinition(
    constraintName: 'closecall_widget_credential_same_couple_member',
    columns: ['coupleId', 'memberId'],
    referenceTable: 'closecall_couple_member',
    referenceTableSchema: 'public',
    referenceColumns: ['coupleId', 'id'],
    onUpdate: ForeignKeyAction.noAction,
    onDelete: ForeignKeyAction.cascade,
  ),
];

List<ForeignKeyDefinition> momentForeignKeys() => [
  ForeignKeyDefinition(
    constraintName: 'closecall_moment_same_couple_author',
    columns: ['coupleId', 'authorMemberId'],
    referenceTable: 'closecall_couple_member',
    referenceTableSchema: 'public',
    referenceColumns: ['coupleId', 'id'],
    onUpdate: ForeignKeyAction.noAction,
    onDelete: ForeignKeyAction.cascade,
  ),
];

/// Composite outbox references require a matching unique parent index. The
/// Moments model predates that relation, so extend its target schema alongside
/// the pending Reminders migration rather than rewriting the installed one.
IndexDefinition momentCoupleIndex() => IndexDefinition(
  indexName: 'closecall_moment_couple_id_unique',
  elements: [
    for (final column in ['coupleId', 'id'])
      IndexElementDefinition(
        type: IndexElementDefinitionType.column,
        definition: column,
      ),
  ],
  type: 'btree',
  isUnique: true,
  isPrimary: false,
);

List<ForeignKeyDefinition> momentEventForeignKeys() => [
  ForeignKeyDefinition(
    constraintName: 'closecall_moment_event_same_couple_moment',
    columns: ['coupleId', 'momentId'],
    referenceTable: 'closecall_moment',
    referenceTableSchema: 'public',
    referenceColumns: ['coupleId', 'id'],
    onUpdate: ForeignKeyAction.noAction,
    onDelete: ForeignKeyAction.cascade,
  ),
  ForeignKeyDefinition(
    constraintName: 'closecall_moment_event_same_couple_recipient',
    columns: ['coupleId', 'recipientMemberId'],
    referenceTable: 'closecall_couple_member',
    referenceTableSchema: 'public',
    referenceColumns: ['coupleId', 'id'],
    onUpdate: ForeignKeyAction.noAction,
    onDelete: ForeignKeyAction.cascade,
  ),
];

List<ForeignKeyDefinition> reminderForeignKeys() => [
  ForeignKeyDefinition(
    constraintName: 'closecall_reminder_same_couple_creator',
    columns: ['coupleId', 'creatorMemberId'],
    referenceTable: 'closecall_couple_member',
    referenceTableSchema: 'public',
    referenceColumns: ['coupleId', 'id'],
    onUpdate: ForeignKeyAction.noAction,
    onDelete: ForeignKeyAction.cascade,
  ),
];

IndexDefinition reminderCoupleIndex() => IndexDefinition(
  indexName: 'closecall_reminder_couple_id_unique',
  elements: [
    for (final column in ['coupleId', 'id'])
      IndexElementDefinition(
        type: IndexElementDefinitionType.column,
        definition: column,
      ),
  ],
  type: 'btree',
  isUnique: true,
  isPrimary: false,
);

List<ForeignKeyDefinition> reminderEventForeignKeys() => [
  ForeignKeyDefinition(
    constraintName: 'closecall_reminder_event_same_couple_reminder',
    columns: ['coupleId', 'reminderId'],
    referenceTable: 'closecall_reminder',
    referenceTableSchema: 'public',
    referenceColumns: ['coupleId', 'id'],
    onUpdate: ForeignKeyAction.noAction,
    onDelete: ForeignKeyAction.cascade,
  ),
  ForeignKeyDefinition(
    constraintName: 'closecall_reminder_event_same_couple_recipient',
    columns: ['coupleId', 'recipientMemberId'],
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
  final isScheduleTable =
      table.name == 'closecall_widget_schedule' ||
      table.name == 'closecall_widget_fallback' ||
      table.name == 'closecall_widget_delivery' ||
      table.name == 'closecall_widget_send';
  final isPushTable = table.name == 'closecall_push_device_registration';
  final isPushOutboxTable = table.name == 'closecall_push_outbox';
  final isCredentialTable = table.name == 'closecall_widget_device_credential';
  final isMomentTable = table.name == 'closecall_moment';
  final isMomentEventTable = table.name == 'closecall_moment_event_outbox';
  final isReminderTable = table.name == 'closecall_reminder';
  final isReminderEventTable = table.name == 'closecall_reminder_event_outbox';
  if (!isScheduleTable &&
      !isPushTable &&
      !isPushOutboxTable &&
      !isCredentialTable &&
      !isMomentTable &&
      !isMomentEventTable &&
      !isReminderTable &&
      !isReminderEventTable) {
    return table;
  }
  // Serverpod 4.0.3's PostgresAnalyzer resolves conkey/confkey without WITH
  // ORDINALITY/ORDER BY and reports each side in physical column order. This
  // view is ONLY for runtime verification, not SQL/artifact generation. The
  // canonical definitions above retain correct paired FK column ordering.
  final additional =
      (isReminderEventTable
              ? reminderEventForeignKeys()
              : isReminderTable
              ? reminderForeignKeys()
              : isMomentEventTable
              ? momentEventForeignKeys()
              : isMomentTable
              ? momentForeignKeys()
              : isCredentialTable
              ? widgetCredentialForeignKeys()
              : isPushTable
              ? pushRegistrationForeignKeys()
              : isPushOutboxTable
              ? pushOutboxForeignKeys()
              : scheduleForeignKeys(table.name))
          .map((key) {
            final parent = tables.singleWhere(
              (t) => t.name == key.referenceTable,
            );
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
          })
          .toList();
  return table.copyWith(
    indexes: isMomentTable
        ? [
            ...table.indexes.where(
              (index) => index.indexName != momentCoupleIndex().indexName,
            ),
            momentCoupleIndex(),
          ]
        : isReminderTable
        ? [
            ...table.indexes.where(
              (index) => index.indexName != reminderCoupleIndex().indexName,
            ),
            reminderCoupleIndex(),
          ]
        : table.indexes,
    foreignKeys: [
      ...table.foreignKeys.where(
        (key) => !additional.any((a) => a.constraintName == key.constraintName),
      ),
      ...additional,
    ],
  );
}).toList();
