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

abstract class WidgetDeliveryRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  WidgetDeliveryRecord._({
    this.id,
    required this.coupleId,
    required this.recipientMemberId,
    bool? autoUpdateEnabled,
    int? version,
    this.assetId,
    this.senderMemberId,
    this.sentAt,
  }) : autoUpdateEnabled = autoUpdateEnabled ?? false,
       version = version ?? 0;

  factory WidgetDeliveryRecord({
    int? id,
    required _is.UuidValue coupleId,
    required int recipientMemberId,
    bool? autoUpdateEnabled,
    int? version,
    _is.UuidValue? assetId,
    int? senderMemberId,
    DateTime? sentAt,
  }) = _WidgetDeliveryRecordImpl;

  factory WidgetDeliveryRecord.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WidgetDeliveryRecord(
      id: jsonSerialization['id'] as int?,
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      recipientMemberId: jsonSerialization['recipientMemberId'] as int,
      autoUpdateEnabled: jsonSerialization['autoUpdateEnabled'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['autoUpdateEnabled'],
            ),
      version: jsonSerialization['version'] as int?,
      assetId: jsonSerialization['assetId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['assetId']),
      senderMemberId: jsonSerialization['senderMemberId'] as int?,
      sentAt: jsonSerialization['sentAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['sentAt']),
    );
  }

  static final t = WidgetDeliveryRecordTable();

  static const db = WidgetDeliveryRecordRepository._();

  @override
  int? id;

  _is.UuidValue coupleId;

  int recipientMemberId;

  bool autoUpdateEnabled;

  int version;

  _is.UuidValue? assetId;

  int? senderMemberId;

  DateTime? sentAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [WidgetDeliveryRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WidgetDeliveryRecord copyWith({
    int? id,
    _is.UuidValue? coupleId,
    int? recipientMemberId,
    bool? autoUpdateEnabled,
    int? version,
    _is.UuidValue? assetId,
    int? senderMemberId,
    DateTime? sentAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WidgetDeliveryRecord',
      if (id != null) 'id': id,
      'coupleId': coupleId.toJson(),
      'recipientMemberId': recipientMemberId,
      'autoUpdateEnabled': autoUpdateEnabled,
      'version': version,
      if (assetId != null) 'assetId': assetId?.toJson(),
      if (senderMemberId != null) 'senderMemberId': senderMemberId,
      if (sentAt != null) 'sentAt': sentAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WidgetDeliveryRecordInclude include() {
    return WidgetDeliveryRecordInclude._();
  }

  static WidgetDeliveryRecordIncludeList includeList({
    _is.WhereExpressionBuilder<WidgetDeliveryRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetDeliveryRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeliveryRecordTable>? orderByList,
    WidgetDeliveryRecordInclude? include,
  }) {
    return WidgetDeliveryRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WidgetDeliveryRecord.t),
      orderByList: orderByList?.call(WidgetDeliveryRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WidgetDeliveryRecordImpl extends WidgetDeliveryRecord {
  _WidgetDeliveryRecordImpl({
    int? id,
    required _is.UuidValue coupleId,
    required int recipientMemberId,
    bool? autoUpdateEnabled,
    int? version,
    _is.UuidValue? assetId,
    int? senderMemberId,
    DateTime? sentAt,
  }) : super._(
         id: id,
         coupleId: coupleId,
         recipientMemberId: recipientMemberId,
         autoUpdateEnabled: autoUpdateEnabled,
         version: version,
         assetId: assetId,
         senderMemberId: senderMemberId,
         sentAt: sentAt,
       );

  /// Returns a shallow copy of this [WidgetDeliveryRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WidgetDeliveryRecord copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    int? recipientMemberId,
    bool? autoUpdateEnabled,
    int? version,
    Object? assetId = _Undefined,
    Object? senderMemberId = _Undefined,
    Object? sentAt = _Undefined,
  }) {
    return WidgetDeliveryRecord(
      id: id is int? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      recipientMemberId: recipientMemberId ?? this.recipientMemberId,
      autoUpdateEnabled: autoUpdateEnabled ?? this.autoUpdateEnabled,
      version: version ?? this.version,
      assetId: assetId is _is.UuidValue? ? assetId : this.assetId,
      senderMemberId: senderMemberId is int?
          ? senderMemberId
          : this.senderMemberId,
      sentAt: sentAt is DateTime? ? sentAt : this.sentAt,
    );
  }
}

class WidgetDeliveryRecordUpdateTable
    extends _is.UpdateTable<WidgetDeliveryRecordTable> {
  WidgetDeliveryRecordUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<int, int> recipientMemberId(int value) =>
      _is.ColumnValue(table.recipientMemberId, value);

  _is.ColumnValue<bool, bool> autoUpdateEnabled(bool value) =>
      _is.ColumnValue(table.autoUpdateEnabled, value);

  _is.ColumnValue<int, int> version(int value) =>
      _is.ColumnValue(table.version, value);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> assetId(_is.UuidValue? value) =>
      _is.ColumnValue(table.assetId, value);

  _is.ColumnValue<int, int> senderMemberId(int? value) =>
      _is.ColumnValue(table.senderMemberId, value);

  _is.ColumnValue<DateTime, DateTime> sentAt(DateTime? value) =>
      _is.ColumnValue(table.sentAt, value);
}

class WidgetDeliveryRecordTable extends _is.Table<int?> {
  WidgetDeliveryRecordTable({super.tableRelation})
    : super(tableName: 'closecall_widget_delivery') {
    updateTable = WidgetDeliveryRecordUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    recipientMemberId = _is.ColumnInt('recipientMemberId', this);
    autoUpdateEnabled = _is.ColumnBool(
      'autoUpdateEnabled',
      this,
      hasDefault: true,
    );
    version = _is.ColumnInt('version', this, hasDefault: true);
    assetId = _is.ColumnUuid('assetId', this);
    senderMemberId = _is.ColumnInt('senderMemberId', this);
    sentAt = _is.ColumnDateTime('sentAt', this);
  }

  late final WidgetDeliveryRecordUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnInt recipientMemberId;

  late final _is.ColumnBool autoUpdateEnabled;

  late final _is.ColumnInt version;

  late final _is.ColumnUuid assetId;

  late final _is.ColumnInt senderMemberId;

  late final _is.ColumnDateTime sentAt;

  @override
  List<_is.Column> get columns => [
    id,
    coupleId,
    recipientMemberId,
    autoUpdateEnabled,
    version,
    assetId,
    senderMemberId,
    sentAt,
  ];
}

class WidgetDeliveryRecordInclude extends _is.IncludeObject {
  WidgetDeliveryRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => WidgetDeliveryRecord.t;
}

class WidgetDeliveryRecordIncludeList extends _is.IncludeList {
  WidgetDeliveryRecordIncludeList._({
    _is.WhereExpressionBuilder<WidgetDeliveryRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WidgetDeliveryRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => WidgetDeliveryRecord.t;
}

class WidgetDeliveryRecordRepository {
  const WidgetDeliveryRecordRepository._();

  /// Returns a list of [WidgetDeliveryRecord]s matching the given query parameters.
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
  Future<List<WidgetDeliveryRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetDeliveryRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetDeliveryRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeliveryRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WidgetDeliveryRecord>(
      where: where?.call(WidgetDeliveryRecord.t),
      orderBy: orderBy?.call(WidgetDeliveryRecord.t),
      orderByList: orderByList?.call(WidgetDeliveryRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WidgetDeliveryRecord] matching the given query parameters.
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
  Future<WidgetDeliveryRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetDeliveryRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<WidgetDeliveryRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeliveryRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WidgetDeliveryRecord>(
      where: where?.call(WidgetDeliveryRecord.t),
      orderBy: orderBy?.call(WidgetDeliveryRecord.t),
      orderByList: orderByList?.call(WidgetDeliveryRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WidgetDeliveryRecord] by its [id] or null if no such row exists.
  Future<WidgetDeliveryRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WidgetDeliveryRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WidgetDeliveryRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [WidgetDeliveryRecord]s will have their `id` fields set.
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
  Future<List<WidgetDeliveryRecord>> insert(
    _is.DatabaseSession session,
    List<WidgetDeliveryRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<WidgetDeliveryRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [WidgetDeliveryRecord] and returns the inserted row.
  ///
  /// The returned [WidgetDeliveryRecord] will have its `id` field set.
  Future<WidgetDeliveryRecord> insertRow(
    _is.DatabaseSession session,
    WidgetDeliveryRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<WidgetDeliveryRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [WidgetDeliveryRecord]s in the list and returns the resulting rows.
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
  /// The returned [WidgetDeliveryRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetDeliveryRecord>> upsert(
    _is.DatabaseSession session,
    List<WidgetDeliveryRecord> rows, {
    required _is.ColumnSelections<WidgetDeliveryRecordTable> conflictColumns,
    _is.ColumnSelections<WidgetDeliveryRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<WidgetDeliveryRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<WidgetDeliveryRecord>(
      rows,
      conflictColumns: conflictColumns(WidgetDeliveryRecord.t),
      updateColumns: updateColumns?.call(WidgetDeliveryRecord.t),
      updateWhere: updateWhere?.call(WidgetDeliveryRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [WidgetDeliveryRecord] and returns the resulting row.
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
  /// The returned [WidgetDeliveryRecord] will have its `id` field set.
  Future<WidgetDeliveryRecord?> upsertRow(
    _is.DatabaseSession session,
    WidgetDeliveryRecord row, {
    required _is.ColumnSelections<WidgetDeliveryRecordTable> conflictColumns,
    _is.ColumnSelections<WidgetDeliveryRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<WidgetDeliveryRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<WidgetDeliveryRecord>(
      row,
      conflictColumns: conflictColumns(WidgetDeliveryRecord.t),
      updateColumns: updateColumns?.call(WidgetDeliveryRecord.t),
      updateWhere: updateWhere?.call(WidgetDeliveryRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [WidgetDeliveryRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetDeliveryRecord>> update(
    _is.DatabaseSession session,
    List<WidgetDeliveryRecord> rows, {
    _is.ColumnSelections<WidgetDeliveryRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<WidgetDeliveryRecord>(
      rows,
      columns: columns?.call(WidgetDeliveryRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [WidgetDeliveryRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WidgetDeliveryRecord> updateRow(
    _is.DatabaseSession session,
    WidgetDeliveryRecord row, {
    _is.ColumnSelections<WidgetDeliveryRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<WidgetDeliveryRecord>(
      row,
      columns: columns?.call(WidgetDeliveryRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WidgetDeliveryRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WidgetDeliveryRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<WidgetDeliveryRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<WidgetDeliveryRecord>(
      id,
      columnValues: columnValues(WidgetDeliveryRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WidgetDeliveryRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetDeliveryRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<WidgetDeliveryRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<WidgetDeliveryRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetDeliveryRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeliveryRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<WidgetDeliveryRecord>(
      columnValues: columnValues(WidgetDeliveryRecord.t.updateTable),
      where: where(WidgetDeliveryRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WidgetDeliveryRecord.t),
      orderByList: orderByList?.call(WidgetDeliveryRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [WidgetDeliveryRecord]s in the list and returns the deleted rows.
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
  Future<List<WidgetDeliveryRecord>> delete(
    _is.DatabaseSession session,
    List<WidgetDeliveryRecord> rows, {
    _is.OrderByBuilder<WidgetDeliveryRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeliveryRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<WidgetDeliveryRecord>(
      rows,
      orderBy: orderBy?.call(WidgetDeliveryRecord.t),
      orderByList: orderByList?.call(WidgetDeliveryRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [WidgetDeliveryRecord].
  Future<WidgetDeliveryRecord> deleteRow(
    _is.DatabaseSession session,
    WidgetDeliveryRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WidgetDeliveryRecord>(
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
  Future<List<WidgetDeliveryRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WidgetDeliveryRecordTable> where,
    _is.OrderByBuilder<WidgetDeliveryRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeliveryRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<WidgetDeliveryRecord>(
      where: where(WidgetDeliveryRecord.t),
      orderBy: orderBy?.call(WidgetDeliveryRecord.t),
      orderByList: orderByList?.call(WidgetDeliveryRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetDeliveryRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<WidgetDeliveryRecord>(
      where: where?.call(WidgetDeliveryRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WidgetDeliveryRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WidgetDeliveryRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WidgetDeliveryRecord>(
      where: where(WidgetDeliveryRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
