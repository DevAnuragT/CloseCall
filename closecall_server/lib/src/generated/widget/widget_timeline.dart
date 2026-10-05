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
import 'package:closecall_server/src/generated/protocol.dart' as _iapnyesd;
import 'package:serverpod/serverpod.dart' as _is;
import '../widget/widget_schedule_entry.dart' as _il7dc4v7;

abstract class WidgetTimeline
    implements _is.SerializableModel, _is.ProtocolSerialization {
  WidgetTimeline._({
    required this.coupleId,
    required this.recipientId,
    this.fallbackAssetId,
    this.latestAssetId,
    int? deliveryVersion,
    bool? autoUpdateEnabled,
    this.currentAssetId,
    this.nextTransition,
    required this.schedules,
    required this.serverTime,
  }) : deliveryVersion = deliveryVersion ?? 0,
       autoUpdateEnabled = autoUpdateEnabled ?? false;

  factory WidgetTimeline({
    required String coupleId,
    required String recipientId,
    String? fallbackAssetId,
    String? latestAssetId,
    int? deliveryVersion,
    bool? autoUpdateEnabled,
    String? currentAssetId,
    DateTime? nextTransition,
    required List<_il7dc4v7.WidgetScheduleEntry> schedules,
    required DateTime serverTime,
  }) = _WidgetTimelineImpl;

  factory WidgetTimeline.fromJson(Map<String, dynamic> jsonSerialization) {
    return WidgetTimeline(
      coupleId: jsonSerialization['coupleId'] as String,
      recipientId: jsonSerialization['recipientId'] as String,
      fallbackAssetId: jsonSerialization['fallbackAssetId'] as String?,
      latestAssetId: jsonSerialization['latestAssetId'] as String?,
      deliveryVersion: jsonSerialization['deliveryVersion'] as int?,
      autoUpdateEnabled: jsonSerialization['autoUpdateEnabled'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['autoUpdateEnabled'],
            ),
      currentAssetId: jsonSerialization['currentAssetId'] as String?,
      nextTransition: jsonSerialization['nextTransition'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['nextTransition'],
            ),
      schedules: _iapnyesd.Protocol()
          .deserialize<List<_il7dc4v7.WidgetScheduleEntry>>(
            jsonSerialization['schedules'],
          ),
      serverTime: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['serverTime'],
      ),
    );
  }

  String coupleId;

  String recipientId;

  String? fallbackAssetId;

  String? latestAssetId;

  int deliveryVersion;

  bool autoUpdateEnabled;

  String? currentAssetId;

  DateTime? nextTransition;

  List<_il7dc4v7.WidgetScheduleEntry> schedules;

  DateTime serverTime;

  /// Returns a shallow copy of this [WidgetTimeline]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WidgetTimeline copyWith({
    String? coupleId,
    String? recipientId,
    String? fallbackAssetId,
    String? latestAssetId,
    int? deliveryVersion,
    bool? autoUpdateEnabled,
    String? currentAssetId,
    DateTime? nextTransition,
    List<_il7dc4v7.WidgetScheduleEntry>? schedules,
    DateTime? serverTime,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WidgetTimeline',
      'coupleId': coupleId,
      'recipientId': recipientId,
      if (fallbackAssetId != null) 'fallbackAssetId': fallbackAssetId,
      if (latestAssetId != null) 'latestAssetId': latestAssetId,
      'deliveryVersion': deliveryVersion,
      'autoUpdateEnabled': autoUpdateEnabled,
      if (currentAssetId != null) 'currentAssetId': currentAssetId,
      if (nextTransition != null) 'nextTransition': nextTransition?.toJson(),
      'schedules': schedules.toJson(valueToJson: (v) => v.toJson()),
      'serverTime': serverTime.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WidgetTimeline',
      'coupleId': coupleId,
      'recipientId': recipientId,
      if (fallbackAssetId != null) 'fallbackAssetId': fallbackAssetId,
      if (latestAssetId != null) 'latestAssetId': latestAssetId,
      'deliveryVersion': deliveryVersion,
      'autoUpdateEnabled': autoUpdateEnabled,
      if (currentAssetId != null) 'currentAssetId': currentAssetId,
      if (nextTransition != null) 'nextTransition': nextTransition?.toJson(),
      'schedules': schedules.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'serverTime': serverTime.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WidgetTimelineImpl extends WidgetTimeline {
  _WidgetTimelineImpl({
    required String coupleId,
    required String recipientId,
    String? fallbackAssetId,
    String? latestAssetId,
    int? deliveryVersion,
    bool? autoUpdateEnabled,
    String? currentAssetId,
    DateTime? nextTransition,
    required List<_il7dc4v7.WidgetScheduleEntry> schedules,
    required DateTime serverTime,
  }) : super._(
         coupleId: coupleId,
         recipientId: recipientId,
         fallbackAssetId: fallbackAssetId,
         latestAssetId: latestAssetId,
         deliveryVersion: deliveryVersion,
         autoUpdateEnabled: autoUpdateEnabled,
         currentAssetId: currentAssetId,
         nextTransition: nextTransition,
         schedules: schedules,
         serverTime: serverTime,
       );

  /// Returns a shallow copy of this [WidgetTimeline]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WidgetTimeline copyWith({
    String? coupleId,
    String? recipientId,
    Object? fallbackAssetId = _Undefined,
    Object? latestAssetId = _Undefined,
    int? deliveryVersion,
    bool? autoUpdateEnabled,
    Object? currentAssetId = _Undefined,
    Object? nextTransition = _Undefined,
    List<_il7dc4v7.WidgetScheduleEntry>? schedules,
    DateTime? serverTime,
  }) {
    return WidgetTimeline(
      coupleId: coupleId ?? this.coupleId,
      recipientId: recipientId ?? this.recipientId,
      fallbackAssetId: fallbackAssetId is String?
          ? fallbackAssetId
          : this.fallbackAssetId,
      latestAssetId: latestAssetId is String?
          ? latestAssetId
          : this.latestAssetId,
      deliveryVersion: deliveryVersion ?? this.deliveryVersion,
      autoUpdateEnabled: autoUpdateEnabled ?? this.autoUpdateEnabled,
      currentAssetId: currentAssetId is String?
          ? currentAssetId
          : this.currentAssetId,
      nextTransition: nextTransition is DateTime?
          ? nextTransition
          : this.nextTransition,
      schedules:
          schedules ?? this.schedules.map((e0) => e0.copyWith()).toList(),
      serverTime: serverTime ?? this.serverTime,
    );
  }
}
