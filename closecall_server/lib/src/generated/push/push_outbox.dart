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

abstract class PushOutbox
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  PushOutbox._({
    this.id,
    required this.coupleId,
    required this.sendId,
    required this.recipientMemberId,
    required this.version,
    DateTime? createdAt,
    int? attempts,
    DateTime? availableAt,
    this.leasedUntil,
    this.leaseOwner,
    this.completedAt,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now(),
       attempts = attempts ?? 0,
       availableAt = availableAt ?? DateTime.now();

  factory PushOutbox({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required _is.UuidValue sendId,
    required int recipientMemberId,
    required int version,
    DateTime? createdAt,
    int? attempts,
    DateTime? availableAt,
    DateTime? leasedUntil,
    String? leaseOwner,
    DateTime? completedAt,
    String? lastError,
  }) = _PushOutboxImpl;

  factory PushOutbox.fromJson(Map<String, dynamic> jsonSerialization) {
    return PushOutbox(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      sendId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['sendId']),
      recipientMemberId: jsonSerialization['recipientMemberId'] as int,
      version: jsonSerialization['version'] as int,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      attempts: jsonSerialization['attempts'] as int?,
      availableAt: jsonSerialization['availableAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['availableAt'],
            ),
      leasedUntil: jsonSerialization['leasedUntil'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['leasedUntil'],
            ),
      leaseOwner: jsonSerialization['leaseOwner'] as String?,
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      lastError: jsonSerialization['lastError'] as String?,
    );
  }

  static final t = PushOutboxTable();

  static const db = PushOutboxRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue coupleId;

  _is.UuidValue sendId;

  int recipientMemberId;

  int version;

  DateTime createdAt;

  int attempts;

  DateTime availableAt;

  DateTime? leasedUntil;

  String? leaseOwner;

  DateTime? completedAt;

  String? lastError;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [PushOutbox]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PushOutbox copyWith({
    _is.UuidValue? id,
    _is.UuidValue? coupleId,
    _is.UuidValue? sendId,
    int? recipientMemberId,
    int? version,
    DateTime? createdAt,
    int? attempts,
    DateTime? availableAt,
    DateTime? leasedUntil,
    String? leaseOwner,
    DateTime? completedAt,
    String? lastError,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PushOutbox',
      if (id != null) 'id': id?.toJson(),
      'coupleId': coupleId.toJson(),
      'sendId': sendId.toJson(),
      'recipientMemberId': recipientMemberId,
      'version': version,
      'createdAt': createdAt.toJson(),
      'attempts': attempts,
      'availableAt': availableAt.toJson(),
      if (leasedUntil != null) 'leasedUntil': leasedUntil?.toJson(),
      if (leaseOwner != null) 'leaseOwner': leaseOwner,
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (lastError != null) 'lastError': lastError,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static PushOutboxInclude include() {
    return PushOutboxInclude._();
  }

  static PushOutboxIncludeList includeList({
    _is.WhereExpressionBuilder<PushOutboxTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PushOutboxTable>? orderBy,
    _is.OrderByListBuilder<PushOutboxTable>? orderByList,
    PushOutboxInclude? include,
  }) {
    return PushOutboxIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PushOutbox.t),
      orderByList: orderByList?.call(PushOutbox.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PushOutboxImpl extends PushOutbox {
  _PushOutboxImpl({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required _is.UuidValue sendId,
    required int recipientMemberId,
    required int version,
    DateTime? createdAt,
    int? attempts,
    DateTime? availableAt,
    DateTime? leasedUntil,
    String? leaseOwner,
    DateTime? completedAt,
    String? lastError,
  }) : super._(
         id: id,
         coupleId: coupleId,
         sendId: sendId,
         recipientMemberId: recipientMemberId,
         version: version,
         createdAt: createdAt,
         attempts: attempts,
         availableAt: availableAt,
         leasedUntil: leasedUntil,
         leaseOwner: leaseOwner,
         completedAt: completedAt,
         lastError: lastError,
       );

  /// Returns a shallow copy of this [PushOutbox]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PushOutbox copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    _is.UuidValue? sendId,
    int? recipientMemberId,
    int? version,
    DateTime? createdAt,
    int? attempts,
    DateTime? availableAt,
    Object? leasedUntil = _Undefined,
    Object? leaseOwner = _Undefined,
    Object? completedAt = _Undefined,
    Object? lastError = _Undefined,
  }) {
    return PushOutbox(
      id: id is _is.UuidValue? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      sendId: sendId ?? this.sendId,
      recipientMemberId: recipientMemberId ?? this.recipientMemberId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      availableAt: availableAt ?? this.availableAt,
      leasedUntil: leasedUntil is DateTime? ? leasedUntil : this.leasedUntil,
      leaseOwner: leaseOwner is String? ? leaseOwner : this.leaseOwner,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      lastError: lastError is String? ? lastError : this.lastError,
    );
  }
}

class PushOutboxUpdateTable extends _is.UpdateTable<PushOutboxTable> {
  PushOutboxUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> sendId(_is.UuidValue value) =>
      _is.ColumnValue(table.sendId, value);

  _is.ColumnValue<int, int> recipientMemberId(int value) =>
      _is.ColumnValue(table.recipientMemberId, value);

  _is.ColumnValue<int, int> version(int value) =>
      _is.ColumnValue(table.version, value);

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(table.createdAt, value);

  _is.ColumnValue<int, int> attempts(int value) =>
      _is.ColumnValue(table.attempts, value);

  _is.ColumnValue<DateTime, DateTime> availableAt(DateTime value) =>
      _is.ColumnValue(table.availableAt, value);

  _is.ColumnValue<DateTime, DateTime> leasedUntil(DateTime? value) =>
      _is.ColumnValue(table.leasedUntil, value);

  _is.ColumnValue<String, String> leaseOwner(String? value) =>
      _is.ColumnValue(table.leaseOwner, value);

  _is.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _is.ColumnValue(table.completedAt, value);

  _is.ColumnValue<String, String> lastError(String? value) =>
      _is.ColumnValue(table.lastError, value);
}

class PushOutboxTable extends _is.Table<_is.UuidValue?> {
  PushOutboxTable({super.tableRelation})
    : super(tableName: 'closecall_push_outbox') {
    updateTable = PushOutboxUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    sendId = _is.ColumnUuid('sendId', this);
    recipientMemberId = _is.ColumnInt('recipientMemberId', this);
    version = _is.ColumnInt('version', this);
    createdAt = _is.ColumnDateTime('createdAt', this, hasDefault: true);
    attempts = _is.ColumnInt('attempts', this, hasDefault: true);
    availableAt = _is.ColumnDateTime('availableAt', this, hasDefault: true);
    leasedUntil = _is.ColumnDateTime('leasedUntil', this);
    leaseOwner = _is.ColumnString('leaseOwner', this);
    completedAt = _is.ColumnDateTime('completedAt', this);
    lastError = _is.ColumnString('lastError', this);
  }

  late final PushOutboxUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnUuid sendId;

  late final _is.ColumnInt recipientMemberId;

  late final _is.ColumnInt version;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnInt attempts;

  late final _is.ColumnDateTime availableAt;

  late final _is.ColumnDateTime leasedUntil;

  late final _is.ColumnString leaseOwner;

  late final _is.ColumnDateTime completedAt;

  late final _is.ColumnString lastError;

  @override
  List<_is.Column> get columns => [
    id,
    coupleId,
    sendId,
    recipientMemberId,
    version,
    createdAt,
    attempts,
    availableAt,
    leasedUntil,
    leaseOwner,
    completedAt,
    lastError,
  ];
}

class PushOutboxInclude extends _is.IncludeObject {
  PushOutboxInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => PushOutbox.t;
}

class PushOutboxIncludeList extends _is.IncludeList {
  PushOutboxIncludeList._({
    _is.WhereExpressionBuilder<PushOutboxTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(PushOutbox.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => PushOutbox.t;
}

class PushOutboxRepository {
  const PushOutboxRepository._();

  /// Returns a list of [PushOutbox]s matching the given query parameters.
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
  Future<List<PushOutbox>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PushOutboxTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PushOutboxTable>? orderBy,
    _is.OrderByListBuilder<PushOutboxTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<PushOutbox>(
      where: where?.call(PushOutbox.t),
      orderBy: orderBy?.call(PushOutbox.t),
      orderByList: orderByList?.call(PushOutbox.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [PushOutbox] matching the given query parameters.
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
  Future<PushOutbox?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PushOutboxTable>? where,
    int? offset,
    _is.OrderByBuilder<PushOutboxTable>? orderBy,
    _is.OrderByListBuilder<PushOutboxTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<PushOutbox>(
      where: where?.call(PushOutbox.t),
      orderBy: orderBy?.call(PushOutbox.t),
      orderByList: orderByList?.call(PushOutbox.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [PushOutbox] by its [id] or null if no such row exists.
  Future<PushOutbox?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<PushOutbox>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [PushOutbox]s in the list and returns the inserted rows.
  ///
  /// The returned [PushOutbox]s will have their `id` fields set.
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
  Future<List<PushOutbox>> insert(
    _is.DatabaseSession session,
    List<PushOutbox> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<PushOutbox>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [PushOutbox] and returns the inserted row.
  ///
  /// The returned [PushOutbox] will have its `id` field set.
  Future<PushOutbox> insertRow(
    _is.DatabaseSession session,
    PushOutbox row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<PushOutbox>(row, transaction: transaction);
  }

  /// Upserts all [PushOutbox]s in the list and returns the resulting rows.
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
  /// The returned [PushOutbox]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushOutbox>> upsert(
    _is.DatabaseSession session,
    List<PushOutbox> rows, {
    required _is.ColumnSelections<PushOutboxTable> conflictColumns,
    _is.ColumnSelections<PushOutboxTable>? updateColumns,
    _is.WhereExpressionBuilder<PushOutboxTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<PushOutbox>(
      rows,
      conflictColumns: conflictColumns(PushOutbox.t),
      updateColumns: updateColumns?.call(PushOutbox.t),
      updateWhere: updateWhere?.call(PushOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [PushOutbox] and returns the resulting row.
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
  /// The returned [PushOutbox] will have its `id` field set.
  Future<PushOutbox?> upsertRow(
    _is.DatabaseSession session,
    PushOutbox row, {
    required _is.ColumnSelections<PushOutboxTable> conflictColumns,
    _is.ColumnSelections<PushOutboxTable>? updateColumns,
    _is.WhereExpressionBuilder<PushOutboxTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<PushOutbox>(
      row,
      conflictColumns: conflictColumns(PushOutbox.t),
      updateColumns: updateColumns?.call(PushOutbox.t),
      updateWhere: updateWhere?.call(PushOutbox.t),
      transaction: transaction,
    );
  }

  /// Updates all [PushOutbox]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushOutbox>> update(
    _is.DatabaseSession session,
    List<PushOutbox> rows, {
    _is.ColumnSelections<PushOutboxTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<PushOutbox>(
      rows,
      columns: columns?.call(PushOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [PushOutbox]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<PushOutbox> updateRow(
    _is.DatabaseSession session,
    PushOutbox row, {
    _is.ColumnSelections<PushOutboxTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<PushOutbox>(
      row,
      columns: columns?.call(PushOutbox.t),
      transaction: transaction,
    );
  }

  /// Updates a single [PushOutbox] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<PushOutbox?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<PushOutboxUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<PushOutbox>(
      id,
      columnValues: columnValues(PushOutbox.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [PushOutbox]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushOutbox>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<PushOutboxUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<PushOutboxTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PushOutboxTable>? orderBy,
    _is.OrderByListBuilder<PushOutboxTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<PushOutbox>(
      columnValues: columnValues(PushOutbox.t.updateTable),
      where: where(PushOutbox.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PushOutbox.t),
      orderByList: orderByList?.call(PushOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [PushOutbox]s in the list and returns the deleted rows.
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
  Future<List<PushOutbox>> delete(
    _is.DatabaseSession session,
    List<PushOutbox> rows, {
    _is.OrderByBuilder<PushOutboxTable>? orderBy,
    _is.OrderByListBuilder<PushOutboxTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<PushOutbox>(
      rows,
      orderBy: orderBy?.call(PushOutbox.t),
      orderByList: orderByList?.call(PushOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [PushOutbox].
  Future<PushOutbox> deleteRow(
    _is.DatabaseSession session,
    PushOutbox row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<PushOutbox>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushOutbox>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PushOutboxTable> where,
    _is.OrderByBuilder<PushOutboxTable>? orderBy,
    _is.OrderByListBuilder<PushOutboxTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<PushOutbox>(
      where: where(PushOutbox.t),
      orderBy: orderBy?.call(PushOutbox.t),
      orderByList: orderByList?.call(PushOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PushOutboxTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<PushOutbox>(
      where: where?.call(PushOutbox.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [PushOutbox] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PushOutboxTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<PushOutbox>(
      where: where(PushOutbox.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
