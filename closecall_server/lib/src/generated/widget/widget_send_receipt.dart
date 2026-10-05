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

abstract class WidgetSendReceipt
    implements _is.SerializableModel, _is.ProtocolSerialization {
  WidgetSendReceipt._({
    required this.sendId,
    required this.requestId,
    required this.coupleId,
    required this.senderId,
    required this.recipientId,
    required this.assetId,
    required this.version,
    required this.createdAt,
    required this.recipientAutoUpdateEnabled,
  });

  factory WidgetSendReceipt({
    required String sendId,
    required String requestId,
    required String coupleId,
    required String senderId,
    required String recipientId,
    required String assetId,
    required int version,
    required DateTime createdAt,
    required bool recipientAutoUpdateEnabled,
  }) = _WidgetSendReceiptImpl;

  factory WidgetSendReceipt.fromJson(Map<String, dynamic> jsonSerialization) {
    return WidgetSendReceipt(
      sendId: jsonSerialization['sendId'] as String,
      requestId: jsonSerialization['requestId'] as String,
      coupleId: jsonSerialization['coupleId'] as String,
      senderId: jsonSerialization['senderId'] as String,
      recipientId: jsonSerialization['recipientId'] as String,
      assetId: jsonSerialization['assetId'] as String,
      version: jsonSerialization['version'] as int,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      recipientAutoUpdateEnabled: _is.BoolJsonExtension.fromJson(
        jsonSerialization['recipientAutoUpdateEnabled'],
      ),
    );
  }

  String sendId;

  String requestId;

  String coupleId;

  String senderId;

  String recipientId;

  String assetId;

  int version;

  DateTime createdAt;

  bool recipientAutoUpdateEnabled;

  /// Returns a shallow copy of this [WidgetSendReceipt]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WidgetSendReceipt copyWith({
    String? sendId,
    String? requestId,
    String? coupleId,
    String? senderId,
    String? recipientId,
    String? assetId,
    int? version,
    DateTime? createdAt,
    bool? recipientAutoUpdateEnabled,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WidgetSendReceipt',
      'sendId': sendId,
      'requestId': requestId,
      'coupleId': coupleId,
      'senderId': senderId,
      'recipientId': recipientId,
      'assetId': assetId,
      'version': version,
      'createdAt': createdAt.toJson(),
      'recipientAutoUpdateEnabled': recipientAutoUpdateEnabled,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WidgetSendReceipt',
      'sendId': sendId,
      'requestId': requestId,
      'coupleId': coupleId,
      'senderId': senderId,
      'recipientId': recipientId,
      'assetId': assetId,
      'version': version,
      'createdAt': createdAt.toJson(),
      'recipientAutoUpdateEnabled': recipientAutoUpdateEnabled,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _WidgetSendReceiptImpl extends WidgetSendReceipt {
  _WidgetSendReceiptImpl({
    required String sendId,
    required String requestId,
    required String coupleId,
    required String senderId,
    required String recipientId,
    required String assetId,
    required int version,
    required DateTime createdAt,
    required bool recipientAutoUpdateEnabled,
  }) : super._(
         sendId: sendId,
         requestId: requestId,
         coupleId: coupleId,
         senderId: senderId,
         recipientId: recipientId,
         assetId: assetId,
         version: version,
         createdAt: createdAt,
         recipientAutoUpdateEnabled: recipientAutoUpdateEnabled,
       );

  /// Returns a shallow copy of this [WidgetSendReceipt]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WidgetSendReceipt copyWith({
    String? sendId,
    String? requestId,
    String? coupleId,
    String? senderId,
    String? recipientId,
    String? assetId,
    int? version,
    DateTime? createdAt,
    bool? recipientAutoUpdateEnabled,
  }) {
    return WidgetSendReceipt(
      sendId: sendId ?? this.sendId,
      requestId: requestId ?? this.requestId,
      coupleId: coupleId ?? this.coupleId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      assetId: assetId ?? this.assetId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      recipientAutoUpdateEnabled:
          recipientAutoUpdateEnabled ?? this.recipientAutoUpdateEnabled,
    );
  }
}
