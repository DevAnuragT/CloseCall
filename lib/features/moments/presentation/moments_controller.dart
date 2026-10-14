import 'dart:async';
import 'dart:typed_data';

import 'package:closecall_client/closecall_client.dart' as api;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../pairing/presentation/pairing_controller.dart';
import '../data/moment_audio.dart';
import '../data/moments_repository.dart';

class MomentsController extends ChangeNotifier {
  MomentsController({
    required this.pairing,
    required this.repository,
    required this.audio,
    String Function()? requestId,
  }) : _requestId = requestId ?? const Uuid().v4 {
    _scope = _currentScope;
    pairing.addListener(_scopeChanged);
    pairing.session.addListener(_scopeChanged);
    _completion = audio.completed.listen((_) {
      if (playingId != null) unawaited(stopPlayback());
    });
  }

  final PairingController pairing;
  final MomentsRepository repository;
  final MomentAudio audio;
  final String Function() _requestId;
  String? _scope;
  int _revision = 0;
  int _feedRevision = 0;
  int _playRevision = 0;
  int _recordRevision = 0;
  int _draftRevision = 0;
  bool _disposed = false;
  bool _foreground = true;
  bool _started = false;
  Future<void> _audioQueue = Future.value();
  StreamSubscription<void>? _completion;
  StreamSubscription<Uint8List>? _recordingStream;
  Timer? _recordTimer;
  final _pcm = BytesBuilder(copy: true);
  DateTime? _recordingAt;
  Uint8List? _voice;
  _PendingMoment? _pending;
  String? _failedCursor;
  bool _failedFeed = false;
  api.MomentEntry? _failedDelete;

  List<api.MomentEntry> entries = [];
  bool loading = false;
  bool loaded = false;
  bool hasMore = false;
  String? feedError;
  bool composerOpen = false;
  String draftText = '';
  bool publishing = false;
  String? composerError;
  bool audioBusy = false;
  bool recording = false;
  String? audioError;
  String? loadingVoiceId;
  String? playingId;
  String? voiceErrorId;
  String? deletingId;
  String? deleteErrorId;
  String? highlightedMomentId;

  static const _automaticRetryDelays = <Duration>[
    Duration(milliseconds: 150),
    Duration(milliseconds: 400),
  ];

  bool get canCreate => !_disposed && _currentScope != null;
  int get scopeRevision => _revision;
  bool get hasVoice => _voice != null;
  bool get hasPendingPublish => _pending != null;
  int? get voiceDurationMs =>
      _voice == null ? null : validateMomentWav(_voice!);
  int get recordingSeconds => _recordingAt == null
      ? 0
      : DateTime.now().difference(_recordingAt!).inSeconds.clamp(0, 30);
  String? get _currentScope {
    final couple = pairing.couple;
    final id = pairing.userId;
    if (!pairing.hasLoadedPairing ||
        id == null ||
        couple?.isComplete != true ||
        !couple!.memberIds.contains(id) ||
        couple.partnerOf(id) == null ||
        couple.partnerOf(id)!.isEmpty) {
      return null;
    }
    return '$id:${pairing.authRevision}/${couple.id}/${couple.partnerOf(id)}';
  }

  bool _current(int revision) =>
      !_disposed &&
      revision == _revision &&
      _scope != null &&
      _scope == _currentScope;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String authorLabel(api.MomentEntry entry) => entry.authorId == pairing.userId
      ? pairing.couple?.ownNickname ?? 'You'
      : pairing.couple?.partnerNickname ?? 'Your partner';

  void start() {
    if (_started || _disposed) return;
    _started = true;
    if (canCreate) unawaited(refresh(automatic: true));
  }

  void _scopeChanged() {
    if (_scope == _currentScope) {
      _notify();
      return;
    }
    _scope = _currentScope;
    _revision++;
    _feedRevision++;
    entries = [];
    loaded = loading = hasMore = false;
    feedError = null;
    _failedFeed = false;
    _failedCursor = null;
    _failedDelete = null;
    deleteErrorId = deletingId = null;
    publishing = false;
    _clearDraft();
    _invalidateAudio();
    _notify();
    if (_started && canCreate) unawaited(refresh(automatic: true));
  }

  bool _validEntry(api.MomentEntry entry) =>
      entry.momentId.isNotEmpty &&
      entry.coupleId == pairing.couple?.id &&
      pairing.couple!.memberIds.contains(entry.authorId) &&
      (entry.kind == 'text' || entry.kind == 'voice');

  Future<void> refresh({bool automatic = false}) =>
      _load(null, automatic: automatic);

  /// Refreshes the private feed after a partner notification and leaves the
  /// opaque id available to the screen for a short-lived visual cue. The
  /// server remains authoritative; the push payload is never treated as
  /// permission to read a different couple's data.
  Future<void> openFromNotification(String momentId) async {
    if (!canCreate || !_isUuid(momentId)) return;
    highlightedMomentId = momentId;
    _notify();
    await refresh(automatic: true);
  }

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
  Future<void> loadMore() async {
    if (hasMore && entries.isNotEmpty && entries.length < 100) {
      await _load(entries.last.momentId);
    }
  }

  Future<void> retryFeed() async {
    if (_failedFeed) await _load(_failedCursor);
  }

  Future<void> _load(String? cursor, {bool automatic = false}) async {
    if (!canCreate || loading) return;
    final revision = _revision;
    final feed = ++_feedRevision;
    final attempts = automatic && cursor == null
        ? _automaticRetryDelays.length + 1
        : 1;
    loading = true;
    feedError = null;
    _failedFeed = false;
    _notify();
    try {
      for (var attempt = 0; attempt < attempts; attempt++) {
        if (!_current(revision) || feed != _feedRevision) return;
        try {
          final result = await repository.list(beforeId: cursor, limit: 20);
          if (!_current(revision) || feed != _feedRevision) return;
          if (result.length > 20 || result.any((e) => !_validEntry(e))) {
            throw StateError('Moments outside the current couple.');
          }
          final previousIds = entries.map((e) => e.momentId).toSet();
          final merged = <String, api.MomentEntry>{
            if (cursor != null)
              for (final e in entries) e.momentId: e,
            for (final e in result) e.momentId: e,
          };
          entries = merged.values.toList()..sort(_newestFirst);
          entries = entries.take(100).toList();
          hasMore =
              result.length == 20 &&
              entries.length < 100 &&
              (cursor == null ||
                  result.any((e) => !previousIds.contains(e.momentId)));
          loaded = true;
          return;
        } catch (_) {
          final canRetry =
              attempt + 1 < attempts &&
              _current(revision) &&
              feed == _feedRevision;
          if (!canRetry) {
            if (_current(revision) && feed == _feedRevision) {
              feedError = 'Couldn’t load your moments. Pull down to refresh.';
              _failedFeed = true;
              _failedCursor = cursor;
            }
            return;
          }
          await Future<void>.delayed(_automaticRetryDelays[attempt]);
        }
      }
    } finally {
      if (_current(revision) && feed == _feedRevision) {
        loading = false;
        _notify();
      }
    }
  }

  static int _newestFirst(api.MomentEntry a, api.MomentEntry b) {
    final time = b.createdAt.compareTo(a.createdAt);
    return time == 0 ? b.momentId.compareTo(a.momentId) : time;
  }

  void openComposer() {
    if (!canCreate) return;
    composerOpen = true;
    _notify();
  }

  void setText(String text) {
    if (!canCreate || publishing || hasPendingPublish) return;
    draftText = text;
    composerError = null;
    _notify();
  }

  void _clearDraft() {
    _draftRevision++;
    _pending = null;
    _voice = null;
    draftText = '';
    composerOpen = false;
    composerError = null;
  }

  void cancelDraft() {
    if (publishing) return;
    _clearDraft();
    _invalidateAudio();
    _notify();
  }

  Future<bool> publish() async {
    if (!canCreate || publishing || recording || audioBusy) return false;
    if (_pending != null) return false;
    if (draftText.length > 2000 ||
        draftText.runes.length > 1000 ||
        (draftText.trim().isEmpty && !hasVoice)) {
      composerError =
          'Add a note (up to 1000 characters) or record a voice moment.';
      _notify();
      return false;
    }
    _pending = _PendingMoment(
      _requestId(),
      draftText,
      _voice == null ? null : Uint8List.fromList(_voice!).asUnmodifiableView(),
      _revision,
    );
    return _sendPending();
  }

  Future<bool> retryPublish() => _sendPending();
  Future<bool> _sendPending() async {
    final pending = _pending;
    if (pending == null || publishing || !_current(pending.revision)) {
      return false;
    }
    publishing = true;
    composerError = null;
    _notify();
    try {
      final result = await repository.create(
        requestId: pending.requestId,
        text: pending.text,
        voiceBytes: pending.voice == null
            ? null
            : ByteData.sublistView(Uint8List.fromList(pending.voice!)),
      );
      if (!_current(pending.revision) || !identical(_pending, pending)) {
        return false;
      }
      if (!_validEntry(result) || result.authorId != pairing.userId) {
        throw StateError('Moment outside the current couple.');
      }
      _feedRevision++;
      loading = false;
      entries = [result, ...entries.where((e) => e.momentId != result.momentId)]
        ..sort(_newestFirst);
      entries = entries.take(100).toList();
      loaded = true;
      hasMore = hasMore && entries.length < 100;
      _clearDraft();
      _invalidateAudio();
      return true;
    } catch (failure) {
      if (_current(pending.revision) && identical(_pending, pending)) {
        final confirmed = failure is api.MomentFailure
            ? _confirmedPublishError(failure.code)
            : null;
        if (confirmed != null) {
          _pending = null;
          composerError = confirmed;
        } else {
          composerError =
              'Couldn’t confirm publication. Retry sends the same moment safely.';
        }
      }
      return false;
    } finally {
      if (_current(pending.revision)) {
        publishing = false;
        _notify();
      }
    }
  }

  String? _confirmedPublishError(String code) => switch (code) {
    'invalid_text' =>
      'Keep your note within 1000 characters, or add a voice moment.',
    'invalid_voice' ||
    'file_too_large' => 'Please record your voice again (up to 30 seconds).',
    'quota_exceeded' =>
      'Your shared space is full (100 moments, 50 voice notes). Delete one of your moments to make room.',
    'not_paired' => 'Connect with your partner before publishing a moment.',
    'moment_not_found' =>
      'This moment was removed. You can publish a new moment.',
    'request_conflict' || 'invalid_request_id' =>
      'Couldn’t publish this moment. Cancel it and start again.',
    _ => null,
  };

  Future<void> delete(api.MomentEntry entry) async {
    if (!canCreate ||
        !_validEntry(entry) ||
        entry.authorId != pairing.userId ||
        deletingId != null) {
      return;
    }
    final revision = _revision;
    deletingId = entry.momentId;
    deleteErrorId = null;
    _failedDelete = null;
    _notify();
    try {
      await repository.delete(entry.momentId);
      if (!_current(revision)) return;
      _feedRevision++;
      loading = false;
      entries.removeWhere((e) => e.momentId == entry.momentId);
      if (playingId == entry.momentId || loadingVoiceId == entry.momentId) {
        await stopPlayback();
      }
    } catch (_) {
      if (_current(revision)) {
        deleteErrorId = entry.momentId;
        _failedDelete = entry;
      }
    } finally {
      if (_current(revision)) {
        deletingId = null;
        _notify();
      }
    }
  }

  Future<void> retryDelete() async {
    final entry = _failedDelete;
    if (entry != null) await delete(entry);
  }

  Future<void> _native(Future<void> Function() action) {
    final result = _audioQueue.then((_) => action());
    _audioQueue = result.catchError((Object _) {});
    return result;
  }

  Future<void> record() async {
    if (!canCreate ||
        !_foreground ||
        publishing ||
        hasPendingPublish ||
        recording ||
        audioBusy) {
      return;
    }
    final revision = _revision;
    final record = ++_recordRevision;
    _playRevision++;
    _voice = null;
    _pcm.clear();
    audioBusy = true;
    audioError = null;
    playingId = loadingVoiceId = voiceErrorId = null;
    _notify();
    bool current() =>
        _current(revision) && record == _recordRevision && _foreground;
    try {
      await _native(() async {
        if (!current()) return;
        await audio.stopPlayback();
        if (!current()) return;
        final stream = await audio.startRecording();
        if (!current()) {
          await audio.stopRecording();
          return;
        }
        recording = true;
        _recordingAt = DateTime.now();
        _recordingStream = stream.listen(
          (bytes) {
            if (!current() || !recording) return;
            final room = maxMomentPcmBytes - _pcm.length;
            final count = bytes.length.clamp(0, room);
            if (count > 0) _pcm.add(bytes.sublist(0, count));
            if (_pcm.length >= maxMomentPcmBytes) unawaited(stopRecording());
          },
          onError: (Object _) {
            if (current()) {
              _invalidateAudio();
              audioError = 'Recording failed. Please record again.';
              _notify();
            }
          },
          onDone: () {
            if (current() && recording) unawaited(stopRecording());
          },
        );
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!current()) return;
          if (recordingSeconds >= 30) {
            unawaited(stopRecording());
          } else {
            _notify();
          }
        });
      });
    } catch (_) {
      if (current()) {
        _invalidateAudio();
        audioError =
            'Microphone unavailable. Allow microphone access and try Record again.';
        _notify();
      }
    } finally {
      if (current()) {
        audioBusy = false;
        _notify();
      }
    }
  }

  Future<void> stopRecording() async {
    if (!recording || audioBusy) return;
    final revision = _revision;
    final record = _recordRevision;
    recording = false;
    audioBusy = true;
    _recordTimer?.cancel();
    _recordTimer = null;
    _notify();
    try {
      await _native(() async {
        if (!_current(revision) || record != _recordRevision) return;
        await audio.stopRecording();
        await _recordingStream?.cancel();
        _recordingStream = null;
        if (!_current(revision) || record != _recordRevision) return;
        _voice = momentWav(_pcm.takeBytes());
        validateMomentWav(_voice!);
      });
    } catch (_) {
      if (_current(revision) && record == _recordRevision) {
        _voice = null;
        audioError = 'Couldn’t keep this recording. Please record again.';
      }
    } finally {
      if (_current(revision) && record == _recordRevision) {
        audioBusy = false;
        _recordingAt = null;
        _notify();
      }
    }
  }

  Future<void> preview() async {
    final bytes = _voice;
    if (bytes != null) await _play('draft', () async => bytes);
  }

  Future<void> play(api.MomentEntry entry) async {
    if (!canCreate || !_validEntry(entry) || entry.kind != 'voice') return;
    await _play(entry.momentId, () async {
      final data = await repository.downloadVoice(entry.momentId);
      return Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    });
  }

  Future<void> _play(String id, Future<Uint8List> Function() download) async {
    if (!canCreate || !_foreground || recording || audioBusy) return;
    if (playingId == id || loadingVoiceId == id) {
      await stopPlayback();
      return;
    }
    final revision = _revision;
    final play = ++_playRevision;
    final draft = _draftRevision;
    bool current() =>
        _current(revision) &&
        play == _playRevision &&
        _foreground &&
        (id != 'draft' || draft == _draftRevision);
    playingId = null;
    loadingVoiceId = id;
    voiceErrorId = null;
    _notify();
    try {
      await _native(audio.stopPlayback);
      if (!current()) return;
      final bytes = await download();
      if (!current()) return;
      validateMomentWav(bytes);
      await _native(() async {
        if (!current()) return;
        await audio.play(bytes);
        if (!current()) {
          await audio.stopPlayback();
          return;
        }
        playingId = id;
      });
    } catch (_) {
      if (current()) voiceErrorId = id;
    } finally {
      if (current()) {
        loadingVoiceId = null;
        _notify();
      }
    }
  }

  Future<void> stopPlayback() async {
    _playRevision++;
    playingId = loadingVoiceId = null;
    _notify();
    try {
      await _native(audio.stopPlayback);
    } catch (_) {}
  }

  void _invalidateAudio() {
    _recordRevision++;
    _playRevision++;
    _recordTimer?.cancel();
    _recordTimer = null;
    final subscription = _recordingStream;
    _recordingStream = null;
    _pcm.clear();
    _recordingAt = null;
    recording = audioBusy = false;
    playingId = loadingVoiceId = voiceErrorId = null;
    audioError = null;
    unawaited(
      _native(() async {
        try {
          await audio.stopRecording();
        } catch (_) {}
        await subscription?.cancel();
        try {
          await audio.stopPlayback();
        } catch (_) {}
      }),
    );
  }

  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (foreground && _started && canCreate && !loading) {
      unawaited(refresh(automatic: true));
    }
    if (!foreground) {
      final interrupted = recording || audioBusy;
      _invalidateAudio();
      if (interrupted) {
        audioError =
            'Recording stopped when the app left the foreground. Record again when ready.';
      }
      _notify();
    }
  }

  /// IndexedStack keeps this feature mounted when another tab is selected.
  /// Never keep the microphone or speaker active on a hidden Moments tab.
  void leaveScreen() {
    if (_disposed) return;
    final interrupted = recording || audioBusy;
    _invalidateAudio();
    if (interrupted) {
      audioError =
          'Recording stopped when you left Moments. Record again when ready.';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    pairing.removeListener(_scopeChanged);
    pairing.session.removeListener(_scopeChanged);
    _clearDraft();
    entries = [];
    _invalidateAudio();
    unawaited(_completion?.cancel());
    unawaited(_native(audio.dispose).catchError((Object _) {}));
    super.dispose();
  }
}

class _PendingMoment {
  const _PendingMoment(this.requestId, this.text, this.voice, this.revision);
  final String requestId;
  final String text;
  final Uint8List? voice;
  final int revision;
}
