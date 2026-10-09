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

abstract class WidgetDeviceCredentialRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  WidgetDeviceCredentialRecord._({
    this.id,
    required this.coupleId,
    required this.memberId,
    required this.userIdentifier,
    required this.deviceId,
    required this.credentialHash,
    required this.createdAt,
    required this.expiresAt,
  });

  factory WidgetDeviceCredentialRecord({
    int? id,
    required _is.UuidValue coupleId,
    required int memberId,
    required String userIdentifier,
    required String deviceId,
    required String credentialHash,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) = _WidgetDeviceCredentialRecordImpl;

  factory WidgetDeviceCredentialRecord.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WidgetDeviceCredentialRecord(
      id: jsonSerialization['id'] as int?,
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      memberId: jsonSerialization['memberId'] as int,
      userIdentifier: jsonSerialization['userIdentifier'] as String,
      deviceId: jsonSerialization['deviceId'] as String,
      credentialHash: jsonSerialization['credentialHash'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  static final t = WidgetDeviceCredentialRecordTable();

  static const db = WidgetDeviceCredentialRecordRepository._();

  @override
  int? id;

  _is.UuidValue coupleId;

  int memberId;

  String userIdentifier;

  String deviceId;

  String credentialHash;

  DateTime createdAt;

  DateTime expiresAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [WidgetDeviceCredentialRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WidgetDeviceCredentialRecord copyWith({
    int? id,
    _is.UuidValue? coupleId,
    int? memberId,
    String? userIdentifier,
    String? deviceId,
    String? credentialHash,
    DateTime? createdAt,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WidgetDeviceCredentialRecord',
      if (id != null) 'id': id,
      'coupleId': coupleId.toJson(),
      'memberId': memberId,
      'userIdentifier': userIdentifier,
      'deviceId': deviceId,
      'credentialHash': credentialHash,
      'createdAt': createdAt.toJson(),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WidgetDeviceCredentialRecordInclude include() {
    return WidgetDeviceCredentialRecordInclude._();
  }

  static WidgetDeviceCredentialRecordIncludeList includeList({
    _is.WhereExpressionBuilder<WidgetDeviceCredentialRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetDeviceCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeviceCredentialRecordTable>? orderByList,
    WidgetDeviceCredentialRecordInclude? include,
  }) {
    return WidgetDeviceCredentialRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WidgetDeviceCredentialRecord.t),
      orderByList: orderByList?.call(WidgetDeviceCredentialRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WidgetDeviceCredentialRecordImpl extends WidgetDeviceCredentialRecord {
  _WidgetDeviceCredentialRecordImpl({
    int? id,
    required _is.UuidValue coupleId,
    required int memberId,
    required String userIdentifier,
    required String deviceId,
    required String credentialHash,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) : super._(
         id: id,
         coupleId: coupleId,
         memberId: memberId,
         userIdentifier: userIdentifier,
         deviceId: deviceId,
         credentialHash: credentialHash,
         createdAt: createdAt,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [WidgetDeviceCredentialRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WidgetDeviceCredentialRecord copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    int? memberId,
    String? userIdentifier,
    String? deviceId,
    String? credentialHash,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return WidgetDeviceCredentialRecord(
      id: id is int? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      memberId: memberId ?? this.memberId,
      userIdentifier: userIdentifier ?? this.userIdentifier,
      deviceId: deviceId ?? this.deviceId,
      credentialHash: credentialHash ?? this.credentialHash,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

class WidgetDeviceCredentialRecordUpdateTable
    extends _is.UpdateTable<WidgetDeviceCredentialRecordTable> {
  WidgetDeviceCredentialRecordUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<int, int> memberId(int value) =>
      _is.ColumnValue(table.memberId, value);

  _is.ColumnValue<String, String> userIdentifier(String value) =>
      _is.ColumnValue(table.userIdentifier, value);

  _is.ColumnValue<String, String> deviceId(String value) =>
      _is.ColumnValue(table.deviceId, value);

  _is.ColumnValue<String, String> credentialHash(String value) =>
      _is.ColumnValue(table.credentialHash, value);

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(table.createdAt, value);

  _is.ColumnValue<DateTime, DateTime> expiresAt(DateTime value) =>
      _is.ColumnValue(table.expiresAt, value);
}

class WidgetDeviceCredentialRecordTable extends _is.Table<int?> {
  WidgetDeviceCredentialRecordTable({super.tableRelation})
    : super(tableName: 'closecall_widget_device_credential') {
    updateTable = WidgetDeviceCredentialRecordUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    memberId = _is.ColumnInt('memberId', this);
    userIdentifier = _is.ColumnString('userIdentifier', this);
    deviceId = _is.ColumnString('deviceId', this);
    credentialHash = _is.ColumnString('credentialHash', this);
    createdAt = _is.ColumnDateTime('createdAt', this);
    expiresAt = _is.ColumnDateTime('expiresAt', this);
  }

  late final WidgetDeviceCredentialRecordUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnInt memberId;

  late final _is.ColumnString userIdentifier;

  late final _is.ColumnString deviceId;

  late final _is.ColumnString credentialHash;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime expiresAt;

  @override
  List<_is.Column> get columns => [
    id,
    coupleId,
    memberId,
    userIdentifier,
    deviceId,
    credentialHash,
    createdAt,
    expiresAt,
  ];
}

class WidgetDeviceCredentialRecordInclude extends _is.IncludeObject {
  WidgetDeviceCredentialRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => WidgetDeviceCredentialRecord.t;
}

class WidgetDeviceCredentialRecordIncludeList extends _is.IncludeList {
  WidgetDeviceCredentialRecordIncludeList._({
    _is.WhereExpressionBuilder<WidgetDeviceCredentialRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WidgetDeviceCredentialRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => WidgetDeviceCredentialRecord.t;
}

class WidgetDeviceCredentialRecordRepository {
  const WidgetDeviceCredentialRecordRepository._();

  /// Returns a list of [WidgetDeviceCredentialRecord]s matching the given query parameters.
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
  Future<List<WidgetDeviceCredentialRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetDeviceCredentialRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetDeviceCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeviceCredentialRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WidgetDeviceCredentialRecord>(
      where: where?.call(WidgetDeviceCredentialRecord.t),
      orderBy: orderBy?.call(WidgetDeviceCredentialRecord.t),
      orderByList: orderByList?.call(WidgetDeviceCredentialRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WidgetDeviceCredentialRecord] matching the given query parameters.
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
  Future<WidgetDeviceCredentialRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetDeviceCredentialRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<WidgetDeviceCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeviceCredentialRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WidgetDeviceCredentialRecord>(
      where: where?.call(WidgetDeviceCredentialRecord.t),
      orderBy: orderBy?.call(WidgetDeviceCredentialRecord.t),
      orderByList: orderByList?.call(WidgetDeviceCredentialRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WidgetDeviceCredentialRecord] by its [id] or null if no such row exists.
  Future<WidgetDeviceCredentialRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WidgetDeviceCredentialRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WidgetDeviceCredentialRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [WidgetDeviceCredentialRecord]s will have their `id` fields set.
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
  Future<List<WidgetDeviceCredentialRecord>> insert(
    _is.DatabaseSession session,
    List<WidgetDeviceCredentialRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<WidgetDeviceCredentialRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [WidgetDeviceCredentialRecord] and returns the inserted row.
  ///
  /// The returned [WidgetDeviceCredentialRecord] will have its `id` field set.
  Future<WidgetDeviceCredentialRecord> insertRow(
    _is.DatabaseSession session,
    WidgetDeviceCredentialRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<WidgetDeviceCredentialRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [WidgetDeviceCredentialRecord]s in the list and returns the resulting rows.
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
  /// The returned [WidgetDeviceCredentialRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetDeviceCredentialRecord>> upsert(
    _is.DatabaseSession session,
    List<WidgetDeviceCredentialRecord> rows, {
    required _is.ColumnSelections<WidgetDeviceCredentialRecordTable>
    conflictColumns,
    _is.ColumnSelections<WidgetDeviceCredentialRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<WidgetDeviceCredentialRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<WidgetDeviceCredentialRecord>(
      rows,
      conflictColumns: conflictColumns(WidgetDeviceCredentialRecord.t),
      updateColumns: updateColumns?.call(WidgetDeviceCredentialRecord.t),
      updateWhere: updateWhere?.call(WidgetDeviceCredentialRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [WidgetDeviceCredentialRecord] and returns the resulting row.
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
  /// The returned [WidgetDeviceCredentialRecord] will have its `id` field set.
  Future<WidgetDeviceCredentialRecord?> upsertRow(
    _is.DatabaseSession session,
    WidgetDeviceCredentialRecord row, {
    required _is.ColumnSelections<WidgetDeviceCredentialRecordTable>
    conflictColumns,
    _is.ColumnSelections<WidgetDeviceCredentialRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<WidgetDeviceCredentialRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<WidgetDeviceCredentialRecord>(
      row,
      conflictColumns: conflictColumns(WidgetDeviceCredentialRecord.t),
      updateColumns: updateColumns?.call(WidgetDeviceCredentialRecord.t),
      updateWhere: updateWhere?.call(WidgetDeviceCredentialRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [WidgetDeviceCredentialRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetDeviceCredentialRecord>> update(
    _is.DatabaseSession session,
    List<WidgetDeviceCredentialRecord> rows, {
    _is.ColumnSelections<WidgetDeviceCredentialRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<WidgetDeviceCredentialRecord>(
      rows,
      columns: columns?.call(WidgetDeviceCredentialRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [WidgetDeviceCredentialRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WidgetDeviceCredentialRecord> updateRow(
    _is.DatabaseSession session,
    WidgetDeviceCredentialRecord row, {
    _is.ColumnSelections<WidgetDeviceCredentialRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<WidgetDeviceCredentialRecord>(
      row,
      columns: columns?.call(WidgetDeviceCredentialRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WidgetDeviceCredentialRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WidgetDeviceCredentialRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<WidgetDeviceCredentialRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<WidgetDeviceCredentialRecord>(
      id,
      columnValues: columnValues(WidgetDeviceCredentialRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WidgetDeviceCredentialRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WidgetDeviceCredentialRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<WidgetDeviceCredentialRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<WidgetDeviceCredentialRecordTable>
    where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WidgetDeviceCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeviceCredentialRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<WidgetDeviceCredentialRecord>(
      columnValues: columnValues(WidgetDeviceCredentialRecord.t.updateTable),
      where: where(WidgetDeviceCredentialRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WidgetDeviceCredentialRecord.t),
      orderByList: orderByList?.call(WidgetDeviceCredentialRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [WidgetDeviceCredentialRecord]s in the list and returns the deleted rows.
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
  Future<List<WidgetDeviceCredentialRecord>> delete(
    _is.DatabaseSession session,
    List<WidgetDeviceCredentialRecord> rows, {
    _is.OrderByBuilder<WidgetDeviceCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeviceCredentialRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<WidgetDeviceCredentialRecord>(
      rows,
      orderBy: orderBy?.call(WidgetDeviceCredentialRecord.t),
      orderByList: orderByList?.call(WidgetDeviceCredentialRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [WidgetDeviceCredentialRecord].
  Future<WidgetDeviceCredentialRecord> deleteRow(
    _is.DatabaseSession session,
    WidgetDeviceCredentialRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WidgetDeviceCredentialRecord>(
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
  Future<List<WidgetDeviceCredentialRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WidgetDeviceCredentialRecordTable>
    where,
    _is.OrderByBuilder<WidgetDeviceCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<WidgetDeviceCredentialRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<WidgetDeviceCredentialRecord>(
      where: where(WidgetDeviceCredentialRecord.t),
      orderBy: orderBy?.call(WidgetDeviceCredentialRecord.t),
      orderByList: orderByList?.call(WidgetDeviceCredentialRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WidgetDeviceCredentialRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<WidgetDeviceCredentialRecord>(
      where: where?.call(WidgetDeviceCredentialRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WidgetDeviceCredentialRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WidgetDeviceCredentialRecordTable>
    where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WidgetDeviceCredentialRecord>(
      where: where(WidgetDeviceCredentialRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
