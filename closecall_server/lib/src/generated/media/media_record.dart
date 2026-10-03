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

abstract class MediaRecord
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  MediaRecord._({
    this.id,
    required this.coupleId,
    required this.uploaderId,
    DateTime? createdAt,
    required this.width,
    required this.height,
    required this.requestId,
    required this.contentHash,
    required this.storagePath,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MediaRecord({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required String uploaderId,
    DateTime? createdAt,
    required int width,
    required int height,
    required String requestId,
    required String contentHash,
    required String storagePath,
  }) = _MediaRecordImpl;

  factory MediaRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return MediaRecord(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      uploaderId: jsonSerialization['uploaderId'] as String,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      width: jsonSerialization['width'] as int,
      height: jsonSerialization['height'] as int,
      requestId: jsonSerialization['requestId'] as String,
      contentHash: jsonSerialization['contentHash'] as String,
      storagePath: jsonSerialization['storagePath'] as String,
    );
  }

  static final t = MediaRecordTable();

  static const db = MediaRecordRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue coupleId;

  String uploaderId;

  DateTime createdAt;

  int width;

  int height;

  String requestId;

  String contentHash;

  String storagePath;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [MediaRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MediaRecord copyWith({
    _is.UuidValue? id,
    _is.UuidValue? coupleId,
    String? uploaderId,
    DateTime? createdAt,
    int? width,
    int? height,
    String? requestId,
    String? contentHash,
    String? storagePath,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MediaRecord',
      if (id != null) 'id': id?.toJson(),
      'coupleId': coupleId.toJson(),
      'uploaderId': uploaderId,
      'createdAt': createdAt.toJson(),
      'width': width,
      'height': height,
      'requestId': requestId,
      'contentHash': contentHash,
      'storagePath': storagePath,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static MediaRecordInclude include() {
    return MediaRecordInclude._();
  }

  static MediaRecordIncludeList includeList({
    _is.WhereExpressionBuilder<MediaRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MediaRecordTable>? orderBy,
    _is.OrderByListBuilder<MediaRecordTable>? orderByList,
    MediaRecordInclude? include,
  }) {
    return MediaRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MediaRecord.t),
      orderByList: orderByList?.call(MediaRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MediaRecordImpl extends MediaRecord {
  _MediaRecordImpl({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required String uploaderId,
    DateTime? createdAt,
    required int width,
    required int height,
    required String requestId,
    required String contentHash,
    required String storagePath,
  }) : super._(
         id: id,
         coupleId: coupleId,
         uploaderId: uploaderId,
         createdAt: createdAt,
         width: width,
         height: height,
         requestId: requestId,
         contentHash: contentHash,
         storagePath: storagePath,
       );

  /// Returns a shallow copy of this [MediaRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MediaRecord copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    String? uploaderId,
    DateTime? createdAt,
    int? width,
    int? height,
    String? requestId,
    String? contentHash,
    String? storagePath,
  }) {
    return MediaRecord(
      id: id is _is.UuidValue? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      uploaderId: uploaderId ?? this.uploaderId,
      createdAt: createdAt ?? this.createdAt,
      width: width ?? this.width,
      height: height ?? this.height,
      requestId: requestId ?? this.requestId,
      contentHash: contentHash ?? this.contentHash,
      storagePath: storagePath ?? this.storagePath,
    );
  }
}

class MediaRecordUpdateTable extends _is.UpdateTable<MediaRecordTable> {
  MediaRecordUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<String, String> uploaderId(String value) =>
      _is.ColumnValue(table.uploaderId, value);

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(table.createdAt, value);

  _is.ColumnValue<int, int> width(int value) =>
      _is.ColumnValue(table.width, value);

  _is.ColumnValue<int, int> height(int value) =>
      _is.ColumnValue(table.height, value);

  _is.ColumnValue<String, String> requestId(String value) =>
      _is.ColumnValue(table.requestId, value);

  _is.ColumnValue<String, String> contentHash(String value) =>
      _is.ColumnValue(table.contentHash, value);

  _is.ColumnValue<String, String> storagePath(String value) =>
      _is.ColumnValue(table.storagePath, value);
}

class MediaRecordTable extends _is.Table<_is.UuidValue?> {
  MediaRecordTable({super.tableRelation})
    : super(tableName: 'closecall_media') {
    updateTable = MediaRecordUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    uploaderId = _is.ColumnString('uploaderId', this);
    createdAt = _is.ColumnDateTime('createdAt', this, hasDefault: true);
    width = _is.ColumnInt('width', this);
    height = _is.ColumnInt('height', this);
    requestId = _is.ColumnString('requestId', this);
    contentHash = _is.ColumnString('contentHash', this);
    storagePath = _is.ColumnString('storagePath', this);
  }

  late final MediaRecordUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnString uploaderId;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnInt width;

  late final _is.ColumnInt height;

  late final _is.ColumnString requestId;

  late final _is.ColumnString contentHash;

  late final _is.ColumnString storagePath;

  @override
  List<_is.Column> get columns => [
    id,
    coupleId,
    uploaderId,
    createdAt,
    width,
    height,
    requestId,
    contentHash,
    storagePath,
  ];
}

class MediaRecordInclude extends _is.IncludeObject {
  MediaRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => MediaRecord.t;
}

class MediaRecordIncludeList extends _is.IncludeList {
  MediaRecordIncludeList._({
    _is.WhereExpressionBuilder<MediaRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(MediaRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => MediaRecord.t;
}

class MediaRecordRepository {
  const MediaRecordRepository._();

  /// Returns a list of [MediaRecord]s matching the given query parameters.
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
  Future<List<MediaRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MediaRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MediaRecordTable>? orderBy,
    _is.OrderByListBuilder<MediaRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<MediaRecord>(
      where: where?.call(MediaRecord.t),
      orderBy: orderBy?.call(MediaRecord.t),
      orderByList: orderByList?.call(MediaRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [MediaRecord] matching the given query parameters.
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
  Future<MediaRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MediaRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<MediaRecordTable>? orderBy,
    _is.OrderByListBuilder<MediaRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<MediaRecord>(
      where: where?.call(MediaRecord.t),
      orderBy: orderBy?.call(MediaRecord.t),
      orderByList: orderByList?.call(MediaRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [MediaRecord] by its [id] or null if no such row exists.
  Future<MediaRecord?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<MediaRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [MediaRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [MediaRecord]s will have their `id` fields set.
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
  Future<List<MediaRecord>> insert(
    _is.DatabaseSession session,
    List<MediaRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<MediaRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [MediaRecord] and returns the inserted row.
  ///
  /// The returned [MediaRecord] will have its `id` field set.
  Future<MediaRecord> insertRow(
    _is.DatabaseSession session,
    MediaRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<MediaRecord>(row, transaction: transaction);
  }

  /// Upserts all [MediaRecord]s in the list and returns the resulting rows.
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
  /// The returned [MediaRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MediaRecord>> upsert(
    _is.DatabaseSession session,
    List<MediaRecord> rows, {
    required _is.ColumnSelections<MediaRecordTable> conflictColumns,
    _is.ColumnSelections<MediaRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<MediaRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<MediaRecord>(
      rows,
      conflictColumns: conflictColumns(MediaRecord.t),
      updateColumns: updateColumns?.call(MediaRecord.t),
      updateWhere: updateWhere?.call(MediaRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [MediaRecord] and returns the resulting row.
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
  /// The returned [MediaRecord] will have its `id` field set.
  Future<MediaRecord?> upsertRow(
    _is.DatabaseSession session,
    MediaRecord row, {
    required _is.ColumnSelections<MediaRecordTable> conflictColumns,
    _is.ColumnSelections<MediaRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<MediaRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<MediaRecord>(
      row,
      conflictColumns: conflictColumns(MediaRecord.t),
      updateColumns: updateColumns?.call(MediaRecord.t),
      updateWhere: updateWhere?.call(MediaRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [MediaRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MediaRecord>> update(
    _is.DatabaseSession session,
    List<MediaRecord> rows, {
    _is.ColumnSelections<MediaRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<MediaRecord>(
      rows,
      columns: columns?.call(MediaRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [MediaRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<MediaRecord> updateRow(
    _is.DatabaseSession session,
    MediaRecord row, {
    _is.ColumnSelections<MediaRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<MediaRecord>(
      row,
      columns: columns?.call(MediaRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MediaRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<MediaRecord?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<MediaRecordUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<MediaRecord>(
      id,
      columnValues: columnValues(MediaRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [MediaRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MediaRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<MediaRecordUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<MediaRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MediaRecordTable>? orderBy,
    _is.OrderByListBuilder<MediaRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<MediaRecord>(
      columnValues: columnValues(MediaRecord.t.updateTable),
      where: where(MediaRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MediaRecord.t),
      orderByList: orderByList?.call(MediaRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [MediaRecord]s in the list and returns the deleted rows.
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
  Future<List<MediaRecord>> delete(
    _is.DatabaseSession session,
    List<MediaRecord> rows, {
    _is.OrderByBuilder<MediaRecordTable>? orderBy,
    _is.OrderByListBuilder<MediaRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<MediaRecord>(
      rows,
      orderBy: orderBy?.call(MediaRecord.t),
      orderByList: orderByList?.call(MediaRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [MediaRecord].
  Future<MediaRecord> deleteRow(
    _is.DatabaseSession session,
    MediaRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<MediaRecord>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MediaRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<MediaRecordTable> where,
    _is.OrderByBuilder<MediaRecordTable>? orderBy,
    _is.OrderByListBuilder<MediaRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<MediaRecord>(
      where: where(MediaRecord.t),
      orderBy: orderBy?.call(MediaRecord.t),
      orderByList: orderByList?.call(MediaRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MediaRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<MediaRecord>(
      where: where?.call(MediaRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [MediaRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<MediaRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<MediaRecord>(
      where: where(MediaRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
