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

abstract class TimelineNotice
    implements _is.SerializableModel, _is.ProtocolSerialization {
  TimelineNotice._({required this.recipientId, this.deliveryVersion});

  factory TimelineNotice({required String recipientId, int? deliveryVersion}) =
      _TimelineNoticeImpl;

  factory TimelineNotice.fromJson(Map<String, dynamic> jsonSerialization) {
    return TimelineNotice(
      recipientId: jsonSerialization['recipientId'] as String,
      deliveryVersion: jsonSerialization['deliveryVersion'] as int?,
    );
  }

  String recipientId;

  int? deliveryVersion;

  /// Returns a shallow copy of this [TimelineNotice]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  TimelineNotice copyWith({String? recipientId, int? deliveryVersion});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TimelineNotice',
      'recipientId': recipientId,
      if (deliveryVersion != null) 'deliveryVersion': deliveryVersion,
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

class _Undefined {}

class _TimelineNoticeImpl extends TimelineNotice {
  _TimelineNoticeImpl({required String recipientId, int? deliveryVersion})
    : super._(recipientId: recipientId, deliveryVersion: deliveryVersion);

  /// Returns a shallow copy of this [TimelineNotice]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  TimelineNotice copyWith({
    String? recipientId,
    Object? deliveryVersion = _Undefined,
  }) {
    return TimelineNotice(
      recipientId: recipientId ?? this.recipientId,
      deliveryVersion: deliveryVersion is int?
          ? deliveryVersion
          : this.deliveryVersion,
    );
  }
}
