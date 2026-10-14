import 'dart:async';
import 'dart:typed_data';

import 'package:closecall_client/closecall_client.dart' as api;
import 'package:closecall/features/moments/data/moment_audio.dart';
import 'package:closecall/features/moments/data/moments_repository.dart';

api.MomentEntry testMoment({
  String id = 'moment',
  String author = 'me',
  String couple = 'couple',
  String kind = 'text',
  String text = 'A small hello',
  DateTime? createdAt,
}) => api.MomentEntry(
  momentId: id,
  coupleId: couple,
  authorId: author,
  text: text,
  kind: kind,
  durationMs: kind == 'voice' ? 1000 : null,
  createdAt: createdAt ?? DateTime.utc(2026, 10, 11),
);

class FakeMoments implements MomentsRepository {
  List<api.MomentEntry> entries = [];
  Object? listFailure;
  int listFailures = 0;
  Object? createFailure;
  Object? downloadFailure;
  Object? deleteFailure;
  Completer<List<api.MomentEntry>>? pendingList;
  Completer<api.MomentEntry>? pendingCreate;
  Completer<ByteData>? pendingDownload;
  final cursors = <String?>[];
  final limits = <int>[];
  final requestIds = <String>[];
  final texts = <String>[];
  final voices = <Uint8List?>[];
  final downloads = <String>[];
  final deletions = <String>[];

  int get listCalls => cursors.length;

  @override
  Future<List<api.MomentEntry>> list({String? beforeId, int limit = 20}) async {
    cursors.add(beforeId);
    limits.add(limit);
    if (listFailure != null) throw listFailure!;
    if (listFailures > 0) {
      listFailures--;
      throw StateError('transient list failure');
    }
    if (pendingList != null) return pendingList!.future;
    final start = beforeId == null
        ? 0
        : entries.indexWhere((e) => e.momentId == beforeId) + 1;
    return entries.skip(start).take(limit).toList();
  }

  @override
  Future<api.MomentEntry> create({
    required String requestId,
    required String text,
    ByteData? voiceBytes,
  }) async {
    requestIds.add(requestId);
    texts.add(text);
    voices.add(
      voiceBytes == null
          ? null
          : Uint8List.fromList(
              voiceBytes.buffer.asUint8List(
                voiceBytes.offsetInBytes,
                voiceBytes.lengthInBytes,
              ),
            ),
    );
    if (createFailure != null) throw createFailure!;
    if (pendingCreate != null) return pendingCreate!.future;
    return testMoment(
      id: 'published',
      text: text,
      kind: voiceBytes == null ? 'text' : 'voice',
    );
  }

  @override
  Future<ByteData> downloadVoice(String momentId) async {
    downloads.add(momentId);
    if (downloadFailure != null) throw downloadFailure!;
    if (pendingDownload != null) return pendingDownload!.future;
    final wav = momentWav(Uint8List(32000));
    final container = Uint8List(wav.length + 4)
      ..setRange(2, wav.length + 2, wav);
    return ByteData.sublistView(container, 2, wav.length + 2);
  }

  @override
  Future<void> delete(String momentId) async {
    deletions.add(momentId);
    if (deleteFailure != null) throw deleteFailure!;
  }
}

class FakeMomentAudio implements MomentAudio {
  final completions = StreamController<void>.broadcast(sync: true);
  final pcm = StreamController<Uint8List>.broadcast(sync: true);
  int records = 0;
  int recordStops = 0;
  int playbackStops = 0;
  int disposals = 0;
  final played = <Uint8List>[];
  Object? recordFailure;
  Object? playFailure;
  Completer<Stream<Uint8List>>? pendingStart;
  @override
  Stream<void> get completed => completions.stream;
  @override
  Future<Stream<Uint8List>> startRecording() async {
    records++;
    if (recordFailure != null) throw recordFailure!;
    return pendingStart == null ? pcm.stream : pendingStart!.future;
  }

  @override
  Future<void> stopRecording() async {
    recordStops++;
  }

  @override
  Future<void> play(Uint8List wav) async {
    if (playFailure != null) throw playFailure!;
    played.add(Uint8List.fromList(wav));
  }

  @override
  Future<void> stopPlayback() async {
    playbackStops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await pcm.close();
    await completions.close();
  }
}
