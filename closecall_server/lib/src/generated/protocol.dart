/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/protocol.dart' as _isp;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import 'pairing/couple.dart' as _iz3xjlbz;
import 'pairing/couple_member.dart' as _ijn3tadz;
import 'pairing/pairing_failure.dart' as _ium95mnn;
import 'pairing/pairing_state.dart' as _iyyqlhox;
export 'pairing/couple.dart';
export 'pairing/couple_member.dart';
export 'pairing/pairing_failure.dart';
export 'pairing/pairing_state.dart';

class Protocol extends _is.DatabaseSerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  static List<_isp.TableDefinition> get targetTableDefinitions => [
    _isp.TableDefinition(
      name: 'closecall_couple',
      dartName: 'Couple',
      schema: 'public',
      module: 'closecall',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random',
        ),
        _isp.ColumnDefinition(
          name: 'partnerNickname',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'anniversary',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'themeKey',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'blush\'',
        ),
        _isp.ColumnDefinition(
          name: 'pairingCode',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'closecall_couple_pairing_code_unique',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'pairingCode',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'closecall_couple_member',
      dartName: 'CoupleMember',
      schema: 'public',
      module: 'closecall',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'coupleId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'userIdentifier',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'creatorSlot',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'closecall_couple_member_fk_0',
          columns: ['coupleId'],
          referenceTable: 'closecall_couple',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'closecall_member_user_unique',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userIdentifier',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'closecall_member_slot_unique',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'coupleId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'creatorSlot',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._iacs.Protocol.targetTableDefinitions,
    ..._iais.Protocol.targetTableDefinitions,
    ..._isp.Protocol.targetTableDefinitions,
  ];

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _is.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _iz3xjlbz.Couple) {
      return _iz3xjlbz.Couple.fromJson(data) as T;
    }
    if (t == _ijn3tadz.CoupleMember) {
      return _ijn3tadz.CoupleMember.fromJson(data) as T;
    }
    if (t == _ium95mnn.PairingFailure) {
      return _ium95mnn.PairingFailure.fromJson(data) as T;
    }
    if (t == _iyyqlhox.PairingState) {
      return _iyyqlhox.PairingState.fromJson(data) as T;
    }
    if (t == _is.getType<_iz3xjlbz.Couple?>()) {
      return (data != null ? _iz3xjlbz.Couple.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ijn3tadz.CoupleMember?>()) {
      return (data != null ? _ijn3tadz.CoupleMember.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ium95mnn.PairingFailure?>()) {
      return (data != null ? _ium95mnn.PairingFailure.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iyyqlhox.PairingState?>()) {
      return (data != null ? _iyyqlhox.PairingState.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    try {
      return _iacs.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _iais.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _isp.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _iz3xjlbz.Couple => 'Couple',
      _ijn3tadz.CoupleMember => 'CoupleMember',
      _ium95mnn.PairingFailure => 'PairingFailure',
      _iyyqlhox.PairingState => 'PairingState',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('closecall.', '');
    }

    switch (data) {
      case _iz3xjlbz.Couple():
        return 'Couple';
      case _ijn3tadz.CoupleMember():
        return 'CoupleMember';
      case _ium95mnn.PairingFailure():
        return 'PairingFailure';
      case _iyyqlhox.PairingState():
        return 'PairingState';
    }
    className = _iacs.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    className = _iais.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _isp.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.') ? className : 'serverpod.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'Couple') {
      return deserialize<_iz3xjlbz.Couple>(data['data']);
    }
    if (dataClassName == 'CoupleMember') {
      return deserialize<_ijn3tadz.CoupleMember>(data['data']);
    }
    if (dataClassName == 'PairingFailure') {
      return deserialize<_ium95mnn.PairingFailure>(data['data']);
    }
    if (dataClassName == 'PairingState') {
      return deserialize<_iyyqlhox.PairingState>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _iacs.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _iais.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _isp.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iacs.Protocol().registerHostProtocol('closecall', this);
    _iais.Protocol().registerHostProtocol('closecall', this);
  }

  @override
  _is.Table? getTableForType(Type t) {
    {
      var table = _iacs.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _iais.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _isp.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _iz3xjlbz.Couple:
        return _iz3xjlbz.Couple.t;
      case _ijn3tadz.CoupleMember:
        return _ijn3tadz.CoupleMember.t;
    }
    return null;
  }

  @override
  List<_isp.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'closecall';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _iacs.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iais.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
