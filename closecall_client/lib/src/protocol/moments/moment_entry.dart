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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class MomentEntry
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  MomentEntry._({
    required this.momentId,
    required this.coupleId,
    required this.authorId,
    required this.text,
    required this.kind,
    this.durationMs,
    required this.createdAt,
  });

  factory MomentEntry({
    required String momentId,
    required String coupleId,
    required String authorId,
    required String text,
    required String kind,
    int? durationMs,
    required DateTime createdAt,
  }) = _MomentEntryImpl;

  factory MomentEntry.fromJson(Map<String, dynamic> jsonSerialization) {
    return MomentEntry(
      momentId: jsonSerialization['momentId'] as String,
      coupleId: jsonSerialization['coupleId'] as String,
      authorId: jsonSerialization['authorId'] as String,
      text: jsonSerialization['text'] as String,
      kind: jsonSerialization['kind'] as String,
      durationMs: jsonSerialization['durationMs'] as int?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  String momentId;

  String coupleId;

  String authorId;

  String text;

  String kind;

  int? durationMs;

  DateTime createdAt;

  /// Returns a shallow copy of this [MomentEntry]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  MomentEntry copyWith({
    String? momentId,
    String? coupleId,
    String? authorId,
    String? text,
    String? kind,
    int? durationMs,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MomentEntry',
      'momentId': momentId,
      'coupleId': coupleId,
      'authorId': authorId,
      'text': text,
      'kind': kind,
      if (durationMs != null) 'durationMs': durationMs,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MomentEntry',
      'momentId': momentId,
      'coupleId': coupleId,
      'authorId': authorId,
      'text': text,
      'kind': kind,
      if (durationMs != null) 'durationMs': durationMs,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MomentEntryImpl extends MomentEntry {
  _MomentEntryImpl({
    required String momentId,
    required String coupleId,
    required String authorId,
    required String text,
    required String kind,
    int? durationMs,
    required DateTime createdAt,
  }) : super._(
         momentId: momentId,
         coupleId: coupleId,
         authorId: authorId,
         text: text,
         kind: kind,
         durationMs: durationMs,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [MomentEntry]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  MomentEntry copyWith({
    String? momentId,
    String? coupleId,
    String? authorId,
    String? text,
    String? kind,
    Object? durationMs = _Undefined,
    DateTime? createdAt,
  }) {
    return MomentEntry(
      momentId: momentId ?? this.momentId,
      coupleId: coupleId ?? this.coupleId,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      kind: kind ?? this.kind,
      durationMs: durationMs is int? ? durationMs : this.durationMs,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
