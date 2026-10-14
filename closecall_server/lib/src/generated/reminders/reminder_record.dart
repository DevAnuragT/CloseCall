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

abstract class ReminderRecord
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  ReminderRecord._({
    this.id,
    required this.coupleId,
    required this.creatorMemberId,
    required this.creatorId,
    required this.title,
    required this.kind,
    required this.remindAt,
    this.completedAt,
    DateTime? createdAt,
    required this.requestId,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ReminderRecord({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required int creatorMemberId,
    required String creatorId,
    required String title,
    required String kind,
    required DateTime remindAt,
    DateTime? completedAt,
    DateTime? createdAt,
    required String requestId,
  }) = _ReminderRecordImpl;

  factory ReminderRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return ReminderRecord(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      creatorMemberId: jsonSerialization['creatorMemberId'] as int,
      creatorId: jsonSerialization['creatorId'] as String,
      title: jsonSerialization['title'] as String,
      kind: jsonSerialization['kind'] as String,
      remindAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['remindAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      requestId: jsonSerialization['requestId'] as String,
    );
  }

  static final t = ReminderRecordTable();

  static const db = ReminderRecordRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue coupleId;

  int creatorMemberId;

  String creatorId;

  String title;

  String kind;

  DateTime remindAt;

  DateTime? completedAt;

  DateTime createdAt;

  String requestId;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [ReminderRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ReminderRecord copyWith({
    _is.UuidValue? id,
    _is.UuidValue? coupleId,
    int? creatorMemberId,
    String? creatorId,
    String? title,
    String? kind,
    DateTime? remindAt,
    DateTime? completedAt,
    DateTime? createdAt,
    String? requestId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ReminderRecord',
      if (id != null) 'id': id?.toJson(),
      'coupleId': coupleId.toJson(),
      'creatorMemberId': creatorMemberId,
      'creatorId': creatorId,
      'title': title,
      'kind': kind,
      'remindAt': remindAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      'createdAt': createdAt.toJson(),
      'requestId': requestId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ReminderRecordInclude include() {
    return ReminderRecordInclude._();
  }

  static ReminderRecordIncludeList includeList({
    _is.WhereExpressionBuilder<ReminderRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ReminderRecordTable>? orderBy,
    _is.OrderByListBuilder<ReminderRecordTable>? orderByList,
    ReminderRecordInclude? include,
  }) {
    return ReminderRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ReminderRecord.t),
      orderByList: orderByList?.call(ReminderRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ReminderRecordImpl extends ReminderRecord {
  _ReminderRecordImpl({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required int creatorMemberId,
    required String creatorId,
    required String title,
    required String kind,
    required DateTime remindAt,
    DateTime? completedAt,
    DateTime? createdAt,
    required String requestId,
  }) : super._(
         id: id,
         coupleId: coupleId,
         creatorMemberId: creatorMemberId,
         creatorId: creatorId,
         title: title,
         kind: kind,
         remindAt: remindAt,
         completedAt: completedAt,
         createdAt: createdAt,
         requestId: requestId,
       );

  /// Returns a shallow copy of this [ReminderRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ReminderRecord copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    int? creatorMemberId,
    String? creatorId,
    String? title,
    String? kind,
    DateTime? remindAt,
    Object? completedAt = _Undefined,
    DateTime? createdAt,
    String? requestId,
  }) {
    return ReminderRecord(
      id: id is _is.UuidValue? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      creatorMemberId: creatorMemberId ?? this.creatorMemberId,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      remindAt: remindAt ?? this.remindAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      requestId: requestId ?? this.requestId,
    );
  }
}

class ReminderRecordUpdateTable extends _is.UpdateTable<ReminderRecordTable> {
  ReminderRecordUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<int, int> creatorMemberId(int value) =>
      _is.ColumnValue(table.creatorMemberId, value);

  _is.ColumnValue<String, String> creatorId(String value) =>
      _is.ColumnValue(table.creatorId, value);

  _is.ColumnValue<String, String> title(String value) =>
      _is.ColumnValue(table.title, value);

  _is.ColumnValue<String, String> kind(String value) =>
      _is.ColumnValue(table.kind, value);

  _is.ColumnValue<DateTime, DateTime> remindAt(DateTime value) =>
      _is.ColumnValue(table.remindAt, value);

  _is.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _is.ColumnValue(table.completedAt, value);

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(table.createdAt, value);

  _is.ColumnValue<String, String> requestId(String value) =>
      _is.ColumnValue(table.requestId, value);
}

class ReminderRecordTable extends _is.Table<_is.UuidValue?> {
  ReminderRecordTable({super.tableRelation})
    : super(tableName: 'closecall_reminder') {
    updateTable = ReminderRecordUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    creatorMemberId = _is.ColumnInt('creatorMemberId', this);
    creatorId = _is.ColumnString('creatorId', this);
    title = _is.ColumnString('title', this);
    kind = _is.ColumnString('kind', this);
    remindAt = _is.ColumnDateTime('remindAt', this);
    completedAt = _is.ColumnDateTime('completedAt', this);
    createdAt = _is.ColumnDateTime('createdAt', this, hasDefault: true);
    requestId = _is.ColumnString('requestId', this);
  }

  late final ReminderRecordUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnInt creatorMemberId;

  late final _is.ColumnString creatorId;

  late final _is.ColumnString title;

  late final _is.ColumnString kind;

  late final _is.ColumnDateTime remindAt;

  late final _is.ColumnDateTime completedAt;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnString requestId;

  @override
  List<_is.Column> get columns => [
    id,
    coupleId,
    creatorMemberId,
    creatorId,
    title,
    kind,
    remindAt,
    completedAt,
    createdAt,
    requestId,
  ];
}

class ReminderRecordInclude extends _is.IncludeObject {
  ReminderRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => ReminderRecord.t;
}

class ReminderRecordIncludeList extends _is.IncludeList {
  ReminderRecordIncludeList._({
    _is.WhereExpressionBuilder<ReminderRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ReminderRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => ReminderRecord.t;
}

class ReminderRecordRepository {
  const ReminderRecordRepository._();

  /// Returns a list of [ReminderRecord]s matching the given query parameters.
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
  Future<List<ReminderRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ReminderRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ReminderRecordTable>? orderBy,
    _is.OrderByListBuilder<ReminderRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ReminderRecord>(
      where: where?.call(ReminderRecord.t),
      orderBy: orderBy?.call(ReminderRecord.t),
      orderByList: orderByList?.call(ReminderRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ReminderRecord] matching the given query parameters.
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
  Future<ReminderRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ReminderRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<ReminderRecordTable>? orderBy,
    _is.OrderByListBuilder<ReminderRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ReminderRecord>(
      where: where?.call(ReminderRecord.t),
      orderBy: orderBy?.call(ReminderRecord.t),
      orderByList: orderByList?.call(ReminderRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ReminderRecord] by its [id] or null if no such row exists.
  Future<ReminderRecord?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ReminderRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ReminderRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [ReminderRecord]s will have their `id` fields set.
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
  Future<List<ReminderRecord>> insert(
    _is.DatabaseSession session,
    List<ReminderRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ReminderRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ReminderRecord] and returns the inserted row.
  ///
  /// The returned [ReminderRecord] will have its `id` field set.
  Future<ReminderRecord> insertRow(
    _is.DatabaseSession session,
    ReminderRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<ReminderRecord>(row, transaction: transaction);
  }

  /// Upserts all [ReminderRecord]s in the list and returns the resulting rows.
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
  /// The returned [ReminderRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ReminderRecord>> upsert(
    _is.DatabaseSession session,
    List<ReminderRecord> rows, {
    required _is.ColumnSelections<ReminderRecordTable> conflictColumns,
    _is.ColumnSelections<ReminderRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<ReminderRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ReminderRecord>(
      rows,
      conflictColumns: conflictColumns(ReminderRecord.t),
      updateColumns: updateColumns?.call(ReminderRecord.t),
      updateWhere: updateWhere?.call(ReminderRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ReminderRecord] and returns the resulting row.
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
  /// The returned [ReminderRecord] will have its `id` field set.
  Future<ReminderRecord?> upsertRow(
    _is.DatabaseSession session,
    ReminderRecord row, {
    required _is.ColumnSelections<ReminderRecordTable> conflictColumns,
    _is.ColumnSelections<ReminderRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<ReminderRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ReminderRecord>(
      row,
      conflictColumns: conflictColumns(ReminderRecord.t),
      updateColumns: updateColumns?.call(ReminderRecord.t),
      updateWhere: updateWhere?.call(ReminderRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [ReminderRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ReminderRecord>> update(
    _is.DatabaseSession session,
    List<ReminderRecord> rows, {
    _is.ColumnSelections<ReminderRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ReminderRecord>(
      rows,
      columns: columns?.call(ReminderRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ReminderRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ReminderRecord> updateRow(
    _is.DatabaseSession session,
    ReminderRecord row, {
    _is.ColumnSelections<ReminderRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<ReminderRecord>(
      row,
      columns: columns?.call(ReminderRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ReminderRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ReminderRecord?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<ReminderRecordUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<ReminderRecord>(
      id,
      columnValues: columnValues(ReminderRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ReminderRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ReminderRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<ReminderRecordUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<ReminderRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ReminderRecordTable>? orderBy,
    _is.OrderByListBuilder<ReminderRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ReminderRecord>(
      columnValues: columnValues(ReminderRecord.t.updateTable),
      where: where(ReminderRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ReminderRecord.t),
      orderByList: orderByList?.call(ReminderRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ReminderRecord]s in the list and returns the deleted rows.
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
  Future<List<ReminderRecord>> delete(
    _is.DatabaseSession session,
    List<ReminderRecord> rows, {
    _is.OrderByBuilder<ReminderRecordTable>? orderBy,
    _is.OrderByListBuilder<ReminderRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ReminderRecord>(
      rows,
      orderBy: orderBy?.call(ReminderRecord.t),
      orderByList: orderByList?.call(ReminderRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ReminderRecord].
  Future<ReminderRecord> deleteRow(
    _is.DatabaseSession session,
    ReminderRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ReminderRecord>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ReminderRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ReminderRecordTable> where,
    _is.OrderByBuilder<ReminderRecordTable>? orderBy,
    _is.OrderByListBuilder<ReminderRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ReminderRecord>(
      where: where(ReminderRecord.t),
      orderBy: orderBy?.call(ReminderRecord.t),
      orderByList: orderByList?.call(ReminderRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ReminderRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<ReminderRecord>(
      where: where?.call(ReminderRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ReminderRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ReminderRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ReminderRecord>(
      where: where(ReminderRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
