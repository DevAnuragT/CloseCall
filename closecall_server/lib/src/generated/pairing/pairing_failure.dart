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

abstract class PairingFailure
    implements
        _is.SerializableException,
        _is.SerializableModel,
        _is.ProtocolSerialization {
  PairingFailure._({required this.code});

  factory PairingFailure({required String code}) = _PairingFailureImpl;

  factory PairingFailure.fromJson(Map<String, dynamic> jsonSerialization) {
    return PairingFailure(code: jsonSerialization['code'] as String);
  }

  String code;

  /// Returns a shallow copy of this [PairingFailure]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PairingFailure copyWith({String? code});
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'PairingFailure', 'code': code};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'PairingFailure', 'code': code};
  }

  @override
  String toString() {
    return 'PairingFailure(code: $code)';
  }
}

class _PairingFailureImpl extends PairingFailure {
  _PairingFailureImpl({required String code}) : super._(code: code);

  /// Returns a shallow copy of this [PairingFailure]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PairingFailure copyWith({String? code}) {
    return PairingFailure(code: code ?? this.code);
  }
}
