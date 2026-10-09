import 'package:closecall_client/closecall_client.dart' as api;

import '../domain/mood.dart';
import 'mood_repository.dart';

class ServerpodMoodRepository implements MoodRepository {
  ServerpodMoodRepository(
    api.Client client, {
    required String? Function() userId,
  }) : this.withCalls(
         userId: userId,
         current: client.mood.current,
         set: client.mood.setMood,
       );

  ServerpodMoodRepository.withCalls({
    required String? Function() userId,
    required Future<api.MoodState> Function() current,
    required Future<api.MoodState> Function(String) set,
  }) {
    _userId = userId;
    _current = current;
    _set = set;
  }

  late final String? Function() _userId;
  late final Future<api.MoodState> Function() _current;
  late final Future<api.MoodState> Function(String) _set;

  void _checkIdentity() {
    if (_userId() == null) {
      throw StateError('Mood requires the current authenticated user.');
    }
  }

  @override
  Future<MoodSnapshot> currentMood() async {
    _checkIdentity();
    return _map(await _current());
  }

  @override
  Future<MoodSnapshot> setMood(MoodKind mood) async {
    _checkIdentity();
    return _map(await _set(mood.key));
  }

  MoodSnapshot _map(api.MoodState state) {
    final id = _userId();
    if (id == null) {
      throw StateError('Mood requires the current authenticated user.');
    }
    MoodCheckIn? own;
    MoodCheckIn? partner;
    if (state.ownMood != null && state.ownUpdatedAt != null) {
      own = MoodCheckIn(
        userId: id,
        mood: MoodKind.fromKey(state.ownMood!),
        createdAt: state.ownUpdatedAt!,
      );
    }
    if (state.partnerMood != null &&
        state.partnerUpdatedAt != null &&
        state.partnerUserId != null) {
      partner = MoodCheckIn(
        userId: state.partnerUserId!,
        mood: MoodKind.fromKey(state.partnerMood!),
        createdAt: state.partnerUpdatedAt!,
      );
    }
    return MoodSnapshot(own: own, partner: partner);
  }
}
