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

abstract class PushFailure
    implements
        _is.SerializableException,
        _is.SerializableModel,
        _is.ProtocolSerialization {
  PushFailure._({required this.code});

  factory PushFailure({required String code}) = _PushFailureImpl;

  factory PushFailure.fromJson(Map<String, dynamic> jsonSerialization) {
    return PushFailure(code: jsonSerialization['code'] as String);
  }

  String code;

  /// Returns a shallow copy of this [PushFailure]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PushFailure copyWith({String? code});
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'PushFailure', 'code': code};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'PushFailure', 'code': code};
  }

  @override
  String toString() {
    return 'PushFailure(code: $code)';
  }
}

class _PushFailureImpl extends PushFailure {
  _PushFailureImpl({required String code}) : super._(code: code);

  /// Returns a shallow copy of this [PushFailure]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PushFailure copyWith({String? code}) {
    return PushFailure(code: code ?? this.code);
  }
}
