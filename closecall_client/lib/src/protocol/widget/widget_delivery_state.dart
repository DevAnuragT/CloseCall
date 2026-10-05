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

abstract class WidgetDeliveryState
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  WidgetDeliveryState._({
    required this.coupleId,
    required this.recipientId,
    required this.autoUpdateEnabled,
    required this.version,
    this.latestAssetId,
    this.latestSenderId,
    this.latestSentAt,
  });

  factory WidgetDeliveryState({
    required String coupleId,
    required String recipientId,
    required bool autoUpdateEnabled,
    required int version,
    String? latestAssetId,
    String? latestSenderId,
    DateTime? latestSentAt,
  }) = _WidgetDeliveryStateImpl;

  factory WidgetDeliveryState.fromJson(Map<String, dynamic> jsonSerialization) {
    return WidgetDeliveryState(
      coupleId: jsonSerialization['coupleId'] as String,
      recipientId: jsonSerialization['recipientId'] as String,
      autoUpdateEnabled: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['autoUpdateEnabled'],
      ),
      version: jsonSerialization['version'] as int,
      latestAssetId: jsonSerialization['latestAssetId'] as String?,
      latestSenderId: jsonSerialization['latestSenderId'] as String?,
      latestSentAt: jsonSerialization['latestSentAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['latestSentAt'],
            ),
    );
  }

  String coupleId;

  String recipientId;

  bool autoUpdateEnabled;

  int version;

  String? latestAssetId;

  String? latestSenderId;

  DateTime? latestSentAt;

  /// Returns a shallow copy of this [WidgetDeliveryState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  WidgetDeliveryState copyWith({
    String? coupleId,
    String? recipientId,
    bool? autoUpdateEnabled,
    int? version,
    String? latestAssetId,
    String? latestSenderId,
    DateTime? latestSentAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WidgetDeliveryState',
      'coupleId': coupleId,
      'recipientId': recipientId,
      'autoUpdateEnabled': autoUpdateEnabled,
      'version': version,
      if (latestAssetId != null) 'latestAssetId': latestAssetId,
      if (latestSenderId != null) 'latestSenderId': latestSenderId,
      if (latestSentAt != null) 'latestSentAt': latestSentAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WidgetDeliveryState',
      'coupleId': coupleId,
      'recipientId': recipientId,
      'autoUpdateEnabled': autoUpdateEnabled,
      'version': version,
      if (latestAssetId != null) 'latestAssetId': latestAssetId,
      if (latestSenderId != null) 'latestSenderId': latestSenderId,
      if (latestSentAt != null) 'latestSentAt': latestSentAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WidgetDeliveryStateImpl extends WidgetDeliveryState {
  _WidgetDeliveryStateImpl({
    required String coupleId,
    required String recipientId,
    required bool autoUpdateEnabled,
    required int version,
    String? latestAssetId,
    String? latestSenderId,
    DateTime? latestSentAt,
  }) : super._(
         coupleId: coupleId,
         recipientId: recipientId,
         autoUpdateEnabled: autoUpdateEnabled,
         version: version,
         latestAssetId: latestAssetId,
         latestSenderId: latestSenderId,
         latestSentAt: latestSentAt,
       );

  /// Returns a shallow copy of this [WidgetDeliveryState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  WidgetDeliveryState copyWith({
    String? coupleId,
    String? recipientId,
    bool? autoUpdateEnabled,
    int? version,
    Object? latestAssetId = _Undefined,
    Object? latestSenderId = _Undefined,
    Object? latestSentAt = _Undefined,
  }) {
    return WidgetDeliveryState(
      coupleId: coupleId ?? this.coupleId,
      recipientId: recipientId ?? this.recipientId,
      autoUpdateEnabled: autoUpdateEnabled ?? this.autoUpdateEnabled,
      version: version ?? this.version,
      latestAssetId: latestAssetId is String?
          ? latestAssetId
          : this.latestAssetId,
      latestSenderId: latestSenderId is String?
          ? latestSenderId
          : this.latestSenderId,
      latestSentAt: latestSentAt is DateTime?
          ? latestSentAt
          : this.latestSentAt,
    );
  }
}
