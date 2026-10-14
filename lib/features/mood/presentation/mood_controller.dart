import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../pairing/presentation/pairing_controller.dart';
import '../data/mood_repository.dart';
import '../domain/mood.dart';

/// Owns the live mood read/write lifecycle and never masks transport failures.
class MoodController extends ChangeNotifier {
  MoodController({required this.pairing, required this.repository}) {
    pairing.addListener(_pairingChanged);
  }

  final PairingController pairing;
  final MoodRepository repository;
  MoodSnapshot? snapshot;
  Object? error;
  bool loading = false;
  bool saving = false;
  MoodKind? _failedMood;
  bool _started = false;
  bool _disposed = false;
  // The live app explicitly supplies lifecycle state. Keeping this false
  // until then prevents standalone controllers/tests from starting a timer.
  bool _foreground = false;
  int _revision = 0;
  Timer? _pollTimer;

  static const _pollInterval = Duration(seconds: 15);
  static const _automaticRetryDelays = <Duration>[
    Duration(milliseconds: 150),
    Duration(milliseconds: 400),
  ];

  bool get paired => pairing.couple?.isComplete == true;
  bool get hasFailedMood => _failedMood != null;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _pairingChanged();
  }

  /// Keep the partner's check-in current while the Home screen is usable,
  /// without creating a background network loop when Android suspends the app.
  void setForeground(bool value) {
    if (_disposed || _foreground == value) return;
    _foreground = value;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_foreground && paired && !loading && !saving) {
      unawaited(refresh(automatic: true));
    }
  }

  void _pairingChanged() {
    if (!_started || _disposed) return;
    if (!paired) {
      _revision++;
      _pollTimer?.cancel();
      _pollTimer = null;
      snapshot = null;
      error = null;
      _failedMood = null;
      loading = false;
      saving = false;
      notifyListeners();
      return;
    }
    if (!loading && !saving) unawaited(refresh(automatic: true));
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (_disposed || !_foreground || !paired || loading || saving) return;
    _pollTimer = Timer(_pollInterval, () {
      _pollTimer = null;
      if (!_disposed && _foreground && paired) {
        unawaited(refresh(automatic: true));
      }
    });
  }

  Future<void> refresh({bool automatic = false}) async {
    if (_disposed || !paired || loading || saving) return;
    final revision = ++_revision;
    final attempts = automatic ? _automaticRetryDelays.length + 1 : 1;
    loading = true;
    error = null;
    notifyListeners();
    try {
      for (var attempt = 0; attempt < attempts; attempt++) {
        if (_disposed || revision != _revision || !paired) return;
        try {
          final result = await repository.currentMood();
          if (_disposed || revision != _revision || !paired) return;
          snapshot = result;
          return;
        } catch (failure) {
          final canRetry =
              attempt + 1 < attempts &&
              !_disposed &&
              revision == _revision &&
              paired;
          if (!canRetry) {
            if (!_disposed && revision == _revision && paired) {
              error = failure;
            }
            return;
          }
          await Future<void>.delayed(_automaticRetryDelays[attempt]);
        }
      }
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        notifyListeners();
        _schedulePoll();
      }
    }
  }

  Future<void> setMood(MoodKind mood) async {
    if (_disposed || !paired || loading || saving) return;
    final revision = ++_revision;
    _failedMood = mood;
    saving = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.setMood(mood);
      if (_disposed || revision != _revision || !paired) return;
      snapshot = result;
      _failedMood = null;
    } catch (failure) {
      if (!_disposed && revision == _revision && paired) error = failure;
    } finally {
      if (!_disposed && revision == _revision) {
        saving = false;
        notifyListeners();
        _schedulePoll();
      }
    }
  }

  Future<void> retryMood() async {
    final mood = _failedMood;
    if (mood != null) await setMood(mood);
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _pollTimer?.cancel();
    pairing.removeListener(_pairingChanged);
    super.dispose();
  }
}
