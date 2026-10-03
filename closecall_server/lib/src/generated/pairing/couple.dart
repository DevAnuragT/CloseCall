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

abstract class Couple
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  Couple._({
    this.id,
    this.partnerNickname,
    this.anniversary,
    String? themeKey,
    this.pairingCode,
  }) : themeKey = themeKey ?? 'blush';

  factory Couple({
    _is.UuidValue? id,
    String? partnerNickname,
    DateTime? anniversary,
    String? themeKey,
    String? pairingCode,
  }) = _CoupleImpl;

  factory Couple.fromJson(Map<String, dynamic> jsonSerialization) {
    return Couple(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      partnerNickname: jsonSerialization['partnerNickname'] as String?,
      anniversary: jsonSerialization['anniversary'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['anniversary'],
            ),
      themeKey: jsonSerialization['themeKey'] as String?,
      pairingCode: jsonSerialization['pairingCode'] as String?,
    );
  }

  static final t = CoupleTable();

  static const db = CoupleRepository._();

  @override
  _is.UuidValue? id;

  String? partnerNickname;

  DateTime? anniversary;

  String themeKey;

  String? pairingCode;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Couple]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Couple copyWith({
    _is.UuidValue? id,
    String? partnerNickname,
    DateTime? anniversary,
    String? themeKey,
    String? pairingCode,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Couple',
      if (id != null) 'id': id?.toJson(),
      if (partnerNickname != null) 'partnerNickname': partnerNickname,
      if (anniversary != null) 'anniversary': anniversary?.toJson(),
      'themeKey': themeKey,
      if (pairingCode != null) 'pairingCode': pairingCode,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static CoupleInclude include() {
    return CoupleInclude._();
  }

  static CoupleIncludeList includeList({
    _is.WhereExpressionBuilder<CoupleTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CoupleTable>? orderBy,
    _is.OrderByListBuilder<CoupleTable>? orderByList,
    CoupleInclude? include,
  }) {
    return CoupleIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Couple.t),
      orderByList: orderByList?.call(Couple.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CoupleImpl extends Couple {
  _CoupleImpl({
    _is.UuidValue? id,
    String? partnerNickname,
    DateTime? anniversary,
    String? themeKey,
    String? pairingCode,
  }) : super._(
         id: id,
         partnerNickname: partnerNickname,
         anniversary: anniversary,
         themeKey: themeKey,
         pairingCode: pairingCode,
       );

  /// Returns a shallow copy of this [Couple]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Couple copyWith({
    Object? id = _Undefined,
    Object? partnerNickname = _Undefined,
    Object? anniversary = _Undefined,
    String? themeKey,
    Object? pairingCode = _Undefined,
  }) {
    return Couple(
      id: id is _is.UuidValue? ? id : this.id,
      partnerNickname: partnerNickname is String?
          ? partnerNickname
          : this.partnerNickname,
      anniversary: anniversary is DateTime? ? anniversary : this.anniversary,
      themeKey: themeKey ?? this.themeKey,
      pairingCode: pairingCode is String? ? pairingCode : this.pairingCode,
    );
  }
}

class CoupleUpdateTable extends _is.UpdateTable<CoupleTable> {
  CoupleUpdateTable(super.table);

  _is.ColumnValue<String, String> partnerNickname(String? value) =>
      _is.ColumnValue(table.partnerNickname, value);

  _is.ColumnValue<DateTime, DateTime> anniversary(DateTime? value) =>
      _is.ColumnValue(table.anniversary, value);

  _is.ColumnValue<String, String> themeKey(String value) =>
      _is.ColumnValue(table.themeKey, value);

  _is.ColumnValue<String, String> pairingCode(String? value) =>
      _is.ColumnValue(table.pairingCode, value);
}

class CoupleTable extends _is.Table<_is.UuidValue?> {
  CoupleTable({super.tableRelation}) : super(tableName: 'closecall_couple') {
    updateTable = CoupleUpdateTable(this);
    partnerNickname = _is.ColumnString('partnerNickname', this);
    anniversary = _is.ColumnDateTime('anniversary', this);
    themeKey = _is.ColumnString('themeKey', this, hasDefault: true);
    pairingCode = _is.ColumnString('pairingCode', this);
  }

  late final CoupleUpdateTable updateTable;

  late final _is.ColumnString partnerNickname;

  late final _is.ColumnDateTime anniversary;

  late final _is.ColumnString themeKey;

  late final _is.ColumnString pairingCode;

  @override
  List<_is.Column> get columns => [
    id,
    partnerNickname,
    anniversary,
    themeKey,
    pairingCode,
  ];
}

class CoupleInclude extends _is.IncludeObject {
  CoupleInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => Couple.t;
}

class CoupleIncludeList extends _is.IncludeList {
  CoupleIncludeList._({
    _is.WhereExpressionBuilder<CoupleTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Couple.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => Couple.t;
}

class CoupleRepository {
  const CoupleRepository._();

  /// Returns a list of [Couple]s matching the given query parameters.
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
  Future<List<Couple>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CoupleTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CoupleTable>? orderBy,
    _is.OrderByListBuilder<CoupleTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Couple>(
      where: where?.call(Couple.t),
      orderBy: orderBy?.call(Couple.t),
      orderByList: orderByList?.call(Couple.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Couple] matching the given query parameters.
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
  Future<Couple?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CoupleTable>? where,
    int? offset,
    _is.OrderByBuilder<CoupleTable>? orderBy,
    _is.OrderByListBuilder<CoupleTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Couple>(
      where: where?.call(Couple.t),
      orderBy: orderBy?.call(Couple.t),
      orderByList: orderByList?.call(Couple.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Couple] by its [id] or null if no such row exists.
  Future<Couple?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Couple>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Couple]s in the list and returns the inserted rows.
  ///
  /// The returned [Couple]s will have their `id` fields set.
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
  Future<List<Couple>> insert(
    _is.DatabaseSession session,
    List<Couple> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Couple>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Couple] and returns the inserted row.
  ///
  /// The returned [Couple] will have its `id` field set.
  Future<Couple> insertRow(
    _is.DatabaseSession session,
    Couple row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Couple>(row, transaction: transaction);
  }

  /// Upserts all [Couple]s in the list and returns the resulting rows.
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
  /// The returned [Couple]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Couple>> upsert(
    _is.DatabaseSession session,
    List<Couple> rows, {
    required _is.ColumnSelections<CoupleTable> conflictColumns,
    _is.ColumnSelections<CoupleTable>? updateColumns,
    _is.WhereExpressionBuilder<CoupleTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Couple>(
      rows,
      conflictColumns: conflictColumns(Couple.t),
      updateColumns: updateColumns?.call(Couple.t),
      updateWhere: updateWhere?.call(Couple.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Couple] and returns the resulting row.
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
  /// The returned [Couple] will have its `id` field set.
  Future<Couple?> upsertRow(
    _is.DatabaseSession session,
    Couple row, {
    required _is.ColumnSelections<CoupleTable> conflictColumns,
    _is.ColumnSelections<CoupleTable>? updateColumns,
    _is.WhereExpressionBuilder<CoupleTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Couple>(
      row,
      conflictColumns: conflictColumns(Couple.t),
      updateColumns: updateColumns?.call(Couple.t),
      updateWhere: updateWhere?.call(Couple.t),
      transaction: transaction,
    );
  }

  /// Updates all [Couple]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Couple>> update(
    _is.DatabaseSession session,
    List<Couple> rows, {
    _is.ColumnSelections<CoupleTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Couple>(
      rows,
      columns: columns?.call(Couple.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Couple]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Couple> updateRow(
    _is.DatabaseSession session,
    Couple row, {
    _is.ColumnSelections<CoupleTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Couple>(
      row,
      columns: columns?.call(Couple.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Couple] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Couple?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<CoupleUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Couple>(
      id,
      columnValues: columnValues(Couple.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Couple]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Couple>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<CoupleUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<CoupleTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CoupleTable>? orderBy,
    _is.OrderByListBuilder<CoupleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Couple>(
      columnValues: columnValues(Couple.t.updateTable),
      where: where(Couple.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Couple.t),
      orderByList: orderByList?.call(Couple.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Couple]s in the list and returns the deleted rows.
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
  Future<List<Couple>> delete(
    _is.DatabaseSession session,
    List<Couple> rows, {
    _is.OrderByBuilder<CoupleTable>? orderBy,
    _is.OrderByListBuilder<CoupleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Couple>(
      rows,
      orderBy: orderBy?.call(Couple.t),
      orderByList: orderByList?.call(Couple.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Couple].
  Future<Couple> deleteRow(
    _is.DatabaseSession session,
    Couple row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Couple>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Couple>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<CoupleTable> where,
    _is.OrderByBuilder<CoupleTable>? orderBy,
    _is.OrderByListBuilder<CoupleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Couple>(
      where: where(Couple.t),
      orderBy: orderBy?.call(Couple.t),
      orderByList: orderByList?.call(Couple.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CoupleTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Couple>(
      where: where?.call(Couple.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Couple] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<CoupleTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Couple>(
      where: where(Couple.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
