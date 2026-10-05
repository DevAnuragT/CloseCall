/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;

abstract class WidgetSendRecord
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  WidgetSendRecord._({
    this.id,
    required this.coupleId,
    required this.senderMemberId,
    required this.recipientMemberId,
    required this.assetId,
    required this.requestId,
    required this.version,
    DateTime? createdAt,
    required this.recipientAutoUpdateEnabled,
  }) : createdAt = createdAt ?? DateTime.now();

  factory WidgetSendRecord({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required int senderMemberId,
    required int recipientMemberId,
    required _is.UuidValue assetId,
    required String requestId,
    required int version,
    DateTime? createdAt,
    required bool recipientAutoUpdateEnabled,
  }) = _WidgetSendRecordImpl;

  factory WidgetSendRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return WidgetSendRecord(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      senderMemberId: jsonSerialization['senderMemberId'] as int,
      recipientMemberId: jsonSerialization['recipientMemberId'] as int,
      assetId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['assetId'],
      ),
      requestId: jsonSerialization['requestId'] as String,
      version: jsonSerialization['version'] as int,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      recipientAutoUpdateEnabled: _is.BoolJsonExtension.fromJson(
        jsonSerialization['recipientAutoUpdateEnabled'],
      ),
    );
  }

  static final t = WidgetSendRecordTable();

  static const db = WidgetSendRecordRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue coupleId;

  int senderMemberId;

  int recipientMemberId;

  _is.UuidValue assetId;

  String requestId;

  int version;

  DateTime createdAt;

  bool recipientAutoUpdateEnabled;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [WidgetSendRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WidgetSendRecord copyWith({
    _is.UuidValue? id,
    _is.UuidValue? coupleId,
    int? senderMemberId,
    int? recipientMemberId,
    _is.UuidValue? assetId,
    String? requestId,
    int? version,
    DateTime? createdAt,
    bool? recipientAutoUpdateEnabled,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WidgetSendRecord',
      if (id != null) 'id': id?.toJson(),
      'coupleId': coupleId.toJson(),
      'senderMemberId': senderMemberId,
      'recipientMemberId': recipientMemberId,
      'assetId': assetId.toJson(),
      'requestId': requestId,
      'version': version,
      'createdAt': createdAt.toJson(),
      'recipientAutoUpdateEnabled': recipientAutoUpdateEnabled,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WidgetSendRecordInclude include() {
    return WidgetSendRecordInclude._();
  }

  static WidgetSendRecordIncludeList includeList({
    _is.WhereExpressionBuilder<WidgetSendRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetSendRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetSendRecordTable>? orderByList,
    WidgetSendRecordInclude? include,
  }) {
    return WidgetSendRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WidgetSendRecord.t),
      orderByList: orderByList?.call(WidgetSendRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WidgetSendRecordImpl extends WidgetSendRecord {
  _WidgetSendRecordImpl({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required int senderMemberId,
    required int recipientMemberId,
    required _is.UuidValue assetId,
    required String requestId,
    required int version,
    DateTime? createdAt,
    required bool recipientAutoUpdateEnabled,
  }) : super._(
         id: id,
         coupleId: coupleId,
         senderMemberId: senderMemberId,
         recipientMemberId: recipientMemberId,
         assetId: assetId,
         requestId: requestId,
         version: version,
         createdAt: createdAt,
         recipientAutoUpdateEnabled: recipientAutoUpdateEnabled,
       );

  /// Returns a shallow copy of this [WidgetSendRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WidgetSendRecord copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    int? senderMemberId,
    int? recipientMemberId,
    _is.UuidValue? assetId,
    String? requestId,
    int? version,
    DateTime? createdAt,
    bool? recipientAutoUpdateEnabled,
  }) {
    return WidgetSendRecord(
      id: id is _is.UuidValue? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      senderMemberId: senderMemberId ?? this.senderMemberId,
      recipientMemberId: recipientMemberId ?? this.recipientMemberId,
      assetId: assetId ?? this.assetId,
      requestId: requestId ?? this.requestId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      recipientAutoUpdateEnabled:
          recipientAutoUpdateEnabled ?? this.recipientAutoUpdateEnabled,
    );
  }
}

class WidgetSendRecordUpdateTable
    extends _is.UpdateTable<WidgetSendRecordTable> {
  WidgetSendRecordUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<int, int> senderMemberId(int value) =>
      _is.ColumnValue(table.senderMemberId, value);

  _is.ColumnValue<int, int> recipientMemberId(int value) =>
      _is.ColumnValue(table.recipientMemberId, value);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> assetId(_is.UuidValue value) =>
      _is.ColumnValue(table.assetId, value);

  _is.ColumnValue<String, String> requestId(String value) =>
      _is.ColumnValue(table.requestId, value);

  _is.ColumnValue<int, int> version(int value) =>
      _is.ColumnValue(table.version, value);

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(table.createdAt, value);

  _is.ColumnValue<bool, bool> recipientAutoUpdateEnabled(bool value) =>
      _is.ColumnValue(table.recipientAutoUpdateEnabled, value);
}

class WidgetSendRecordTable extends _is.Table<_is.UuidValue?> {
  WidgetSendRecordTable({super.tableRelation})
    : super(tableName: 'closecall_widget_send') {
    updateTable = WidgetSendRecordUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    senderMemberId = _is.ColumnInt('senderMemberId', this);
    recipientMemberId = _is.ColumnInt('recipientMemberId', this);
    assetId = _is.ColumnUuid('assetId', this);
    requestId = _is.ColumnString('requestId', this);
    version = _is.ColumnInt('version', this);
    createdAt = _is.ColumnDateTime('createdAt', this, hasDefault: true);
    recipientAutoUpdateEnabled = _is.ColumnBool(
      'recipientAutoUpdateEnabled',
      this,
    );
  }

  late final WidgetSendRecordUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnInt senderMemberId;

  late final _is.ColumnInt recipientMemberId;

  late final _is.ColumnUuid assetId;

  late final _is.ColumnString requestId;

  late final _is.ColumnInt version;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnBool recipientAutoUpdateEnabled;

  @override
  List<_is.Column> get columns => [
    id,
    coupleId,
    senderMemberId,
    recipientMemberId,
    assetId,
    requestId,
    version,
    createdAt,
    recipientAutoUpdateEnabled,
  ];
}

class WidgetSendRecordInclude extends _is.IncludeObject {
  WidgetSendRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => WidgetSendRecord.t;
}

class WidgetSendRecordIncludeList extends _is.IncludeList {
  WidgetSendRecordIncludeList._({
    _is.WhereExpressionBuilder<WidgetSendRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WidgetSendRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => WidgetSendRecord.t;
}

class WidgetSendRecordRepository {
  const WidgetSendRecordRepository._();

  /// Returns a list of [WidgetSendRecord]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<WidgetSendRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetSendRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetSendRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetSendRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WidgetSendRecord>(
      where: where?.call(WidgetSendRecord.t),
      orderBy: orderBy?.call(WidgetSendRecord.t),
      orderByList: orderByList?.call(WidgetSendRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WidgetSendRecord] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<WidgetSendRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetSendRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<WidgetSendRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetSendRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WidgetSendRecord>(
      where: where?.call(WidgetSendRecord.t),
      orderBy: orderBy?.call(WidgetSendRecord.t),
      orderByList: orderByList?.call(WidgetSendRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WidgetSendRecord] by its [id] or null if no such row exists.
  Future<WidgetSendRecord?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WidgetSendRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WidgetSendRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [WidgetSendRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetSendRecord>> insert(
    _is.DatabaseSession session,
    List<WidgetSendRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<WidgetSendRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [WidgetSendRecord] and returns the inserted row.
  ///
  /// The returned [WidgetSendRecord] will have its `id` field set.
  Future<WidgetSendRecord> insertRow(
    _is.DatabaseSession session,
    WidgetSendRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<WidgetSendRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [WidgetSendRecord]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [WidgetSendRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetSendRecord>> upsert(
    _is.DatabaseSession session,
    List<WidgetSendRecord> rows, {
    required _is.ColumnSelections<WidgetSendRecordTable> conflictColumns,
    _is.ColumnSelections<WidgetSendRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<WidgetSendRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<WidgetSendRecord>(
      rows,
      conflictColumns: conflictColumns(WidgetSendRecord.t),
      updateColumns: updateColumns?.call(WidgetSendRecord.t),
      updateWhere: updateWhere?.call(WidgetSendRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [WidgetSendRecord] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [WidgetSendRecord] will have its `id` field set.
  Future<WidgetSendRecord?> upsertRow(
    _is.DatabaseSession session,
    WidgetSendRecord row, {
    required _is.ColumnSelections<WidgetSendRecordTable> conflictColumns,
    _is.ColumnSelections<WidgetSendRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<WidgetSendRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<WidgetSendRecord>(
      row,
      conflictColumns: conflictColumns(WidgetSendRecord.t),
      updateColumns: updateColumns?.call(WidgetSendRecord.t),
      updateWhere: updateWhere?.call(WidgetSendRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [WidgetSendRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetSendRecord>> update(
    _is.DatabaseSession session,
    List<WidgetSendRecord> rows, {
    _is.ColumnSelections<WidgetSendRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<WidgetSendRecord>(
      rows,
      columns: columns?.call(WidgetSendRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [WidgetSendRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WidgetSendRecord> updateRow(
    _is.DatabaseSession session,
    WidgetSendRecord row, {
    _is.ColumnSelections<WidgetSendRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<WidgetSendRecord>(
      row,
      columns: columns?.call(WidgetSendRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WidgetSendRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WidgetSendRecord?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<WidgetSendRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<WidgetSendRecord>(
      id,
      columnValues: columnValues(WidgetSendRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WidgetSendRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetSendRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<WidgetSendRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<WidgetSendRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetSendRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetSendRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<WidgetSendRecord>(
      columnValues: columnValues(WidgetSendRecord.t.updateTable),
      where: where(WidgetSendRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WidgetSendRecord.t),
      orderByList: orderByList?.call(WidgetSendRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [WidgetSendRecord]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetSendRecord>> delete(
    _is.DatabaseSession session,
    List<WidgetSendRecord> rows, {
    _is.OrderByBuilder<WidgetSendRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetSendRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<WidgetSendRecord>(
      rows,
      orderBy: orderBy?.call(WidgetSendRecord.t),
      orderByList: orderByList?.call(WidgetSendRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [WidgetSendRecord].
  Future<WidgetSendRecord> deleteRow(
    _is.DatabaseSession session,
    WidgetSendRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WidgetSendRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetSendRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WidgetSendRecordTable> where,
    _is.OrderByBuilder<WidgetSendRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetSendRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<WidgetSendRecord>(
      where: where(WidgetSendRecord.t),
      orderBy: orderBy?.call(WidgetSendRecord.t),
      orderByList: orderByList?.call(WidgetSendRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetSendRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<WidgetSendRecord>(
      where: where?.call(WidgetSendRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WidgetSendRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WidgetSendRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WidgetSendRecord>(
      where: where(WidgetSendRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
