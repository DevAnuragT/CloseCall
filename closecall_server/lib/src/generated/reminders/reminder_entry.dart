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

abstract class ReminderEntry
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ReminderEntry._({
    required this.id,
    required this.title,
    required this.kind,
    required this.remindAt,
    this.completedAt,
    required this.createdAt,
  });

  factory ReminderEntry({
    required _is.UuidValue id,
    required String title,
    required String kind,
    required DateTime remindAt,
    DateTime? completedAt,
    required DateTime createdAt,
  }) = _ReminderEntryImpl;

  factory ReminderEntry.fromJson(Map<String, dynamic> jsonSerialization) {
    return ReminderEntry(
      id: _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      title: jsonSerialization['title'] as String,
      kind: jsonSerialization['kind'] as String,
      remindAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['remindAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  _is.UuidValue id;

  String title;

  String kind;

  DateTime remindAt;

  DateTime? completedAt;

  DateTime createdAt;

  /// Returns a shallow copy of this [ReminderEntry]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ReminderEntry copyWith({
    _is.UuidValue? id,
    String? title,
    String? kind,
    DateTime? remindAt,
    DateTime? completedAt,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ReminderEntry',
      'id': id.toJson(),
      'title': title,
      'kind': kind,
      'remindAt': remindAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ReminderEntry',
      'id': id.toJson(),
      'title': title,
      'kind': kind,
      'remindAt': remindAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ReminderEntryImpl extends ReminderEntry {
  _ReminderEntryImpl({
    required _is.UuidValue id,
    required String title,
    required String kind,
    required DateTime remindAt,
    DateTime? completedAt,
    required DateTime createdAt,
  }) : super._(
         id: id,
         title: title,
         kind: kind,
         remindAt: remindAt,
         completedAt: completedAt,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ReminderEntry]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ReminderEntry copyWith({
    _is.UuidValue? id,
    String? title,
    String? kind,
    DateTime? remindAt,
    Object? completedAt = _Undefined,
    DateTime? createdAt,
  }) {
    return ReminderEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      remindAt: remindAt ?? this.remindAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
