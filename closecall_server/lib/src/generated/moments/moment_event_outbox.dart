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

abstract class MomentEventOutbox
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  MomentEventOutbox._({
    this.id,
    required this.coupleId,
    required this.momentId,
    required this.recipientMemberId,
    required this.eventType,
    DateTime? createdAt,
    int? attempts,
    DateTime? availableAt,
    this.leasedUntil,
    this.leaseOwner,
    required this.expiresAt,
    this.completedAt,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now(),
       attempts = attempts ?? 0,
       availableAt = availableAt ?? DateTime.now();

  factory MomentEventOutbox({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required _is.UuidValue momentId,
    required int recipientMemberId,
    required String eventType,
    DateTime? createdAt,
    int? attempts,
    DateTime? availableAt,
    DateTime? leasedUntil,
    String? leaseOwner,
    required DateTime expiresAt,
    DateTime? completedAt,
    String? lastError,
  }) = _MomentEventOutboxImpl;

  factory MomentEventOutbox.fromJson(Map<String, dynamic> jsonSerialization) {
    return MomentEventOutbox(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      momentId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['momentId'],
      ),
      recipientMemberId: jsonSerialization['recipientMemberId'] as int,
      eventType: jsonSerialization['eventType'] as String,
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
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      lastError: jsonSerialization['lastError'] as String?,
    );
  }

  static final t = MomentEventOutboxTable();

  static const db = MomentEventOutboxRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue coupleId;

  _is.UuidValue momentId;

  int recipientMemberId;

  String eventType;

  DateTime createdAt;

  int attempts;

  DateTime availableAt;

  DateTime? leasedUntil;

  String? leaseOwner;

  DateTime expiresAt;

  DateTime? completedAt;

  String? lastError;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [MomentEventOutbox]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MomentEventOutbox copyWith({
    _is.UuidValue? id,
    _is.UuidValue? coupleId,
    _is.UuidValue? momentId,
    int? recipientMemberId,
    String? eventType,
    DateTime? createdAt,
    int? attempts,
    DateTime? availableAt,
    DateTime? leasedUntil,
    String? leaseOwner,
    DateTime? expiresAt,
    DateTime? completedAt,
    String? lastError,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MomentEventOutbox',
      if (id != null) 'id': id?.toJson(),
      'coupleId': coupleId.toJson(),
      'momentId': momentId.toJson(),
      'recipientMemberId': recipientMemberId,
      'eventType': eventType,
      'createdAt': createdAt.toJson(),
      'attempts': attempts,
      'availableAt': availableAt.toJson(),
      if (leasedUntil != null) 'leasedUntil': leasedUntil?.toJson(),
      if (leaseOwner != null) 'leaseOwner': leaseOwner,
      'expiresAt': expiresAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (lastError != null) 'lastError': lastError,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static MomentEventOutboxInclude include() {
    return MomentEventOutboxInclude._();
  }

  static MomentEventOutboxIncludeList includeList({
    _is.WhereExpressionBuilder<MomentEventOutboxTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MomentEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<MomentEventOutboxTable>? orderByList,
    MomentEventOutboxInclude? include,
  }) {
    return MomentEventOutboxIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MomentEventOutbox.t),
      orderByList: orderByList?.call(MomentEventOutbox.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MomentEventOutboxImpl extends MomentEventOutbox {
  _MomentEventOutboxImpl({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required _is.UuidValue momentId,
    required int recipientMemberId,
    required String eventType,
    DateTime? createdAt,
    int? attempts,
    DateTime? availableAt,
    DateTime? leasedUntil,
    String? leaseOwner,
    required DateTime expiresAt,
    DateTime? completedAt,
    String? lastError,
  }) : super._(
         id: id,
         coupleId: coupleId,
         momentId: momentId,
         recipientMemberId: recipientMemberId,
         eventType: eventType,
         createdAt: createdAt,
         attempts: attempts,
         availableAt: availableAt,
         leasedUntil: leasedUntil,
         leaseOwner: leaseOwner,
         expiresAt: expiresAt,
         completedAt: completedAt,
         lastError: lastError,
       );

  /// Returns a shallow copy of this [MomentEventOutbox]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MomentEventOutbox copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    _is.UuidValue? momentId,
    int? recipientMemberId,
    String? eventType,
    DateTime? createdAt,
    int? attempts,
    DateTime? availableAt,
    Object? leasedUntil = _Undefined,
    Object? leaseOwner = _Undefined,
    DateTime? expiresAt,
    Object? completedAt = _Undefined,
    Object? lastError = _Undefined,
  }) {
    return MomentEventOutbox(
      id: id is _is.UuidValue? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      momentId: momentId ?? this.momentId,
      recipientMemberId: recipientMemberId ?? this.recipientMemberId,
      eventType: eventType ?? this.eventType,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      availableAt: availableAt ?? this.availableAt,
      leasedUntil: leasedUntil is DateTime? ? leasedUntil : this.leasedUntil,
      leaseOwner: leaseOwner is String? ? leaseOwner : this.leaseOwner,
      expiresAt: expiresAt ?? this.expiresAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      lastError: lastError is String? ? lastError : this.lastError,
    );
  }
}

class MomentEventOutboxUpdateTable
    extends _is.UpdateTable<MomentEventOutboxTable> {
  MomentEventOutboxUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> momentId(_is.UuidValue value) =>
      _is.ColumnValue(table.momentId, value);

  _is.ColumnValue<int, int> recipientMemberId(int value) =>
      _is.ColumnValue(table.recipientMemberId, value);

  _is.ColumnValue<String, String> eventType(String value) =>
      _is.ColumnValue(table.eventType, value);

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

  _is.ColumnValue<DateTime, DateTime> expiresAt(DateTime value) =>
      _is.ColumnValue(table.expiresAt, value);

  _is.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _is.ColumnValue(table.completedAt, value);

  _is.ColumnValue<String, String> lastError(String? value) =>
      _is.ColumnValue(table.lastError, value);
}

class MomentEventOutboxTable extends _is.Table<_is.UuidValue?> {
  MomentEventOutboxTable({super.tableRelation})
    : super(tableName: 'closecall_moment_event_outbox') {
    updateTable = MomentEventOutboxUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    momentId = _is.ColumnUuid('momentId', this);
    recipientMemberId = _is.ColumnInt('recipientMemberId', this);
    eventType = _is.ColumnString('eventType', this);
    createdAt = _is.ColumnDateTime('createdAt', this, hasDefault: true);
    attempts = _is.ColumnInt('attempts', this, hasDefault: true);
    availableAt = _is.ColumnDateTime('availableAt', this, hasDefault: true);
    leasedUntil = _is.ColumnDateTime('leasedUntil', this);
    leaseOwner = _is.ColumnString('leaseOwner', this);
    expiresAt = _is.ColumnDateTime('expiresAt', this);
    completedAt = _is.ColumnDateTime('completedAt', this);
    lastError = _is.ColumnString('lastError', this);
  }

  late final MomentEventOutboxUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnUuid momentId;

  late final _is.ColumnInt recipientMemberId;

  late final _is.ColumnString eventType;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnInt attempts;

  late final _is.ColumnDateTime availableAt;

  late final _is.ColumnDateTime leasedUntil;

  late final _is.ColumnString leaseOwner;

  late final _is.ColumnDateTime expiresAt;

  late final _is.ColumnDateTime completedAt;

  late final _is.ColumnString lastError;

  @override
  List<_is.Column> get columns => [
    id,
    coupleId,
    momentId,
    recipientMemberId,
    eventType,
    createdAt,
    attempts,
    availableAt,
    leasedUntil,
    leaseOwner,
    expiresAt,
    completedAt,
    lastError,
  ];
}

class MomentEventOutboxInclude extends _is.IncludeObject {
  MomentEventOutboxInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => MomentEventOutbox.t;
}

class MomentEventOutboxIncludeList extends _is.IncludeList {
  MomentEventOutboxIncludeList._({
    _is.WhereExpressionBuilder<MomentEventOutboxTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(MomentEventOutbox.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => MomentEventOutbox.t;
}

class MomentEventOutboxRepository {
  const MomentEventOutboxRepository._();

  /// Returns a list of [MomentEventOutbox]s matching the given query parameters.
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
  Future<List<MomentEventOutbox>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MomentEventOutboxTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MomentEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<MomentEventOutboxTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<MomentEventOutbox>(
      where: where?.call(MomentEventOutbox.t),
      orderBy: orderBy?.call(MomentEventOutbox.t),
      orderByList: orderByList?.call(MomentEventOutbox.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [MomentEventOutbox] matching the given query parameters.
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
  Future<MomentEventOutbox?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MomentEventOutboxTable>? where,
    int? offset,
    _is.OrderByBuilder<MomentEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<MomentEventOutboxTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<MomentEventOutbox>(
      where: where?.call(MomentEventOutbox.t),
      orderBy: orderBy?.call(MomentEventOutbox.t),
      orderByList: orderByList?.call(MomentEventOutbox.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [MomentEventOutbox] by its [id] or null if no such row exists.
  Future<MomentEventOutbox?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<MomentEventOutbox>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [MomentEventOutbox]s in the list and returns the inserted rows.
  ///
  /// The returned [MomentEventOutbox]s will have their `id` fields set.
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
  Future<List<MomentEventOutbox>> insert(
    _is.DatabaseSession session,
    List<MomentEventOutbox> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<MomentEventOutbox>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [MomentEventOutbox] and returns the inserted row.
  ///
  /// The returned [MomentEventOutbox] will have its `id` field set.
  Future<MomentEventOutbox> insertRow(
    _is.DatabaseSession session,
    MomentEventOutbox row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<MomentEventOutbox>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [MomentEventOutbox]s in the list and returns the resulting rows.
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
  /// The returned [MomentEventOutbox]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MomentEventOutbox>> upsert(
    _is.DatabaseSession session,
    List<MomentEventOutbox> rows, {
    required _is.ColumnSelections<MomentEventOutboxTable> conflictColumns,
    _is.ColumnSelections<MomentEventOutboxTable>? updateColumns,
    _is.WhereExpressionBuilder<MomentEventOutboxTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<MomentEventOutbox>(
      rows,
      conflictColumns: conflictColumns(MomentEventOutbox.t),
      updateColumns: updateColumns?.call(MomentEventOutbox.t),
      updateWhere: updateWhere?.call(MomentEventOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [MomentEventOutbox] and returns the resulting row.
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
  /// The returned [MomentEventOutbox] will have its `id` field set.
  Future<MomentEventOutbox?> upsertRow(
    _is.DatabaseSession session,
    MomentEventOutbox row, {
    required _is.ColumnSelections<MomentEventOutboxTable> conflictColumns,
    _is.ColumnSelections<MomentEventOutboxTable>? updateColumns,
    _is.WhereExpressionBuilder<MomentEventOutboxTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<MomentEventOutbox>(
      row,
      conflictColumns: conflictColumns(MomentEventOutbox.t),
      updateColumns: updateColumns?.call(MomentEventOutbox.t),
      updateWhere: updateWhere?.call(MomentEventOutbox.t),
      transaction: transaction,
    );
  }

  /// Updates all [MomentEventOutbox]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MomentEventOutbox>> update(
    _is.DatabaseSession session,
    List<MomentEventOutbox> rows, {
    _is.ColumnSelections<MomentEventOutboxTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<MomentEventOutbox>(
      rows,
      columns: columns?.call(MomentEventOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [MomentEventOutbox]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<MomentEventOutbox> updateRow(
    _is.DatabaseSession session,
    MomentEventOutbox row, {
    _is.ColumnSelections<MomentEventOutboxTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<MomentEventOutbox>(
      row,
      columns: columns?.call(MomentEventOutbox.t),
      transaction: transaction,
    );
  }

  /// Updates a single [MomentEventOutbox] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<MomentEventOutbox?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<MomentEventOutboxUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<MomentEventOutbox>(
      id,
      columnValues: columnValues(MomentEventOutbox.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [MomentEventOutbox]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<MomentEventOutbox>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<MomentEventOutboxUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<MomentEventOutboxTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MomentEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<MomentEventOutboxTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<MomentEventOutbox>(
      columnValues: columnValues(MomentEventOutbox.t.updateTable),
      where: where(MomentEventOutbox.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(MomentEventOutbox.t),
      orderByList: orderByList?.call(MomentEventOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [MomentEventOutbox]s in the list and returns the deleted rows.
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
  Future<List<MomentEventOutbox>> delete(
    _is.DatabaseSession session,
    List<MomentEventOutbox> rows, {
    _is.OrderByBuilder<MomentEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<MomentEventOutboxTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<MomentEventOutbox>(
      rows,
      orderBy: orderBy?.call(MomentEventOutbox.t),
      orderByList: orderByList?.call(MomentEventOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [MomentEventOutbox].
  Future<MomentEventOutbox> deleteRow(
    _is.DatabaseSession session,
    MomentEventOutbox row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<MomentEventOutbox>(
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
  Future<List<MomentEventOutbox>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<MomentEventOutboxTable> where,
    _is.OrderByBuilder<MomentEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<MomentEventOutboxTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<MomentEventOutbox>(
      where: where(MomentEventOutbox.t),
      orderBy: orderBy?.call(MomentEventOutbox.t),
      orderByList: orderByList?.call(MomentEventOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MomentEventOutboxTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<MomentEventOutbox>(
      where: where?.call(MomentEventOutbox.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [MomentEventOutbox] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<MomentEventOutboxTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<MomentEventOutbox>(
      where: where(MomentEventOutbox.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
