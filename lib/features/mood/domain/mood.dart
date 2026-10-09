import 'package:meta/meta.dart';

/// The emotional check-in states a partner can broadcast. Order matches the
/// product spec and the home-screen mood picker.
enum MoodKind {
  happy('happy', 'Happy', '😊'),
  tired('tired', 'Tired', '😴'),
  busy('busy', 'Busy', '📎'),
  stressed('stressed', 'Stressed', '😮‍💨'),
  missingYou('missingYou', 'Missing You', '🥺'),
  excited('excited', 'Excited', '✨');

  const MoodKind(this.key, this.label, this.emoji);

  /// Stable storage key (used in Supabase and [AppColors.mood]).
  final String key;
  final String label;
  final String emoji;

  /// Parses a stored [key] back to a [MoodKind]; throws if unknown.
  static MoodKind fromKey(String key) {
    return MoodKind.values.firstWhere(
      (m) => m.key == key,
      orElse: () => throw ArgumentError.value(key, 'key', 'Unknown mood'),
    );
  }
}

/// A single mood update from one partner at a point in time.
@immutable
class MoodCheckIn {
  MoodCheckIn({
    required this.userId,
    required this.mood,
    required DateTime createdAt,
    this.note,
  }) : createdAt = createdAt.toUtc();

  final String userId;
  final MoodKind mood;
  final DateTime createdAt;
  final String? note;

  MoodCheckIn copyWith({
    String? userId,
    MoodKind? mood,
    DateTime? createdAt,
    String? note,
  }) {
    return MoodCheckIn(
      userId: userId ?? this.userId,
      mood: mood ?? this.mood,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }

  factory MoodCheckIn.fromJson(Map<String, dynamic> json) {
    return MoodCheckIn(
      userId: json['user_id'] as String,
      mood: MoodKind.fromKey(json['mood'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'mood': mood.key,
      'created_at': createdAt.toIso8601String(),
      'note': note,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is MoodCheckIn &&
      other.userId == userId &&
      other.mood == mood &&
      other.createdAt == createdAt &&
      other.note == note;

  @override
  int get hashCode => Object.hash(userId, mood, createdAt, note);
}

/// The latest mood owned by each member of the current couple.
@immutable
class MoodSnapshot {
  const MoodSnapshot({this.own, this.partner});

  final MoodCheckIn? own;
  final MoodCheckIn? partner;
}
