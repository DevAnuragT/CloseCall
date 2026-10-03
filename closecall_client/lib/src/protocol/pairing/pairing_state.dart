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
import 'package:closecall_client/src/protocol/protocol.dart' as _ian6hnlh;
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class PairingState
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PairingState._({
    required this.coupleId,
    required this.memberIds,
    this.partnerNickname,
    this.anniversary,
    String? themeKey,
    this.pairingCode,
  }) : themeKey = themeKey ?? 'blush';

  factory PairingState({
    required String coupleId,
    required List<String> memberIds,
    String? partnerNickname,
    DateTime? anniversary,
    String? themeKey,
    String? pairingCode,
  }) = _PairingStateImpl;

  factory PairingState.fromJson(Map<String, dynamic> jsonSerialization) {
    return PairingState(
      coupleId: jsonSerialization['coupleId'] as String,
      memberIds: _ian6hnlh.Protocol().deserialize<List<String>>(
        jsonSerialization['memberIds'],
      ),
      partnerNickname: jsonSerialization['partnerNickname'] as String?,
      anniversary: jsonSerialization['anniversary'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['anniversary'],
            ),
      themeKey: jsonSerialization['themeKey'] as String?,
      pairingCode: jsonSerialization['pairingCode'] as String?,
    );
  }

  String coupleId;

  List<String> memberIds;

  String? partnerNickname;

  DateTime? anniversary;

  String themeKey;

  String? pairingCode;

  /// Returns a shallow copy of this [PairingState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PairingState copyWith({
    String? coupleId,
    List<String>? memberIds,
    String? partnerNickname,
    DateTime? anniversary,
    String? themeKey,
    String? pairingCode,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PairingState',
      'coupleId': coupleId,
      'memberIds': memberIds.toJson(),
      if (partnerNickname != null) 'partnerNickname': partnerNickname,
      if (anniversary != null) 'anniversary': anniversary?.toJson(),
      'themeKey': themeKey,
      if (pairingCode != null) 'pairingCode': pairingCode,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PairingState',
      'coupleId': coupleId,
      'memberIds': memberIds.toJson(),
      if (partnerNickname != null) 'partnerNickname': partnerNickname,
      if (anniversary != null) 'anniversary': anniversary?.toJson(),
      'themeKey': themeKey,
      if (pairingCode != null) 'pairingCode': pairingCode,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PairingStateImpl extends PairingState {
  _PairingStateImpl({
    required String coupleId,
    required List<String> memberIds,
    String? partnerNickname,
    DateTime? anniversary,
    String? themeKey,
    String? pairingCode,
  }) : super._(
         coupleId: coupleId,
         memberIds: memberIds,
         partnerNickname: partnerNickname,
         anniversary: anniversary,
         themeKey: themeKey,
         pairingCode: pairingCode,
       );

  /// Returns a shallow copy of this [PairingState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PairingState copyWith({
    String? coupleId,
    List<String>? memberIds,
    Object? partnerNickname = _Undefined,
    Object? anniversary = _Undefined,
    String? themeKey,
    Object? pairingCode = _Undefined,
  }) {
    return PairingState(
      coupleId: coupleId ?? this.coupleId,
      memberIds: memberIds ?? this.memberIds.map((e0) => e0).toList(),
      partnerNickname: partnerNickname is String?
          ? partnerNickname
          : this.partnerNickname,
      anniversary: anniversary is DateTime? ? anniversary : this.anniversary,
      themeKey: themeKey ?? this.themeKey,
      pairingCode: pairingCode is String? ? pairingCode : this.pairingCode,
    );
  }
}
