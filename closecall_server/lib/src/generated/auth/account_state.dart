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

abstract class AccountState
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AccountState._({required this.userId, required this.isGuest, this.email});

  factory AccountState({
    required String userId,
    required bool isGuest,
    String? email,
  }) = _AccountStateImpl;

  factory AccountState.fromJson(Map<String, dynamic> jsonSerialization) {
    return AccountState(
      userId: jsonSerialization['userId'] as String,
      isGuest: _is.BoolJsonExtension.fromJson(jsonSerialization['isGuest']),
      email: jsonSerialization['email'] as String?,
    );
  }

  String userId;

  bool isGuest;

  String? email;

  /// Returns a shallow copy of this [AccountState]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AccountState copyWith({String? userId, bool? isGuest, String? email});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AccountState',
      'userId': userId,
      'isGuest': isGuest,
      if (email != null) 'email': email,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AccountState',
      'userId': userId,
      'isGuest': isGuest,
      if (email != null) 'email': email,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AccountStateImpl extends AccountState {
  _AccountStateImpl({
    required String userId,
    required bool isGuest,
    String? email,
  }) : super._(userId: userId, isGuest: isGuest, email: email);

  /// Returns a shallow copy of this [AccountState]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AccountState copyWith({
    String? userId,
    bool? isGuest,
    Object? email = _Undefined,
  }) {
    return AccountState(
      userId: userId ?? this.userId,
      isGuest: isGuest ?? this.isGuest,
      email: email is String? ? email : this.email,
    );
  }
}
