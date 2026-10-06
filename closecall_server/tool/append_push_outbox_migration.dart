import 'dart:convert';
import 'dart:io';

/// Creates the reviewed durable FCM outbox migration from the latest checked
/// in definition. The pinned Serverpod DSL cannot express the same-couple
/// composite keys or SQL state check, so both are emitted explicitly here.
void main() {
  const old = '20261006081030595-nicknames';
  const version = '20261006120000000-fcm-outbox';
  final destination = Directory('migrations/$version');
  if (destination.existsSync()) {
    throw StateError('Migration artifacts already exist.');
  }
  destination.createSync(recursive: true);

  final table = _table();
  final migrationTable = Map<String, dynamic>.from(table)
    ..['foreignKeys'] = (table['foreignKeys'] as List).take(3).toList();
  final fullDefinition =
      jsonDecode(File('migrations/$old/definition.json').readAsStringSync())
          as Map<String, dynamic>;
  final tables = fullDefinition['tables'] as List;
  final widgetSend =
      tables.singleWhere((item) => item['name'] == 'closecall_widget_send')
          as Map<String, dynamic>;
  (widgetSend['indexes'] as List).add(
    _index('closecall_widget_send_couple_id_unique', ['coupleId', 'id'], true),
  );
  tables.insert(
    tables.indexWhere((item) => item['name'] == 'closecall_widget_delivery'),
    table,
  );
  final definitionText = const JsonEncoder.withIndent(
    '  ',
  ).convert(fullDefinition);
  File('${destination.path}/definition.json').writeAsStringSync(definitionText);
  File(
    '${destination.path}/definition_project.json',
  ).writeAsStringSync(definitionText);

  final migration = {
    '__className__': 'serverpod.DatabaseMigration',
    'actions': [
      {
        '__className__': 'serverpod.DatabaseMigrationAction',
        'type': 'alterTable',
        'alterTable': {
          '__className__': 'serverpod.TableMigration',
          'name': 'closecall_widget_send',
          'schema': 'public',
          'addColumns': [],
          'deleteColumns': [],
          'modifyColumns': [],
          'addIndexes': [
            _index('closecall_widget_send_couple_id_unique', [
              'coupleId',
              'id',
            ], true),
          ],
          'deleteIndexes': [],
          'warnings': [],
          'deleteForeignKeys': [],
          'addForeignKeys': [],
        },
      },
      {
        '__className__': 'serverpod.DatabaseMigrationAction',
        'type': 'createTable',
        'createTable': migrationTable,
      },
      {
        '__className__': 'serverpod.DatabaseMigrationAction',
        'type': 'alterTable',
        'alterTable': {
          '__className__': 'serverpod.TableMigration',
          'name': 'closecall_push_outbox',
          'schema': 'public',
          'addColumns': [],
          'deleteColumns': [],
          'modifyColumns': [],
          'addIndexes': [],
          'deleteIndexes': [],
          'warnings': [],
          'deleteForeignKeys': [],
          'addForeignKeys': [
            _composite('closecall_push_outbox_same_couple_send', [
              'coupleId',
              'sendId',
            ], 'closecall_widget_send'),
            _composite('closecall_push_outbox_same_couple_recipient', [
              'coupleId',
              'recipientMemberId',
            ], 'closecall_couple_member'),
          ],
        },
      },
    ],
    'warnings': [],
    'migrationApiVersion': 1,
  };
  File(
    '${destination.path}/migration.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(migration));

  final base = File(
    'migrations/$old/definition.sql',
  ).readAsStringSync().replaceAll(old, version);
  final fresh = base.replaceFirst(
    '-- Class WidgetDeliveryRecord as table closecall_widget_delivery',
    '${_tableSql().split('\nALTER TABLE ONLY').first}\n-- Class WidgetDeliveryRecord as table closecall_widget_delivery',
  );
  final freshWithSendKey = fresh.replaceFirst(
    'CREATE UNIQUE INDEX "closecall_widget_send_request_unique" ON "closecall_widget_send" USING btree ("coupleId", "requestId");',
    'CREATE UNIQUE INDEX "closecall_widget_send_request_unique" ON "closecall_widget_send" USING btree ("coupleId", "requestId");\nCREATE UNIQUE INDEX "closecall_widget_send_couple_id_unique" ON "closecall_widget_send" USING btree ("coupleId", "id");',
  );
  File('${destination.path}/definition.sql').writeAsStringSync(
    freshWithSendKey
        .replaceFirst(
          '-- Canonical same-couple composite constraints',
          '${_basicForeignSql()}${_compositeSql()}\n-- Canonical same-couple composite constraints',
        )
        .replaceFirst(
          '-- SQL-only invariants are not expressible',
          'ALTER TABLE "closecall_push_outbox" ADD CONSTRAINT "closecall_push_outbox_valid" CHECK ("version" > 0 AND "attempts" >= 0);\n\n-- SQL-only invariants are not expressible',
        ),
  );
  File('${destination.path}/migration.sql').writeAsStringSync(_migrationSql());

  final registry = File('migrations/migration_registry.txt');
  registry.writeAsStringSync('$version\n', mode: FileMode.append);
}

Map<String, dynamic> _column(
  String name,
  int type,
  String dartType, {
  bool nullable = false,
  String? defaultValue,
}) => {
  '__className__': 'serverpod.ColumnDefinition',
  'name': name,
  'fieldName': name,
  'columnType': type,
  'isNullable': nullable,
  ...?defaultValue == null ? null : {'columnDefault': defaultValue},
  'dartType': dartType,
};

Map<String, dynamic> _foreign(
  String name,
  List<String> columns,
  String table,
  List<String> references,
) => {
  '__className__': 'serverpod.ForeignKeyDefinition',
  'constraintName': name,
  'columns': columns,
  'referenceTable': table,
  'referenceTableSchema': 'public',
  'referenceColumns': references,
  'onUpdate': 3,
  'onDelete': 4,
};

Map<String, dynamic> _composite(
  String name,
  List<String> columns,
  String table,
) => _foreign(
  name,
  columns,
  table,
  table == 'closecall_widget_send' ? ['coupleId', 'id'] : ['coupleId', 'id'],
);

Map<String, dynamic> _index(String name, List<String> columns, bool unique) => {
  '__className__': 'serverpod.IndexDefinition',
  'indexName': name,
  'elements': columns
      .map(
        (column) => {
          '__className__': 'serverpod.IndexElementDefinition',
          'type': 0,
          'definition': column,
        },
      )
      .toList(),
  'type': 'btree',
  'isUnique': unique,
  'isPrimary': false,
};

Map<String, dynamic> _table() => {
  '__className__': 'serverpod.TableDefinition',
  'name': 'closecall_push_outbox',
  'dartName': 'PushOutbox',
  'module': 'closecall',
  'schema': 'public',
  'columns': [
    _column('id', 7, 'UuidValue?', defaultValue: 'random'),
    _column('coupleId', 7, 'UuidValue'),
    _column('sendId', 7, 'UuidValue'),
    _column('recipientMemberId', 6, 'int'),
    _column('version', 6, 'int'),
    _column('createdAt', 4, 'DateTime', defaultValue: 'now'),
    _column('attempts', 6, 'int', defaultValue: '0'),
    _column('availableAt', 4, 'DateTime', defaultValue: 'now'),
    _column('leasedUntil', 4, 'DateTime', nullable: true),
    _column('leaseOwner', 0, 'String?', nullable: true),
    _column('completedAt', 4, 'DateTime', nullable: true),
    _column('lastError', 0, 'String?', nullable: true),
  ],
  'foreignKeys': [
    _foreign(
      'closecall_push_outbox_fk_0',
      ['coupleId'],
      'closecall_couple',
      ['id'],
    ),
    _foreign(
      'closecall_push_outbox_fk_1',
      ['sendId'],
      'closecall_widget_send',
      ['id'],
    ),
    _foreign(
      'closecall_push_outbox_fk_2',
      ['recipientMemberId'],
      'closecall_couple_member',
      ['id'],
    ),
    _composite('closecall_push_outbox_same_couple_send', [
      'coupleId',
      'sendId',
    ], 'closecall_widget_send'),
    _composite('closecall_push_outbox_same_couple_recipient', [
      'coupleId',
      'recipientMemberId',
    ], 'closecall_couple_member'),
  ],
  'indexes': [
    _index('closecall_push_outbox_send_version_unique', [
      'sendId',
      'version',
    ], true),
    _index('closecall_push_outbox_ready_idx', [
      'completedAt',
      'availableAt',
    ], false),
  ],
  'managed': true,
};

String _tableSql() => '''--
-- Class PushOutbox as table closecall_push_outbox
--
CREATE TABLE "closecall_push_outbox" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "coupleId" uuid NOT NULL,
    "sendId" uuid NOT NULL,
    "recipientMemberId" bigint NOT NULL,
    "version" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "attempts" bigint NOT NULL DEFAULT 0,
    "availableAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "leasedUntil" timestamp without time zone,
    "leaseOwner" text,
    "completedAt" timestamp without time zone,
    "lastError" text
);

-- Indexes
CREATE UNIQUE INDEX "closecall_push_outbox_send_version_unique" ON "closecall_push_outbox" USING btree ("sendId", "version");
CREATE INDEX "closecall_push_outbox_ready_idx" ON "closecall_push_outbox" USING btree ("completedAt", "availableAt");

ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_fk_0"
    FOREIGN KEY("coupleId") REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_fk_1"
    FOREIGN KEY("sendId") REFERENCES "closecall_widget_send"("id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_fk_2"
    FOREIGN KEY("recipientMemberId") REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
''';

String _basicForeignSql() => '''ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_fk_0"
    FOREIGN KEY("coupleId") REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_fk_1"
    FOREIGN KEY("sendId") REFERENCES "closecall_widget_send"("id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_fk_2"
    FOREIGN KEY("recipientMemberId") REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
''';

String _compositeSql() => '''ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_same_couple_send"
    FOREIGN KEY("coupleId", "sendId")
    REFERENCES "closecall_widget_send"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_same_couple_recipient"
    FOREIGN KEY("coupleId", "recipientMemberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
''';

String _migrationSql() =>
    '''BEGIN;

CREATE UNIQUE INDEX "closecall_widget_send_couple_id_unique" ON "closecall_widget_send" USING btree ("coupleId", "id");

-- Durable FCM invalidation event. Payload is never stored here.
${_tableSql()}
${_compositeSql()}
ALTER TABLE "closecall_push_outbox"
  ADD CONSTRAINT "closecall_push_outbox_valid"
  CHECK ("version" > 0 AND "attempts" >= 0);

INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('closecall', '20261006120000000-fcm-outbox', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261006120000000-fcm-outbox', "timestamp" = now();
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module") DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260924105232991', now())
    ON CONFLICT ("module") DO UPDATE SET "version" = '20260924105232991', "timestamp" = now();
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260924105404509', now())
    ON CONFLICT ("module") DO UPDATE SET "version" = '20260924105404509', "timestamp" = now();

COMMIT;
''';
