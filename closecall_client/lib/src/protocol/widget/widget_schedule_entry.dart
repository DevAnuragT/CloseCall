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

abstract class WidgetScheduleEntry
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  WidgetScheduleEntry._({
    required this.scheduleId,
    required this.assetId,
    required this.senderId,
    required this.recipientId,
    required this.activeFrom,
    required this.activeUntil,
    required this.createdAt,
  });

  factory WidgetScheduleEntry({
    required String scheduleId,
    required String assetId,
    required String senderId,
    required String recipientId,
    required DateTime activeFrom,
    required DateTime activeUntil,
    required DateTime createdAt,
  }) = _WidgetScheduleEntryImpl;

  factory WidgetScheduleEntry.fromJson(Map<String, dynamic> jsonSerialization) {
    return WidgetScheduleEntry(
      scheduleId: jsonSerialization['scheduleId'] as String,
      assetId: jsonSerialization['assetId'] as String,
      senderId: jsonSerialization['senderId'] as String,
      recipientId: jsonSerialization['recipientId'] as String,
      activeFrom: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['activeFrom'],
      ),
      activeUntil: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['activeUntil'],
      ),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  String scheduleId;

  String assetId;

  String senderId;

  String recipientId;

  DateTime activeFrom;

  DateTime activeUntil;

  DateTime createdAt;

  /// Returns a shallow copy of this [WidgetScheduleEntry]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  WidgetScheduleEntry copyWith({
    String? scheduleId,
    String? assetId,
    String? senderId,
    String? recipientId,
    DateTime? activeFrom,
    DateTime? activeUntil,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WidgetScheduleEntry',
      'scheduleId': scheduleId,
      'assetId': assetId,
      'senderId': senderId,
      'recipientId': recipientId,
      'activeFrom': activeFrom.toJson(),
      'activeUntil': activeUntil.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WidgetScheduleEntry',
      'scheduleId': scheduleId,
      'assetId': assetId,
      'senderId': senderId,
      'recipientId': recipientId,
      'activeFrom': activeFrom.toJson(),
      'activeUntil': activeUntil.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _WidgetScheduleEntryImpl extends WidgetScheduleEntry {
  _WidgetScheduleEntryImpl({
    required String scheduleId,
    required String assetId,
    required String senderId,
    required String recipientId,
    required DateTime activeFrom,
    required DateTime activeUntil,
    required DateTime createdAt,
  }) : super._(
         scheduleId: scheduleId,
         assetId: assetId,
         senderId: senderId,
         recipientId: recipientId,
         activeFrom: activeFrom,
         activeUntil: activeUntil,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [WidgetScheduleEntry]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  WidgetScheduleEntry copyWith({
    String? scheduleId,
    String? assetId,
    String? senderId,
    String? recipientId,
    DateTime? activeFrom,
    DateTime? activeUntil,
    DateTime? createdAt,
  }) {
    return WidgetScheduleEntry(
      scheduleId: scheduleId ?? this.scheduleId,
      assetId: assetId ?? this.assetId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      activeFrom: activeFrom ?? this.activeFrom,
      activeUntil: activeUntil ?? this.activeUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
