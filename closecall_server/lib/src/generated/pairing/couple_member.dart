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

abstract class CoupleMember
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  CoupleMember._({
    this.id,
    required this.coupleId,
    required this.userIdentifier,
    required this.creatorSlot,
    this.ownNickname,
    this.partnerNickname,
    this.nicknamesUpdatedAt,
    this.currentMood,
    this.moodUpdatedAt,
  });

  factory CoupleMember({
    int? id,
    required _is.UuidValue coupleId,
    required String userIdentifier,
    required bool creatorSlot,
    String? ownNickname,
    String? partnerNickname,
    DateTime? nicknamesUpdatedAt,
    String? currentMood,
    DateTime? moodUpdatedAt,
  }) = _CoupleMemberImpl;

  factory CoupleMember.fromJson(Map<String, dynamic> jsonSerialization) {
    return CoupleMember(
      id: jsonSerialization['id'] as int?,
      coupleId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['coupleId'],
      ),
      userIdentifier: jsonSerialization['userIdentifier'] as String,
      creatorSlot: _is.BoolJsonExtension.fromJson(
        jsonSerialization['creatorSlot'],
      ),
      ownNickname: jsonSerialization['ownNickname'] as String?,
      partnerNickname: jsonSerialization['partnerNickname'] as String?,
      nicknamesUpdatedAt: jsonSerialization['nicknamesUpdatedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['nicknamesUpdatedAt'],
            ),
      currentMood: jsonSerialization['currentMood'] as String?,
      moodUpdatedAt: jsonSerialization['moodUpdatedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['moodUpdatedAt'],
            ),
    );
  }

  static final t = CoupleMemberTable();

  static const db = CoupleMemberRepository._();

  @override
  int? id;

  _is.UuidValue coupleId;

  String userIdentifier;

  bool creatorSlot;

  String? ownNickname;

  String? partnerNickname;

  DateTime? nicknamesUpdatedAt;

  String? currentMood;

  DateTime? moodUpdatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [CoupleMember]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CoupleMember copyWith({
    int? id,
    _is.UuidValue? coupleId,
    String? userIdentifier,
    bool? creatorSlot,
    String? ownNickname,
    String? partnerNickname,
    DateTime? nicknamesUpdatedAt,
    String? currentMood,
    DateTime? moodUpdatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CoupleMember',
      if (id != null) 'id': id,
      'coupleId': coupleId.toJson(),
      'userIdentifier': userIdentifier,
      'creatorSlot': creatorSlot,
      if (ownNickname != null) 'ownNickname': ownNickname,
      if (partnerNickname != null) 'partnerNickname': partnerNickname,
      if (nicknamesUpdatedAt != null)
        'nicknamesUpdatedAt': nicknamesUpdatedAt?.toJson(),
      if (currentMood != null) 'currentMood': currentMood,
      if (moodUpdatedAt != null) 'moodUpdatedAt': moodUpdatedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static CoupleMemberInclude include() {
    return CoupleMemberInclude._();
  }

  static CoupleMemberIncludeList includeList({
    _is.WhereExpressionBuilder<CoupleMemberTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CoupleMemberTable>? orderBy,
    _is.OrderByListBuilder<CoupleMemberTable>? orderByList,
    CoupleMemberInclude? include,
  }) {
    return CoupleMemberIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CoupleMember.t),
      orderByList: orderByList?.call(CoupleMember.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CoupleMemberImpl extends CoupleMember {
  _CoupleMemberImpl({
    int? id,
    required _is.UuidValue coupleId,
    required String userIdentifier,
    required bool creatorSlot,
    String? ownNickname,
    String? partnerNickname,
    DateTime? nicknamesUpdatedAt,
    String? currentMood,
    DateTime? moodUpdatedAt,
  }) : super._(
         id: id,
         coupleId: coupleId,
         userIdentifier: userIdentifier,
         creatorSlot: creatorSlot,
         ownNickname: ownNickname,
         partnerNickname: partnerNickname,
         nicknamesUpdatedAt: nicknamesUpdatedAt,
         currentMood: currentMood,
         moodUpdatedAt: moodUpdatedAt,
       );

  /// Returns a shallow copy of this [CoupleMember]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CoupleMember copyWith({
    Object? id = _Undefined,
    _is.UuidValue? coupleId,
    String? userIdentifier,
    bool? creatorSlot,
    Object? ownNickname = _Undefined,
    Object? partnerNickname = _Undefined,
    Object? nicknamesUpdatedAt = _Undefined,
    Object? currentMood = _Undefined,
    Object? moodUpdatedAt = _Undefined,
  }) {
    return CoupleMember(
      id: id is int? ? id : this.id,
      coupleId: coupleId ?? this.coupleId,
      userIdentifier: userIdentifier ?? this.userIdentifier,
      creatorSlot: creatorSlot ?? this.creatorSlot,
      ownNickname: ownNickname is String? ? ownNickname : this.ownNickname,
      partnerNickname: partnerNickname is String?
          ? partnerNickname
          : this.partnerNickname,
      nicknamesUpdatedAt: nicknamesUpdatedAt is DateTime?
          ? nicknamesUpdatedAt
          : this.nicknamesUpdatedAt,
      currentMood: currentMood is String? ? currentMood : this.currentMood,
      moodUpdatedAt: moodUpdatedAt is DateTime?
          ? moodUpdatedAt
          : this.moodUpdatedAt,
    );
  }
}

class CoupleMemberUpdateTable extends _is.UpdateTable<CoupleMemberTable> {
  CoupleMemberUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> coupleId(_is.UuidValue value) =>
      _is.ColumnValue(table.coupleId, value);

  _is.ColumnValue<String, String> userIdentifier(String value) =>
      _is.ColumnValue(table.userIdentifier, value);

  _is.ColumnValue<bool, bool> creatorSlot(bool value) =>
      _is.ColumnValue(table.creatorSlot, value);

  _is.ColumnValue<String, String> ownNickname(String? value) =>
      _is.ColumnValue(table.ownNickname, value);

  _is.ColumnValue<String, String> partnerNickname(String? value) =>
      _is.ColumnValue(table.partnerNickname, value);

  _is.ColumnValue<DateTime, DateTime> nicknamesUpdatedAt(DateTime? value) =>
      _is.ColumnValue(table.nicknamesUpdatedAt, value);

  _is.ColumnValue<String, String> currentMood(String? value) =>
      _is.ColumnValue(table.currentMood, value);

  _is.ColumnValue<DateTime, DateTime> moodUpdatedAt(DateTime? value) =>
      _is.ColumnValue(table.moodUpdatedAt, value);
}

class CoupleMemberTable extends _is.Table<int?> {
  CoupleMemberTable({super.tableRelation})
    : super(tableName: 'closecall_couple_member') {
    updateTable = CoupleMemberUpdateTable(this);
    coupleId = _is.ColumnUuid('coupleId', this);
    userIdentifier = _is.ColumnString('userIdentifier', this);
    creatorSlot = _is.ColumnBool('creatorSlot', this);
    ownNickname = _is.ColumnString('ownNickname', this);
    partnerNickname = _is.ColumnString('partnerNickname', this);
    nicknamesUpdatedAt = _is.ColumnDateTime('nicknamesUpdatedAt', this);
    currentMood = _is.ColumnString('currentMood', this);
    moodUpdatedAt = _is.ColumnDateTime('moodUpdatedAt', this);
  }

  late final CoupleMemberUpdateTable updateTable;

  late final _is.ColumnUuid coupleId;

  late final _is.ColumnString userIdentifier;

  late final _is.ColumnBool creatorSlot;

  late final _is.ColumnString ownNickname;

  late final _is.ColumnString partnerNickname;

  late final _is.ColumnDateTime nicknamesUpdatedAt;

  late final _is.ColumnString currentMood;

  late final _is.ColumnDateTime moodUpdatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    coupleId,
    userIdentifier,
    creatorSlot,
    ownNickname,
    partnerNickname,
    nicknamesUpdatedAt,
    currentMood,
    moodUpdatedAt,
  ];
}

class CoupleMemberInclude extends _is.IncludeObject {
  CoupleMemberInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => CoupleMember.t;
}

class CoupleMemberIncludeList extends _is.IncludeList {
  CoupleMemberIncludeList._({
    _is.WhereExpressionBuilder<CoupleMemberTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CoupleMember.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => CoupleMember.t;
}

class CoupleMemberRepository {
  const CoupleMemberRepository._();

  /// Returns a list of [CoupleMember]s matching the given query parameters.
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
  Future<List<CoupleMember>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CoupleMemberTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CoupleMemberTable>? orderBy,
    _is.OrderByListBuilder<CoupleMemberTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CoupleMember>(
      where: where?.call(CoupleMember.t),
      orderBy: orderBy?.call(CoupleMember.t),
      orderByList: orderByList?.call(CoupleMember.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CoupleMember] matching the given query parameters.
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
  Future<CoupleMember?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CoupleMemberTable>? where,
    int? offset,
    _is.OrderByBuilder<CoupleMemberTable>? orderBy,
    _is.OrderByListBuilder<CoupleMemberTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CoupleMember>(
      where: where?.call(CoupleMember.t),
      orderBy: orderBy?.call(CoupleMember.t),
      orderByList: orderByList?.call(CoupleMember.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CoupleMember] by its [id] or null if no such row exists.
  Future<CoupleMember?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CoupleMember>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CoupleMember]s in the list and returns the inserted rows.
  ///
  /// The returned [CoupleMember]s will have their `id` fields set.
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
  Future<List<CoupleMember>> insert(
    _is.DatabaseSession session,
    List<CoupleMember> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CoupleMember>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CoupleMember] and returns the inserted row.
  ///
  /// The returned [CoupleMember] will have its `id` field set.
  Future<CoupleMember> insertRow(
    _is.DatabaseSession session,
    CoupleMember row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<CoupleMember>(row, transaction: transaction);
  }

  /// Upserts all [CoupleMember]s in the list and returns the resulting rows.
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
  /// The returned [CoupleMember]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CoupleMember>> upsert(
    _is.DatabaseSession session,
    List<CoupleMember> rows, {
    required _is.ColumnSelections<CoupleMemberTable> conflictColumns,
    _is.ColumnSelections<CoupleMemberTable>? updateColumns,
    _is.WhereExpressionBuilder<CoupleMemberTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CoupleMember>(
      rows,
      conflictColumns: conflictColumns(CoupleMember.t),
      updateColumns: updateColumns?.call(CoupleMember.t),
      updateWhere: updateWhere?.call(CoupleMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CoupleMember] and returns the resulting row.
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
  /// The returned [CoupleMember] will have its `id` field set.
  Future<CoupleMember?> upsertRow(
    _is.DatabaseSession session,
    CoupleMember row, {
    required _is.ColumnSelections<CoupleMemberTable> conflictColumns,
    _is.ColumnSelections<CoupleMemberTable>? updateColumns,
    _is.WhereExpressionBuilder<CoupleMemberTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CoupleMember>(
      row,
      conflictColumns: conflictColumns(CoupleMember.t),
      updateColumns: updateColumns?.call(CoupleMember.t),
      updateWhere: updateWhere?.call(CoupleMember.t),
      transaction: transaction,
    );
  }

  /// Updates all [CoupleMember]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CoupleMember>> update(
    _is.DatabaseSession session,
    List<CoupleMember> rows, {
    _is.ColumnSelections<CoupleMemberTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CoupleMember>(
      rows,
      columns: columns?.call(CoupleMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CoupleMember]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CoupleMember> updateRow(
    _is.DatabaseSession session,
    CoupleMember row, {
    _is.ColumnSelections<CoupleMemberTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<CoupleMember>(
      row,
      columns: columns?.call(CoupleMember.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CoupleMember] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CoupleMember?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<CoupleMemberUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<CoupleMember>(
      id,
      columnValues: columnValues(CoupleMember.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CoupleMember]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CoupleMember>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<CoupleMemberUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<CoupleMemberTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CoupleMemberTable>? orderBy,
    _is.OrderByListBuilder<CoupleMemberTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CoupleMember>(
      columnValues: columnValues(CoupleMember.t.updateTable),
      where: where(CoupleMember.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CoupleMember.t),
      orderByList: orderByList?.call(CoupleMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CoupleMember]s in the list and returns the deleted rows.
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
  Future<List<CoupleMember>> delete(
    _is.DatabaseSession session,
    List<CoupleMember> rows, {
    _is.OrderByBuilder<CoupleMemberTable>? orderBy,
    _is.OrderByListBuilder<CoupleMemberTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CoupleMember>(
      rows,
      orderBy: orderBy?.call(CoupleMember.t),
      orderByList: orderByList?.call(CoupleMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CoupleMember].
  Future<CoupleMember> deleteRow(
    _is.DatabaseSession session,
    CoupleMember row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CoupleMember>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CoupleMember>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<CoupleMemberTable> where,
    _is.OrderByBuilder<CoupleMemberTable>? orderBy,
    _is.OrderByListBuilder<CoupleMemberTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CoupleMember>(
      where: where(CoupleMember.t),
      orderBy: orderBy?.call(CoupleMember.t),
      orderByList: orderByList?.call(CoupleMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CoupleMemberTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<CoupleMember>(
      where: where?.call(CoupleMember.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CoupleMember] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<CoupleMemberTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CoupleMember>(
      where: where(CoupleMember.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
