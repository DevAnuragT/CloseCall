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

abstract class MomentFailure
    implements
        _is.SerializableException,
        _is.SerializableModel,
        _is.ProtocolSerialization {
  MomentFailure._({required this.code});

  factory MomentFailure({required String code}) = _MomentFailureImpl;

  factory MomentFailure.fromJson(Map<String, dynamic> jsonSerialization) {
    return MomentFailure(code: jsonSerialization['code'] as String);
  }

  String code;

  /// Returns a shallow copy of this [MomentFailure]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MomentFailure copyWith({String? code});
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'MomentFailure', 'code': code};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'MomentFailure', 'code': code};
  }

  @override
  String toString() {
    return 'MomentFailure(code: $code)';
  }
}

class _MomentFailureImpl extends MomentFailure {
  _MomentFailureImpl({required String code}) : super._(code: code);

  /// Returns a shallow copy of this [MomentFailure]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MomentFailure copyWith({String? code}) {
    return MomentFailure(code: code ?? this.code);
  }
}
