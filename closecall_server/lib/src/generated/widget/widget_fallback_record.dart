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

abstract class WidgetFallbackRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  WidgetFallbackRecord._({
    this.id,
    required this.coupleId,
    required this.recipientMemberId,
    required this.assetId,
  });

  factory WidgetFallbackRecord({
    int? id,
    required _is.UuidValue coupleId,
    required int recipientMemberId,
    required _is.UuidValue assetId,
  }) = _WidgetFallbackRecordImpl;

  factory WidgetFallbackRecord.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WidgetFallbackRecord(
      id: jsonSerialization['id'] as int?,
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      recipientMemberId: jsonSerialization['recipientMemberId'] as int,
      assetId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['assetId'],
      ),
    );
  }

  static final t = WidgetFallbackRecordTable();

  static const db = WidgetFallbackRecordRepository._();

  @override
  int? id;

  _is.UuidValue coupleId;

  int recipientMemberId;

  _is.UuidValue assetId;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [WidgetFallbackRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WidgetFallbackRecord copyWith({
    int? id,
    _is.UuidValue? coupleId,
    int? recipientMemberId,
    _is.UuidValue? assetId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WidgetFallbackRecord',
      if (id != null) 'id': id,
      'coupleId': coupleId.toJson(),
      'recipientMemberId': recipientMemberId,
      'assetId': assetId.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WidgetFallbackRecordInclude include() {
    return WidgetFallbackRecordInclude._();
  }

  static WidgetFallbackRecordIncludeList includeList({
    _is.WhereExpressionBuilder<WidgetFallbackRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetFallbackRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetFallbackRecordTable>? orderByList,
    WidgetFallbackRecordInclude? include,
  }) {
    return WidgetFallbackRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WidgetFallbackRecord.t),
      orderByList: orderByList?.call(WidgetFallbackRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WidgetFallbackRecordImpl extends WidgetFallbackRecord {
  _WidgetFallbackRecordImpl({
    int? id,
    required _is.UuidValue coupleId,
    required int recipientMemberId,
    required _is.UuidValue assetId,
  }) : super._(
         id: id,
         coupleId: coupleId,
         recipientMemberId: recipientMemberId,
         assetId: assetId,
       );

  /// Returns a shallow copy of this [WidgetFallbackRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WidgetFallbackRecord copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    int? recipientMemberId,
    _is.UuidValue? assetId,
  }) {
    return WidgetFallbackRecord(
      id: id is int? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      recipientMemberId: recipientMemberId ?? this.recipientMemberId,
      assetId: assetId ?? this.assetId,
    );
  }
}

class WidgetFallbackRecordUpdateTable
    extends _is.UpdateTable<WidgetFallbackRecordTable> {
  WidgetFallbackRecordUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<int, int> recipientMemberId(int value) =>
      _is.ColumnValue(table.recipientMemberId, value);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> assetId(_is.UuidValue value) =>
      _is.ColumnValue(table.assetId, value);
}

class WidgetFallbackRecordTable extends _is.Table<int?> {
  WidgetFallbackRecordTable({super.tableRelation})
    : super(tableName: 'closecall_widget_fallback') {
    updateTable = WidgetFallbackRecordUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    recipientMemberId = _is.ColumnInt('recipientMemberId', this);
    assetId = _is.ColumnUuid('assetId', this);
  }

  late final WidgetFallbackRecordUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnInt recipientMemberId;

  late final _is.ColumnUuid assetId;

  @override
  List<_is.Column> get columns => [id, coupleId, recipientMemberId, assetId];
}

class WidgetFallbackRecordInclude extends _is.IncludeObject {
  WidgetFallbackRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => WidgetFallbackRecord.t;
}

class WidgetFallbackRecordIncludeList extends _is.IncludeList {
  WidgetFallbackRecordIncludeList._({
    _is.WhereExpressionBuilder<WidgetFallbackRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WidgetFallbackRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => WidgetFallbackRecord.t;
}

class WidgetFallbackRecordRepository {
  const WidgetFallbackRecordRepository._();

  /// Returns a list of [WidgetFallbackRecord]s matching the given query parameters.
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
  Future<List<WidgetFallbackRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetFallbackRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetFallbackRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetFallbackRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WidgetFallbackRecord>(
      where: where?.call(WidgetFallbackRecord.t),
      orderBy: orderBy?.call(WidgetFallbackRecord.t),
      orderByList: orderByList?.call(WidgetFallbackRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WidgetFallbackRecord] matching the given query parameters.
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
  Future<WidgetFallbackRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetFallbackRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<WidgetFallbackRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetFallbackRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WidgetFallbackRecord>(
      where: where?.call(WidgetFallbackRecord.t),
      orderBy: orderBy?.call(WidgetFallbackRecord.t),
      orderByList: orderByList?.call(WidgetFallbackRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WidgetFallbackRecord] by its [id] or null if no such row exists.
  Future<WidgetFallbackRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WidgetFallbackRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WidgetFallbackRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [WidgetFallbackRecord]s will have their `id` fields set.
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
  Future<List<WidgetFallbackRecord>> insert(
    _is.DatabaseSession session,
    List<WidgetFallbackRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<WidgetFallbackRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [WidgetFallbackRecord] and returns the inserted row.
  ///
  /// The returned [WidgetFallbackRecord] will have its `id` field set.
  Future<WidgetFallbackRecord> insertRow(
    _is.DatabaseSession session,
    WidgetFallbackRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<WidgetFallbackRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [WidgetFallbackRecord]s in the list and returns the resulting rows.
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
  /// The returned [WidgetFallbackRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetFallbackRecord>> upsert(
    _is.DatabaseSession session,
    List<WidgetFallbackRecord> rows, {
    required _is.ColumnSelections<WidgetFallbackRecordTable> conflictColumns,
    _is.ColumnSelections<WidgetFallbackRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<WidgetFallbackRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<WidgetFallbackRecord>(
      rows,
      conflictColumns: conflictColumns(WidgetFallbackRecord.t),
      updateColumns: updateColumns?.call(WidgetFallbackRecord.t),
      updateWhere: updateWhere?.call(WidgetFallbackRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [WidgetFallbackRecord] and returns the resulting row.
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
  /// The returned [WidgetFallbackRecord] will have its `id` field set.
  Future<WidgetFallbackRecord?> upsertRow(
    _is.DatabaseSession session,
    WidgetFallbackRecord row, {
    required _is.ColumnSelections<WidgetFallbackRecordTable> conflictColumns,
    _is.ColumnSelections<WidgetFallbackRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<WidgetFallbackRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<WidgetFallbackRecord>(
      row,
      conflictColumns: conflictColumns(WidgetFallbackRecord.t),
      updateColumns: updateColumns?.call(WidgetFallbackRecord.t),
      updateWhere: updateWhere?.call(WidgetFallbackRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [WidgetFallbackRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetFallbackRecord>> update(
    _is.DatabaseSession session,
    List<WidgetFallbackRecord> rows, {
    _is.ColumnSelections<WidgetFallbackRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<WidgetFallbackRecord>(
      rows,
      columns: columns?.call(WidgetFallbackRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [WidgetFallbackRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WidgetFallbackRecord> updateRow(
    _is.DatabaseSession session,
    WidgetFallbackRecord row, {
    _is.ColumnSelections<WidgetFallbackRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<WidgetFallbackRecord>(
      row,
      columns: columns?.call(WidgetFallbackRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WidgetFallbackRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WidgetFallbackRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<WidgetFallbackRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<WidgetFallbackRecord>(
      id,
      columnValues: columnValues(WidgetFallbackRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WidgetFallbackRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetFallbackRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<WidgetFallbackRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<WidgetFallbackRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetFallbackRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetFallbackRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<WidgetFallbackRecord>(
      columnValues: columnValues(WidgetFallbackRecord.t.updateTable),
      where: where(WidgetFallbackRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WidgetFallbackRecord.t),
      orderByList: orderByList?.call(WidgetFallbackRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [WidgetFallbackRecord]s in the list and returns the deleted rows.
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
  Future<List<WidgetFallbackRecord>> delete(
    _is.DatabaseSession session,
    List<WidgetFallbackRecord> rows, {
    _is.OrderByBuilder<WidgetFallbackRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetFallbackRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<WidgetFallbackRecord>(
      rows,
      orderBy: orderBy?.call(WidgetFallbackRecord.t),
      orderByList: orderByList?.call(WidgetFallbackRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [WidgetFallbackRecord].
  Future<WidgetFallbackRecord> deleteRow(
    _is.DatabaseSession session,
    WidgetFallbackRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WidgetFallbackRecord>(
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
  Future<List<WidgetFallbackRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WidgetFallbackRecordTable> where,
    _is.OrderByBuilder<WidgetFallbackRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetFallbackRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<WidgetFallbackRecord>(
      where: where(WidgetFallbackRecord.t),
      orderBy: orderBy?.call(WidgetFallbackRecord.t),
      orderByList: orderByList?.call(WidgetFallbackRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetFallbackRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<WidgetFallbackRecord>(
      where: where?.call(WidgetFallbackRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WidgetFallbackRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WidgetFallbackRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WidgetFallbackRecord>(
      where: where(WidgetFallbackRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
