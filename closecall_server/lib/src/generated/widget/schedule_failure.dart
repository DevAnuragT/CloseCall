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

abstract class ScheduleFailure
    implements
        _is.SerializableException,
        _is.SerializableModel,
        _is.ProtocolSerialization {
  ScheduleFailure._({required this.code});

  factory ScheduleFailure({required String code}) = _ScheduleFailureImpl;

  factory ScheduleFailure.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScheduleFailure(code: jsonSerialization['code'] as String);
  }

  String code;

  /// Returns a shallow copy of this [ScheduleFailure]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ScheduleFailure copyWith({String? code});
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'ScheduleFailure', 'code': code};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'ScheduleFailure', 'code': code};
  }

  @override
  String toString() {
    return 'ScheduleFailure(code: $code)';
  }
}

class _ScheduleFailureImpl extends ScheduleFailure {
  _ScheduleFailureImpl({required String code}) : super._(code: code);

  /// Returns a shallow copy of this [ScheduleFailure]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ScheduleFailure copyWith({String? code}) {
    return ScheduleFailure(code: code ?? this.code);
  }
}
