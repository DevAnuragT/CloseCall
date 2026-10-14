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

abstract class MomentRecord
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  MomentRecord._({
    this.id,
    required this.coupleId,
    required this.authorMemberId,
    required this.authorId,
    required this.text,
    required this.kind,
    this.durationMs,
    DateTime? createdAt,
    required this.requestId,
    required this.contentHash,
    this.storagePath,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MomentRecord({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required int authorMemberId,
    required String authorId,
    required String text,
    required String kind,
    int? durationMs,
    DateTime? createdAt,
    required String requestId,
    required String contentHash,
    String? storagePath,
    DateTime? deletedAt,
  }) = _MomentRecordImpl;

  factory MomentRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return MomentRecord(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      authorMemberId: jsonSerialization['authorMemberId'] as int,
      authorId: jsonSerialization['authorId'] as String,
      text: jsonSerialization['text'] as String,
      kind: jsonSerialization['kind'] as String,
      durationMs: jsonSerialization['durationMs'] as int?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      requestId: jsonSerialization['requestId'] as String,
      contentHash: jsonSerialization['contentHash'] as String,
      storagePath: jsonSerialization['storagePath'] as String?,
      deletedAt: jsonSerialization['deletedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['deletedAt']),
    );
  }

  static final t = MomentRecordTable();

  static const db = MomentRecordRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue coupleId;

  int authorMemberId;

  String authorId;

  String text;

  String kind;

  int? durationMs;

  DateTime createdAt;

  String requestId;

  String contentHash;

  String? storagePath;

  DateTime? deletedAt;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [MomentRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MomentRecord copyWith({
    _is.UuidValue? id,
    _is.UuidValue? coupleId,
    int? authorMemberId,
    String? authorId,
    String? text,
    String? kind,
    int? durationMs,
    DateTime? createdAt,
    String? requestId,
    String? contentHash,
    String? storagePath,
    DateTime? deletedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MomentRecord',
      if (id != null) 'id': id?.toJson(),
      'coupleId': coupleId.toJson(),
      'authorMemberId': authorMemberId,
      'authorId': authorId,
      'text': text,
      'kind': kind,
      if (durationMs != null) 'durationMs': durationMs,
      'createdAt': createdAt.toJson(),
      'requestId': requestId,
      'contentHash': contentHash,
      if (storagePath != null) 'storagePath': storagePath,
      if (deletedAt != null) 'deletedAt': deletedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static MomentRecordInclude include() {
    return MomentRecordInclude._();
  }

  static MomentRecordIncludeList includeList({
    _is.WhereExpressionBuilder<MomentRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MomentRecordTable>? orderBy,
    _is.OrderByListBuilder<MomentRecordTable>? orderByList,
    MomentRecordInclude? include,
  }) {
    return MomentRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MomentRecord.t),
      orderByList: orderByList?.call(MomentRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MomentRecordImpl extends MomentRecord {
  _MomentRecordImpl({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required int authorMemberId,
    required String authorId,
    required String text,
    required String kind,
    int? durationMs,
    DateTime? createdAt,
    required String requestId,
    required String contentHash,
    String? storagePath,
    DateTime? deletedAt,
  }) : super._(
         id: id,
         coupleId: coupleId,
         authorMemberId: authorMemberId,
         authorId: authorId,
         text: text,
         kind: kind,
         durationMs: durationMs,
         createdAt: createdAt,
         requestId: requestId,
         contentHash: contentHash,
         storagePath: storagePath,
         deletedAt: deletedAt,
       );

  /// Returns a shallow copy of this [MomentRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MomentRecord copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    int? authorMemberId,
    String? authorId,
    String? text,
    String? kind,
    Object? durationMs = _Undefined,
    DateTime? createdAt,
    String? requestId,
    String? contentHash,
    Object? storagePath = _Undefined,
    Object? deletedAt = _Undefined,
  }) {
    return MomentRecord(
      id: id is _is.UuidValue? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      authorMemberId: authorMemberId ?? this.authorMemberId,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      kind: kind ?? this.kind,
      durationMs: durationMs is int? ? durationMs : this.durationMs,
      createdAt: createdAt ?? this.createdAt,
      requestId: requestId ?? this.requestId,
      contentHash: contentHash ?? this.contentHash,
      storagePath: storagePath is String? ? storagePath : this.storagePath,
      deletedAt: deletedAt is DateTime? ? deletedAt : this.deletedAt,
    );
  }
}

class MomentRecordUpdateTable extends _is.UpdateTable<MomentRecordTable> {
  MomentRecordUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<int, int> authorMemberId(int value) =>
      _is.ColumnValue(table.authorMemberId, value);

  _is.ColumnValue<String, String> authorId(String value) =>
      _is.ColumnValue(table.authorId, value);

  _is.ColumnValue<String, String> text(String value) =>
      _is.ColumnValue(table.text, value);

  _is.ColumnValue<String, String> kind(String value) =>
      _is.ColumnValue(table.kind, value);

  _is.ColumnValue<int, int> durationMs(int? value) =>
      _is.ColumnValue(table.durationMs, value);

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(table.createdAt, value);

  _is.ColumnValue<String, String> requestId(String value) =>
      _is.ColumnValue(table.requestId, value);

  _is.ColumnValue<String, String> contentHash(String value) =>
      _is.ColumnValue(table.contentHash, value);

  _is.ColumnValue<String, String> storagePath(String? value) =>
      _is.ColumnValue(table.storagePath, value);

  _is.ColumnValue<DateTime, DateTime> deletedAt(DateTime? value) =>
      _is.ColumnValue(table.deletedAt, value);
}

class MomentRecordTable extends _is.Table<_is.UuidValue?> {
  MomentRecordTable({super.tableRelation})
    : super(tableName: 'closecall_moment') {
    updateTable = MomentRecordUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    authorMemberId = _is.ColumnInt('authorMemberId', this);
    authorId = _is.ColumnString('authorId', this);
    text = _is.ColumnString('text', this);
    kind = _is.ColumnString('kind', this);
    durationMs = _is.ColumnInt('durationMs', this);
    createdAt = _is.ColumnDateTime('createdAt', this, hasDefault: true);
    requestId = _is.ColumnString('requestId', this);
    contentHash = _is.ColumnString('contentHash', this);
    storagePath = _is.ColumnString('storagePath', this);
    deletedAt = _is.ColumnDateTime('deletedAt', this);
  }

  late final MomentRecordUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnInt authorMemberId;

  late final _is.ColumnString authorId;

  late final _is.ColumnString text;

  late final _is.ColumnString kind;

  late final _is.ColumnInt durationMs;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnString requestId;

  late final _is.ColumnString contentHash;

  late final _is.ColumnString storagePath;

  late final _is.ColumnDateTime deletedAt;

  @override
  List<_is.Column> get columns => [
    id,
    coupleId,
    authorMemberId,
    authorId,
    text,
    kind,
    durationMs,
    createdAt,
    requestId,
    contentHash,
    storagePath,
    deletedAt,
  ];
}

class MomentRecordInclude extends _is.IncludeObject {
  MomentRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => MomentRecord.t;
}

class MomentRecordIncludeList extends _is.IncludeList {
  MomentRecordIncludeList._({
    _is.WhereExpressionBuilder<MomentRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(MomentRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => MomentRecord.t;
}

class MomentRecordRepository {
  const MomentRecordRepository._();

  /// Returns a list of [MomentRecord]s matching the given query parameters.
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
  Future<List<MomentRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MomentRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MomentRecordTable>? orderBy,
    _is.OrderByListBuilder<MomentRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<MomentRecord>(
      where: where?.call(MomentRecord.t),
      orderBy: orderBy?.call(MomentRecord.t),
      orderByList: orderByList?.call(MomentRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [MomentRecord] matching the given query parameters.
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
  Future<MomentRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MomentRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<MomentRecordTable>? orderBy,
    _is.OrderByListBuilder<MomentRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<MomentRecord>(
      where: where?.call(MomentRecord.t),
      orderBy: orderBy?.call(MomentRecord.t),
      orderByList: orderByList?.call(MomentRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [MomentRecord] by its [id] or null if no such row exists.
  Future<MomentRecord?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<MomentRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [MomentRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [MomentRecord]s will have their `id` fields set.
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
  Future<List<MomentRecord>> insert(
    _is.DatabaseSession session,
    List<MomentRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<MomentRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [MomentRecord] and returns the inserted row.
  ///
  /// The returned [MomentRecord] will have its `id` field set.
  Future<MomentRecord> insertRow(
    _is.DatabaseSession session,
    MomentRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<MomentRecord>(row, transaction: transaction);
  }

  /// Upserts all [MomentRecord]s in the list and returns the resulting rows.
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
  /// The returned [MomentRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MomentRecord>> upsert(
    _is.DatabaseSession session,
    List<MomentRecord> rows, {
    required _is.ColumnSelections<MomentRecordTable> conflictColumns,
    _is.ColumnSelections<MomentRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<MomentRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<MomentRecord>(
      rows,
      conflictColumns: conflictColumns(MomentRecord.t),
      updateColumns: updateColumns?.call(MomentRecord.t),
      updateWhere: updateWhere?.call(MomentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [MomentRecord] and returns the resulting row.
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
  /// The returned [MomentRecord] will have its `id` field set.
  Future<MomentRecord?> upsertRow(
    _is.DatabaseSession session,
    MomentRecord row, {
    required _is.ColumnSelections<MomentRecordTable> conflictColumns,
    _is.ColumnSelections<MomentRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<MomentRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<MomentRecord>(
      row,
      conflictColumns: conflictColumns(MomentRecord.t),
      updateColumns: updateColumns?.call(MomentRecord.t),
      updateWhere: updateWhere?.call(MomentRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [MomentRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MomentRecord>> update(
    _is.DatabaseSession session,
    List<MomentRecord> rows, {
    _is.ColumnSelections<MomentRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<MomentRecord>(
      rows,
      columns: columns?.call(MomentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [MomentRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<MomentRecord> updateRow(
    _is.DatabaseSession session,
    MomentRecord row, {
    _is.ColumnSelections<MomentRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<MomentRecord>(
      row,
      columns: columns?.call(MomentRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MomentRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<MomentRecord?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<MomentRecordUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<MomentRecord>(
      id,
      columnValues: columnValues(MomentRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [MomentRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MomentRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<MomentRecordUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<MomentRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MomentRecordTable>? orderBy,
    _is.OrderByListBuilder<MomentRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<MomentRecord>(
      columnValues: columnValues(MomentRecord.t.updateTable),
      where: where(MomentRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MomentRecord.t),
      orderByList: orderByList?.call(MomentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [MomentRecord]s in the list and returns the deleted rows.
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
  Future<List<MomentRecord>> delete(
    _is.DatabaseSession session,
    List<MomentRecord> rows, {
    _is.OrderByBuilder<MomentRecordTable>? orderBy,
    _is.OrderByListBuilder<MomentRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<MomentRecord>(
      rows,
      orderBy: orderBy?.call(MomentRecord.t),
      orderByList: orderByList?.call(MomentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [MomentRecord].
  Future<MomentRecord> deleteRow(
    _is.DatabaseSession session,
    MomentRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<MomentRecord>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MomentRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<MomentRecordTable> where,
    _is.OrderByBuilder<MomentRecordTable>? orderBy,
    _is.OrderByListBuilder<MomentRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<MomentRecord>(
      where: where(MomentRecord.t),
      orderBy: orderBy?.call(MomentRecord.t),
      orderByList: orderByList?.call(MomentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MomentRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<MomentRecord>(
      where: where?.call(MomentRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [MomentRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<MomentRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<MomentRecord>(
      where: where(MomentRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
