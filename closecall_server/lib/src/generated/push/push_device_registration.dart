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

abstract class PushDeviceRegistration
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  PushDeviceRegistration._({
    this.id,
    required this.coupleId,
    required this.memberId,
    required this.deviceId,
    required this.token,
    this.platform,
    this.appVersion,
    DateTime? updatedAt,
    this.revokedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory PushDeviceRegistration({
    int? id,
    required _is.UuidValue coupleId,
    required int memberId,
    required String deviceId,
    required String token,
    String? platform,
    String? appVersion,
    DateTime? updatedAt,
    DateTime? revokedAt,
  }) = _PushDeviceRegistrationImpl;

  factory PushDeviceRegistration.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PushDeviceRegistration(
      id: jsonSerialization['id'] as int?,
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      memberId: jsonSerialization['memberId'] as int,
      deviceId: jsonSerialization['deviceId'] as String,
      token: jsonSerialization['token'] as String,
      platform: jsonSerialization['platform'] as String?,
      appVersion: jsonSerialization['appVersion'] as String?,
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      revokedAt: jsonSerialization['revokedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['revokedAt']),
    );
  }

  static final t = PushDeviceRegistrationTable();

  static const db = PushDeviceRegistrationRepository._();

  @override
  int? id;

  _is.UuidValue coupleId;

  int memberId;

  String deviceId;

  String token;

  String? platform;

  String? appVersion;

  DateTime updatedAt;

  DateTime? revokedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [PushDeviceRegistration]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PushDeviceRegistration copyWith({
    int? id,
    _is.UuidValue? coupleId,
    int? memberId,
    String? deviceId,
    String? token,
    String? platform,
    String? appVersion,
    DateTime? updatedAt,
    DateTime? revokedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PushDeviceRegistration',
      if (id != null) 'id': id,
      'coupleId': coupleId.toJson(),
      'memberId': memberId,
      'deviceId': deviceId,
      'token': token,
      if (platform != null) 'platform': platform,
      if (appVersion != null) 'appVersion': appVersion,
      'updatedAt': updatedAt.toJson(),
      if (revokedAt != null) 'revokedAt': revokedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static PushDeviceRegistrationInclude include() {
    return PushDeviceRegistrationInclude._();
  }

  static PushDeviceRegistrationIncludeList includeList({
    _is.WhereExpressionBuilder<PushDeviceRegistrationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PushDeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<PushDeviceRegistrationTable>? orderByList,
    PushDeviceRegistrationInclude? include,
  }) {
    return PushDeviceRegistrationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PushDeviceRegistration.t),
      orderByList: orderByList?.call(PushDeviceRegistration.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PushDeviceRegistrationImpl extends PushDeviceRegistration {
  _PushDeviceRegistrationImpl({
    int? id,
    required _is.UuidValue coupleId,
    required int memberId,
    required String deviceId,
    required String token,
    String? platform,
    String? appVersion,
    DateTime? updatedAt,
    DateTime? revokedAt,
  }) : super._(
         id: id,
         coupleId: coupleId,
         memberId: memberId,
         deviceId: deviceId,
         token: token,
         platform: platform,
         appVersion: appVersion,
         updatedAt: updatedAt,
         revokedAt: revokedAt,
       );

  /// Returns a shallow copy of this [PushDeviceRegistration]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PushDeviceRegistration copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    int? memberId,
    String? deviceId,
    String? token,
    Object? platform = _Undefined,
    Object? appVersion = _Undefined,
    DateTime? updatedAt,
    Object? revokedAt = _Undefined,
  }) {
    return PushDeviceRegistration(
      id: id is int? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      memberId: memberId ?? this.memberId,
      deviceId: deviceId ?? this.deviceId,
      token: token ?? this.token,
      platform: platform is String? ? platform : this.platform,
      appVersion: appVersion is String? ? appVersion : this.appVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      revokedAt: revokedAt is DateTime? ? revokedAt : this.revokedAt,
    );
  }
}

class PushDeviceRegistrationUpdateTable
    extends _is.UpdateTable<PushDeviceRegistrationTable> {
  PushDeviceRegistrationUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<int, int> memberId(int value) =>
      _is.ColumnValue(table.memberId, value);

  _is.ColumnValue<String, String> deviceId(String value) =>
      _is.ColumnValue(table.deviceId, value);

  _is.ColumnValue<String, String> token(String value) =>
      _is.ColumnValue(table.token, value);

  _is.ColumnValue<String, String> platform(String? value) =>
      _is.ColumnValue(table.platform, value);

  _is.ColumnValue<String, String> appVersion(String? value) =>
      _is.ColumnValue(table.appVersion, value);

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(table.updatedAt, value);

  _is.ColumnValue<DateTime, DateTime> revokedAt(DateTime? value) =>
      _is.ColumnValue(table.revokedAt, value);
}

class PushDeviceRegistrationTable extends _is.Table<int?> {
  PushDeviceRegistrationTable({super.tableRelation})
    : super(tableName: 'closecall_push_device_registration') {
    updateTable = PushDeviceRegistrationUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    memberId = _is.ColumnInt('memberId', this);
    deviceId = _is.ColumnString('deviceId', this);
    token = _is.ColumnString('token', this);
    platform = _is.ColumnString('platform', this);
    appVersion = _is.ColumnString('appVersion', this);
    updatedAt = _is.ColumnDateTime('updatedAt', this, hasDefault: true);
    revokedAt = _is.ColumnDateTime('revokedAt', this);
  }

  late final PushDeviceRegistrationUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnInt memberId;

  late final _is.ColumnString deviceId;

  late final _is.ColumnString token;

  late final _is.ColumnString platform;

  late final _is.ColumnString appVersion;

  late final _is.ColumnDateTime updatedAt;

  late final _is.ColumnDateTime revokedAt;

  @override
  List<_is.Column> get columns => [
    id,
    coupleId,
    memberId,
    deviceId,
    token,
    platform,
    appVersion,
    updatedAt,
    revokedAt,
  ];
}

class PushDeviceRegistrationInclude extends _is.IncludeObject {
  PushDeviceRegistrationInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => PushDeviceRegistration.t;
}

class PushDeviceRegistrationIncludeList extends _is.IncludeList {
  PushDeviceRegistrationIncludeList._({
    _is.WhereExpressionBuilder<PushDeviceRegistrationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(PushDeviceRegistration.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => PushDeviceRegistration.t;
}

class PushDeviceRegistrationRepository {
  const PushDeviceRegistrationRepository._();

  /// Returns a list of [PushDeviceRegistration]s matching the given query parameters.
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
  Future<List<PushDeviceRegistration>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PushDeviceRegistrationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PushDeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<PushDeviceRegistrationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<PushDeviceRegistration>(
      where: where?.call(PushDeviceRegistration.t),
      orderBy: orderBy?.call(PushDeviceRegistration.t),
      orderByList: orderByList?.call(PushDeviceRegistration.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [PushDeviceRegistration] matching the given query parameters.
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
  Future<PushDeviceRegistration?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PushDeviceRegistrationTable>? where,
    int? offset,
    _is.OrderByBuilder<PushDeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<PushDeviceRegistrationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<PushDeviceRegistration>(
      where: where?.call(PushDeviceRegistration.t),
      orderBy: orderBy?.call(PushDeviceRegistration.t),
      orderByList: orderByList?.call(PushDeviceRegistration.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [PushDeviceRegistration] by its [id] or null if no such row exists.
  Future<PushDeviceRegistration?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<PushDeviceRegistration>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [PushDeviceRegistration]s in the list and returns the inserted rows.
  ///
  /// The returned [PushDeviceRegistration]s will have their `id` fields set.
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
  Future<List<PushDeviceRegistration>> insert(
    _is.DatabaseSession session,
    List<PushDeviceRegistration> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<PushDeviceRegistration>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [PushDeviceRegistration] and returns the inserted row.
  ///
  /// The returned [PushDeviceRegistration] will have its `id` field set.
  Future<PushDeviceRegistration> insertRow(
    _is.DatabaseSession session,
    PushDeviceRegistration row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<PushDeviceRegistration>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [PushDeviceRegistration]s in the list and returns the resulting rows.
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
  /// The returned [PushDeviceRegistration]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushDeviceRegistration>> upsert(
    _is.DatabaseSession session,
    List<PushDeviceRegistration> rows, {
    required _is.ColumnSelections<PushDeviceRegistrationTable> conflictColumns,
    _is.ColumnSelections<PushDeviceRegistrationTable>? updateColumns,
    _is.WhereExpressionBuilder<PushDeviceRegistrationTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<PushDeviceRegistration>(
      rows,
      conflictColumns: conflictColumns(PushDeviceRegistration.t),
      updateColumns: updateColumns?.call(PushDeviceRegistration.t),
      updateWhere: updateWhere?.call(PushDeviceRegistration.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [PushDeviceRegistration] and returns the resulting row.
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
  /// The returned [PushDeviceRegistration] will have its `id` field set.
  Future<PushDeviceRegistration?> upsertRow(
    _is.DatabaseSession session,
    PushDeviceRegistration row, {
    required _is.ColumnSelections<PushDeviceRegistrationTable> conflictColumns,
    _is.ColumnSelections<PushDeviceRegistrationTable>? updateColumns,
    _is.WhereExpressionBuilder<PushDeviceRegistrationTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<PushDeviceRegistration>(
      row,
      conflictColumns: conflictColumns(PushDeviceRegistration.t),
      updateColumns: updateColumns?.call(PushDeviceRegistration.t),
      updateWhere: updateWhere?.call(PushDeviceRegistration.t),
      transaction: transaction,
    );
  }

  /// Updates all [PushDeviceRegistration]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushDeviceRegistration>> update(
    _is.DatabaseSession session,
    List<PushDeviceRegistration> rows, {
    _is.ColumnSelections<PushDeviceRegistrationTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<PushDeviceRegistration>(
      rows,
      columns: columns?.call(PushDeviceRegistration.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [PushDeviceRegistration]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<PushDeviceRegistration> updateRow(
    _is.DatabaseSession session,
    PushDeviceRegistration row, {
    _is.ColumnSelections<PushDeviceRegistrationTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<PushDeviceRegistration>(
      row,
      columns: columns?.call(PushDeviceRegistration.t),
      transaction: transaction,
    );
  }

  /// Updates a single [PushDeviceRegistration] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<PushDeviceRegistration?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<PushDeviceRegistrationUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<PushDeviceRegistration>(
      id,
      columnValues: columnValues(PushDeviceRegistration.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [PushDeviceRegistration]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushDeviceRegistration>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<PushDeviceRegistrationUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<PushDeviceRegistrationTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PushDeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<PushDeviceRegistrationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<PushDeviceRegistration>(
      columnValues: columnValues(PushDeviceRegistration.t.updateTable),
      where: where(PushDeviceRegistration.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PushDeviceRegistration.t),
      orderByList: orderByList?.call(PushDeviceRegistration.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [PushDeviceRegistration]s in the list and returns the deleted rows.
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
  Future<List<PushDeviceRegistration>> delete(
    _is.DatabaseSession session,
    List<PushDeviceRegistration> rows, {
    _is.OrderByBuilder<PushDeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<PushDeviceRegistrationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<PushDeviceRegistration>(
      rows,
      orderBy: orderBy?.call(PushDeviceRegistration.t),
      orderByList: orderByList?.call(PushDeviceRegistration.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [PushDeviceRegistration].
  Future<PushDeviceRegistration> deleteRow(
    _is.DatabaseSession session,
    PushDeviceRegistration row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<PushDeviceRegistration>(
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
  Future<List<PushDeviceRegistration>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PushDeviceRegistrationTable> where,
    _is.OrderByBuilder<PushDeviceRegistrationTable>? orderBy,
    _is.OrderByListBuilder<PushDeviceRegistrationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<PushDeviceRegistration>(
      where: where(PushDeviceRegistration.t),
      orderBy: orderBy?.call(PushDeviceRegistration.t),
      orderByList: orderByList?.call(PushDeviceRegistration.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PushDeviceRegistrationTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<PushDeviceRegistration>(
      where: where?.call(PushDeviceRegistration.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [PushDeviceRegistration] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PushDeviceRegistrationTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<PushDeviceRegistration>(
      where: where(PushDeviceRegistration.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
