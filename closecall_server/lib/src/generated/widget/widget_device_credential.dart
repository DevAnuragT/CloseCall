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

abstract class WidgetDeviceCredential
    implements _is.SerializableModel, _is.ProtocolSerialization {
  WidgetDeviceCredential._({
    required this.credential,
    required this.deviceId,
    required this.userId,
    required this.coupleId,
    required this.expiresAt,
  });

  factory WidgetDeviceCredential({
    required String credential,
    required String deviceId,
    required String userId,
    required String coupleId,
    required DateTime expiresAt,
  }) = _WidgetDeviceCredentialImpl;

  factory WidgetDeviceCredential.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WidgetDeviceCredential(
      credential: jsonSerialization['credential'] as String,
      deviceId: jsonSerialization['deviceId'] as String,
      userId: jsonSerialization['userId'] as String,
      coupleId: jsonSerialization['coupleId'] as String,
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  String credential;

  String deviceId;

  String userId;

  String coupleId;

  DateTime expiresAt;

  /// Returns a shallow copy of this [WidgetDeviceCredential]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WidgetDeviceCredential copyWith({
    String? credential,
    String? deviceId,
    String? userId,
    String? coupleId,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WidgetDeviceCredential',
      'credential': credential,
      'deviceId': deviceId,
      'userId': userId,
      'coupleId': coupleId,
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WidgetDeviceCredential',
      'credential': credential,
      'deviceId': deviceId,
      'userId': userId,
      'coupleId': coupleId,
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _WidgetDeviceCredentialImpl extends WidgetDeviceCredential {
  _WidgetDeviceCredentialImpl({
    required String credential,
    required String deviceId,
    required String userId,
    required String coupleId,
    required DateTime expiresAt,
  }) : super._(
         credential: credential,
         deviceId: deviceId,
         userId: userId,
         coupleId: coupleId,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [WidgetDeviceCredential]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WidgetDeviceCredential copyWith({
    String? credential,
    String? deviceId,
    String? userId,
    String? coupleId,
    DateTime? expiresAt,
  }) {
    return WidgetDeviceCredential(
      credential: credential ?? this.credential,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      coupleId: coupleId ?? this.coupleId,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
