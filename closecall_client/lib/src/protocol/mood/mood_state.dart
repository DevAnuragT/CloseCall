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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class MoodState
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  MoodState._({
    this.ownMood,
    this.ownUpdatedAt,
    this.partnerUserId,
    this.partnerMood,
    this.partnerUpdatedAt,
  });

  factory MoodState({
    String? ownMood,
    DateTime? ownUpdatedAt,
    String? partnerUserId,
    String? partnerMood,
    DateTime? partnerUpdatedAt,
  }) = _MoodStateImpl;

  factory MoodState.fromJson(Map<String, dynamic> jsonSerialization) {
    return MoodState(
      ownMood: jsonSerialization['ownMood'] as String?,
      ownUpdatedAt: jsonSerialization['ownUpdatedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['ownUpdatedAt'],
            ),
      partnerUserId: jsonSerialization['partnerUserId'] as String?,
      partnerMood: jsonSerialization['partnerMood'] as String?,
      partnerUpdatedAt: jsonSerialization['partnerUpdatedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['partnerUpdatedAt'],
            ),
    );
  }

  String? ownMood;

  DateTime? ownUpdatedAt;

  String? partnerUserId;

  String? partnerMood;

  DateTime? partnerUpdatedAt;

  /// Returns a shallow copy of this [MoodState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  MoodState copyWith({
    String? ownMood,
    DateTime? ownUpdatedAt,
    String? partnerUserId,
    String? partnerMood,
    DateTime? partnerUpdatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MoodState',
      if (ownMood != null) 'ownMood': ownMood,
      if (ownUpdatedAt != null) 'ownUpdatedAt': ownUpdatedAt?.toJson(),
      if (partnerUserId != null) 'partnerUserId': partnerUserId,
      if (partnerMood != null) 'partnerMood': partnerMood,
      if (partnerUpdatedAt != null)
        'partnerUpdatedAt': partnerUpdatedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MoodState',
      if (ownMood != null) 'ownMood': ownMood,
      if (ownUpdatedAt != null) 'ownUpdatedAt': ownUpdatedAt?.toJson(),
      if (partnerUserId != null) 'partnerUserId': partnerUserId,
      if (partnerMood != null) 'partnerMood': partnerMood,
      if (partnerUpdatedAt != null)
        'partnerUpdatedAt': partnerUpdatedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MoodStateImpl extends MoodState {
  _MoodStateImpl({
    String? ownMood,
    DateTime? ownUpdatedAt,
    String? partnerUserId,
    String? partnerMood,
    DateTime? partnerUpdatedAt,
  }) : super._(
         ownMood: ownMood,
         ownUpdatedAt: ownUpdatedAt,
         partnerUserId: partnerUserId,
         partnerMood: partnerMood,
         partnerUpdatedAt: partnerUpdatedAt,
       );

  /// Returns a shallow copy of this [MoodState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  MoodState copyWith({
    Object? ownMood = _Undefined,
    Object? ownUpdatedAt = _Undefined,
    Object? partnerUserId = _Undefined,
    Object? partnerMood = _Undefined,
    Object? partnerUpdatedAt = _Undefined,
  }) {
    return MoodState(
      ownMood: ownMood is String? ? ownMood : this.ownMood,
      ownUpdatedAt: ownUpdatedAt is DateTime?
          ? ownUpdatedAt
          : this.ownUpdatedAt,
      partnerUserId: partnerUserId is String?
          ? partnerUserId
          : this.partnerUserId,
      partnerMood: partnerMood is String? ? partnerMood : this.partnerMood,
      partnerUpdatedAt: partnerUpdatedAt is DateTime?
          ? partnerUpdatedAt
          : this.partnerUpdatedAt,
    );
  }
}
