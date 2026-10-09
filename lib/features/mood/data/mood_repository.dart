import '../domain/mood.dart';

/// Reads and writes the one current mood owned by each paired member.
abstract interface class MoodRepository {
  Future<MoodSnapshot> currentMood();

  Future<MoodSnapshot> setMood(MoodKind mood);
}
