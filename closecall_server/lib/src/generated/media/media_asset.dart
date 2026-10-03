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

abstract class MediaAsset
    implements _is.SerializableModel, _is.ProtocolSerialization {
  MediaAsset._({
    required this.assetId,
    required this.coupleId,
    required this.uploaderId,
    required this.createdAt,
    required this.width,
    required this.height,
  });

  factory MediaAsset({
    required String assetId,
    required String coupleId,
    required String uploaderId,
    required DateTime createdAt,
    required int width,
    required int height,
  }) = _MediaAssetImpl;

  factory MediaAsset.fromJson(Map<String, dynamic> jsonSerialization) {
    return MediaAsset(
      assetId: jsonSerialization['assetId'] as String,
      coupleId: jsonSerialization['coupleId'] as String,
      uploaderId: jsonSerialization['uploaderId'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      width: jsonSerialization['width'] as int,
      height: jsonSerialization['height'] as int,
    );
  }

  String assetId;

  String coupleId;

  String uploaderId;

  DateTime createdAt;

  int width;

  int height;

  /// Returns a shallow copy of this [MediaAsset]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  MediaAsset copyWith({
    String? assetId,
    String? coupleId,
    String? uploaderId,
    DateTime? createdAt,
    int? width,
    int? height,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MediaAsset',
      'assetId': assetId,
      'coupleId': coupleId,
      'uploaderId': uploaderId,
      'createdAt': createdAt.toJson(),
      'width': width,
      'height': height,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MediaAsset',
      'assetId': assetId,
      'coupleId': coupleId,
      'uploaderId': uploaderId,
      'createdAt': createdAt.toJson(),
      'width': width,
      'height': height,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _MediaAssetImpl extends MediaAsset {
  _MediaAssetImpl({
    required String assetId,
    required String coupleId,
    required String uploaderId,
    required DateTime createdAt,
    required int width,
    required int height,
  }) : super._(
         assetId: assetId,
         coupleId: coupleId,
         uploaderId: uploaderId,
         createdAt: createdAt,
         width: width,
         height: height,
       );

  /// Returns a shallow copy of this [MediaAsset]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  MediaAsset copyWith({
    String? assetId,
    String? coupleId,
    String? uploaderId,
    DateTime? createdAt,
    int? width,
    int? height,
  }) {
    return MediaAsset(
      assetId: assetId ?? this.assetId,
      coupleId: coupleId ?? this.coupleId,
      uploaderId: uploaderId ?? this.uploaderId,
      createdAt: createdAt ?? this.createdAt,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}
