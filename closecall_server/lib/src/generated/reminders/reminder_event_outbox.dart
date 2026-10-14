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

abstract class ReminderEventOutbox
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  ReminderEventOutbox._({
    this.id,
    required this.coupleId,
    required this.reminderId,
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

  factory ReminderEventOutbox({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required _is.UuidValue reminderId,
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
  }) = _ReminderEventOutboxImpl;

  factory ReminderEventOutbox.fromJson(Map<String, dynamic> jsonSerialization) {
    return ReminderEventOutbox(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      reminderId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['reminderId'],
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

  static final t = ReminderEventOutboxTable();

  static const db = ReminderEventOutboxRepository._();

  @override
  _is.UuidValue? id;

  _is.UuidValue coupleId;

  _is.UuidValue reminderId;

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

  /// Returns a shallow copy of this [ReminderEventOutbox]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ReminderEventOutbox copyWith({
    _is.UuidValue? id,
    _is.UuidValue? coupleId,
    _is.UuidValue? reminderId,
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
      '__className__': 'ReminderEventOutbox',
      if (id != null) 'id': id?.toJson(),
      'coupleId': coupleId.toJson(),
      'reminderId': reminderId.toJson(),
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

  static ReminderEventOutboxInclude include() {
    return ReminderEventOutboxInclude._();
  }

  static ReminderEventOutboxIncludeList includeList({
    _is.WhereExpressionBuilder<ReminderEventOutboxTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ReminderEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<ReminderEventOutboxTable>? orderByList,
    ReminderEventOutboxInclude? include,
  }) {
    return ReminderEventOutboxIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ReminderEventOutbox.t),
      orderByList: orderByList?.call(ReminderEventOutbox.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ReminderEventOutboxImpl extends ReminderEventOutbox {
  _ReminderEventOutboxImpl({
    _is.UuidValue? id,
    required _is.UuidValue coupleId,
    required _is.UuidValue reminderId,
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
         reminderId: reminderId,
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

  /// Returns a shallow copy of this [ReminderEventOutbox]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ReminderEventOutbox copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    _is.UuidValue? reminderId,
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
    return ReminderEventOutbox(
      id: id is _is.UuidValue? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      reminderId: reminderId ?? this.reminderId,
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

class ReminderEventOutboxUpdateTable
    extends _is.UpdateTable<ReminderEventOutboxTable> {
  ReminderEventOutboxUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> reminderId(
    _is.UuidValue value,
  ) => _is.ColumnValue(table.reminderId, value);

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

class ReminderEventOutboxTable extends _is.Table<_is.UuidValue?> {
  ReminderEventOutboxTable({super.tableRelation})
    : super(tableName: 'closecall_reminder_event_outbox') {
    updateTable = ReminderEventOutboxUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    reminderId = _is.ColumnUuid('reminderId', this);
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

  late final ReminderEventOutboxUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnUuid reminderId;

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
    reminderId,
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

class ReminderEventOutboxInclude extends _is.IncludeObject {
  ReminderEventOutboxInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => ReminderEventOutbox.t;
}

class ReminderEventOutboxIncludeList extends _is.IncludeList {
  ReminderEventOutboxIncludeList._({
    _is.WhereExpressionBuilder<ReminderEventOutboxTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ReminderEventOutbox.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => ReminderEventOutbox.t;
}

class ReminderEventOutboxRepository {
  const ReminderEventOutboxRepository._();

  /// Returns a list of [ReminderEventOutbox]s matching the given query parameters.
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
  Future<List<ReminderEventOutbox>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ReminderEventOutboxTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ReminderEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<ReminderEventOutboxTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ReminderEventOutbox>(
      where: where?.call(ReminderEventOutbox.t),
      orderBy: orderBy?.call(ReminderEventOutbox.t),
      orderByList: orderByList?.call(ReminderEventOutbox.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ReminderEventOutbox] matching the given query parameters.
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
  Future<ReminderEventOutbox?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ReminderEventOutboxTable>? where,
    int? offset,
    _is.OrderByBuilder<ReminderEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<ReminderEventOutboxTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ReminderEventOutbox>(
      where: where?.call(ReminderEventOutbox.t),
      orderBy: orderBy?.call(ReminderEventOutbox.t),
      orderByList: orderByList?.call(ReminderEventOutbox.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ReminderEventOutbox] by its [id] or null if no such row exists.
  Future<ReminderEventOutbox?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ReminderEventOutbox>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ReminderEventOutbox]s in the list and returns the inserted rows.
  ///
  /// The returned [ReminderEventOutbox]s will have their `id` fields set.
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
  Future<List<ReminderEventOutbox>> insert(
    _is.DatabaseSession session,
    List<ReminderEventOutbox> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ReminderEventOutbox>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ReminderEventOutbox] and returns the inserted row.
  ///
  /// The returned [ReminderEventOutbox] will have its `id` field set.
  Future<ReminderEventOutbox> insertRow(
    _is.DatabaseSession session,
    ReminderEventOutbox row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<ReminderEventOutbox>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [ReminderEventOutbox]s in the list and returns the resulting rows.
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
  /// The returned [ReminderEventOutbox]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ReminderEventOutbox>> upsert(
    _is.DatabaseSession session,
    List<ReminderEventOutbox> rows, {
    required _is.ColumnSelections<ReminderEventOutboxTable> conflictColumns,
    _is.ColumnSelections<ReminderEventOutboxTable>? updateColumns,
    _is.WhereExpressionBuilder<ReminderEventOutboxTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ReminderEventOutbox>(
      rows,
      conflictColumns: conflictColumns(ReminderEventOutbox.t),
      updateColumns: updateColumns?.call(ReminderEventOutbox.t),
      updateWhere: updateWhere?.call(ReminderEventOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ReminderEventOutbox] and returns the resulting row.
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
  /// The returned [ReminderEventOutbox] will have its `id` field set.
  Future<ReminderEventOutbox?> upsertRow(
    _is.DatabaseSession session,
    ReminderEventOutbox row, {
    required _is.ColumnSelections<ReminderEventOutboxTable> conflictColumns,
    _is.ColumnSelections<ReminderEventOutboxTable>? updateColumns,
    _is.WhereExpressionBuilder<ReminderEventOutboxTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ReminderEventOutbox>(
      row,
      conflictColumns: conflictColumns(ReminderEventOutbox.t),
      updateColumns: updateColumns?.call(ReminderEventOutbox.t),
      updateWhere: updateWhere?.call(ReminderEventOutbox.t),
      transaction: transaction,
    );
  }

  /// Updates all [ReminderEventOutbox]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ReminderEventOutbox>> update(
    _is.DatabaseSession session,
    List<ReminderEventOutbox> rows, {
    _is.ColumnSelections<ReminderEventOutboxTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ReminderEventOutbox>(
      rows,
      columns: columns?.call(ReminderEventOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ReminderEventOutbox]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ReminderEventOutbox> updateRow(
    _is.DatabaseSession session,
    ReminderEventOutbox row, {
    _is.ColumnSelections<ReminderEventOutboxTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<ReminderEventOutbox>(
      row,
      columns: columns?.call(ReminderEventOutbox.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ReminderEventOutbox] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ReminderEventOutbox?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<ReminderEventOutboxUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<ReminderEventOutbox>(
      id,
      columnValues: columnValues(ReminderEventOutbox.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ReminderEventOutbox]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ReminderEventOutbox>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<ReminderEventOutboxUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<ReminderEventOutboxTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ReminderEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<ReminderEventOutboxTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ReminderEventOutbox>(
      columnValues: columnValues(ReminderEventOutbox.t.updateTable),
      where: where(ReminderEventOutbox.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ReminderEventOutbox.t),
      orderByList: orderByList?.call(ReminderEventOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ReminderEventOutbox]s in the list and returns the deleted rows.
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
  Future<List<ReminderEventOutbox>> delete(
    _is.DatabaseSession session,
    List<ReminderEventOutbox> rows, {
    _is.OrderByBuilder<ReminderEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<ReminderEventOutboxTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ReminderEventOutbox>(
      rows,
      orderBy: orderBy?.call(ReminderEventOutbox.t),
      orderByList: orderByList?.call(ReminderEventOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ReminderEventOutbox].
  Future<ReminderEventOutbox> deleteRow(
    _is.DatabaseSession session,
    ReminderEventOutbox row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ReminderEventOutbox>(
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
  Future<List<ReminderEventOutbox>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ReminderEventOutboxTable> where,
    _is.OrderByBuilder<ReminderEventOutboxTable>? orderBy,
    _is.OrderByListBuilder<ReminderEventOutboxTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ReminderEventOutbox>(
      where: where(ReminderEventOutbox.t),
      orderBy: orderBy?.call(ReminderEventOutbox.t),
      orderByList: orderByList?.call(ReminderEventOutbox.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ReminderEventOutboxTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<ReminderEventOutbox>(
      where: where?.call(ReminderEventOutbox.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ReminderEventOutbox] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ReminderEventOutboxTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ReminderEventOutbox>(
      where: where(ReminderEventOutbox.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
