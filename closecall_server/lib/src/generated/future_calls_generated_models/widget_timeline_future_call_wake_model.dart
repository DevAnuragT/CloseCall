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

abstract class WidgetTimelineFutureCallWakeModel
    implements _is.SerializableModel, _is.ProtocolSerialization {
  WidgetTimelineFutureCallWakeModel._({required this.scheduleId});

  factory WidgetTimelineFutureCallWakeModel({required String scheduleId}) =
      _WidgetTimelineFutureCallWakeModelImpl;

  factory WidgetTimelineFutureCallWakeModel.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WidgetTimelineFutureCallWakeModel(
      scheduleId: jsonSerialization['scheduleId'] as String,
    );
  }

  String scheduleId;

  /// Returns a shallow copy of this [WidgetTimelineFutureCallWakeModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WidgetTimelineFutureCallWakeModel copyWith({String? scheduleId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WidgetTimelineFutureCallWakeModel',
      'scheduleId': scheduleId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _WidgetTimelineFutureCallWakeModelImpl
    extends WidgetTimelineFutureCallWakeModel {
  _WidgetTimelineFutureCallWakeModelImpl({required String scheduleId})
    : super._(scheduleId: scheduleId);

  /// Returns a shallow copy of this [WidgetTimelineFutureCallWakeModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WidgetTimelineFutureCallWakeModel copyWith({String? scheduleId}) {
    return WidgetTimelineFutureCallWakeModel(
      scheduleId: scheduleId ?? this.scheduleId,
    );
  }
}
