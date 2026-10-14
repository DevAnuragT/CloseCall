import 'dart:async';
import 'dart:typed_data';

import 'package:closecall_client/closecall_client.dart' as api;
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/moments/data/moment_audio.dart';
import 'package:closecall/features/moments/presentation/moments_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';
import 'moments_fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeCouples couples;
  late PairingController pairing;
  late FakeMoments repository;
  late FakeMomentAudio audio;
  late MomentsController moments;
  setUp(() async {
    auth = FakeAuth()..change('me');
    couples = FakeCouples();
    pairing = PairingController(session: auth, repository: couples);
    await pairing.initialize();
    repository = FakeMoments();
    audio = FakeMomentAudio();
    moments = MomentsController(
      pairing: pairing,
      repository: repository,
      audio: audio,
      requestId: () => '123e4567-e89b-42d3-a456-426614174000',
    );
  });
  tearDown(() async {
    moments.dispose();
    pairing.dispose();
    auth.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'feed is latest-first, paged by last id and bounded; never auto-downloads voice',
    () async {
      repository.entries = List.generate(
        105,
        (i) => testMoment(
          id: 'm$i',
          kind: 'voice',
          createdAt: DateTime.utc(2026, 10, 11).subtract(Duration(minutes: i)),
        ),
      );
      await moments.refresh();
      expect(moments.entries, hasLength(20));
      expect(moments.entries.first.momentId, 'm0');
      expect(moments.hasMore, isTrue);
      for (var i = 0; i < 8; i++) {
        await moments.loadMore();
      }
      expect(moments.entries, hasLength(100));
      expect(moments.hasMore, isFalse);
      expect(repository.cursors, [null, 'm19', 'm39', 'm59', 'm79']);
      expect(repository.limits.toSet(), {20});
      expect(repository.downloads, isEmpty);
      expect(audio.records, 0);
      expect(audio.played, isEmpty);
    },
  );

  test('a valid push hint refreshes the current private feed', () async {
    const id = '123e4567-e89b-42d3-a456-426614174001';
    repository.entries = [testMoment(id: id)];

    await moments.openFromNotification(id);

    expect(repository.cursors, [null]);
    expect(moments.entries.single.momentId, id);
    expect(moments.highlightedMomentId, id);
    await moments.openFromNotification('not-a-uuid');
    expect(repository.cursors, [null]);
  });

  test(
    'feed failure retains snapshot; only explicit retry repeats the failed cursor',
    () async {
      repository.entries = List.generate(
        30,
        (i) => testMoment(
          id: 'm$i',
          createdAt: DateTime.utc(2026).subtract(Duration(minutes: i)),
        ),
      );
      await moments.refresh();
      repository.listFailure = StateError('private backend detail');
      await moments.loadMore();
      expect(moments.entries, hasLength(20));
      expect(moments.feedError, isNot(contains('private backend detail')));
      repository.listFailure = null;
      expect(repository.cursors, [null, 'm19']);
      await moments.retryFeed();
      expect(repository.cursors, [null, 'm19', 'm19']);
      expect(moments.entries, hasLength(30));
    },
  );

  test(
    'text validation and paired-only creation stop invalid requests',
    () async {
      moments.openComposer();
      moments.setText('  ');
      expect(await moments.publish(), isFalse);
      moments.setText('a' * 1001);
      expect(await moments.publish(), isFalse);
      expect(repository.requestIds, isEmpty);
      couples.couple = Couple(id: 'couple', memberIds: ['me']);
      await pairing.refresh();
      moments.openComposer();
      moments.setText('A note');
      expect(moments.canCreate, isFalse);
      expect(await moments.publish(), isFalse);
      await moments.record();
      expect(audio.records, 0);
    },
  );

  test(
    'confirmed quota rejection preserves editable draft with a useful message',
    () async {
      repository.createFailure = api.MomentFailure(code: 'quota_exceeded');
      moments.openComposer();
      moments.setText('Keep me');
      expect(await moments.publish(), isFalse);
      expect(moments.composerError, contains('shared space is full'));
      expect(moments.hasPendingPublish, isFalse);
      moments.setText('Edited note');
      expect(moments.draftText, 'Edited note');
    },
  );

  test(
    'ambiguous text publish freezes exact text and UUID for explicit retry',
    () async {
      repository.createFailure = StateError('response lost');
      moments.openComposer();
      moments.setText('  Exact text ❤️\n');
      expect(await moments.publish(), isFalse);
      moments.setText('changed');
      expect(await moments.publish(), isFalse);
      expect(repository.requestIds, hasLength(1));
      repository.createFailure = null;
      expect(await moments.retryPublish(), isTrue);
      expect(repository.requestIds.toSet(), hasLength(1));
      expect(repository.texts, ['  Exact text ❤️\n', '  Exact text ❤️\n']);
      expect(moments.entries.single.text, '  Exact text ❤️\n');
      expect(moments.hasPendingPublish, isFalse);
      expect(moments.composerOpen, isFalse);
    },
  );

  test(
    'voice stop, preview and ambiguous retry preserve identical WAV bytes',
    () async {
      moments.openComposer();
      await moments.record();
      expect(moments.recording, isTrue);
      final pcm = Uint8List(32000)..[20] = 7;
      audio.pcm.add(pcm);
      pcm[20] = 9;
      await moments.stopRecording();
      expect(moments.voiceDurationMs, 1000);
      expect(audio.played, isEmpty);
      await moments.preview();
      expect(audio.played.single[64], 7);
      repository.createFailure = StateError('ambiguous');
      expect(await moments.publish(), isFalse);
      await moments.record();
      expect(audio.records, 1);
      repository.createFailure = null;
      expect(await moments.retryPublish(), isTrue);
      expect(repository.voices.first, repository.voices.last);
      expect(repository.requestIds.toSet(), hasLength(1));
      expect(moments.hasVoice, isFalse);
    },
  );

  for (final change in [
    'sign-out',
    'identity-roundtrip',
    'couple',
    'partner',
  ]) {
    test('$change rejects pending write retry and late feed result', () async {
      repository.createFailure = StateError('ambiguous');
      moments.openComposer();
      moments.setText('Old scope');
      await moments.publish();
      final list = Completer<List<api.MomentEntry>>();
      repository.pendingList = list;
      final refresh = moments.refresh();
      switch (change) {
        case 'sign-out':
          auth.change(null);
        case 'identity-roundtrip':
          auth.change('other');
          auth.change('me');
          await Future<void>.delayed(Duration.zero);
        case 'couple':
          couples.couple = Couple(
            id: 'new-couple',
            memberIds: ['me', 'partner'],
          );
          await pairing.refresh();
        case 'partner':
          couples.couple = Couple(
            id: 'couple',
            memberIds: ['me', 'new-partner'],
          );
          await pairing.refresh();
      }
      list.complete([testMoment()]);
      await refresh;
      await moments.retryPublish();
      expect(repository.requestIds, hasLength(1));
      expect(moments.hasPendingPublish, isFalse);
      expect(moments.entries, isEmpty);
      expect(moments.feedError, isNull);
      expect(moments.draftText, isEmpty);
    });
  }

  test('late successful publish after sign-out cannot restore feed', () async {
    repository.pendingCreate = Completer<api.MomentEntry>();
    moments.openComposer();
    moments.setText('Old scope');
    final publish = moments.publish();
    auth.change(null);
    repository.pendingCreate!.complete(testMoment());
    expect(await publish, isFalse);
    expect(moments.entries, isEmpty);
    expect(moments.publishing, isFalse);
    expect(moments.composerError, isNull);
  });

  test(
    'voice download is explicit, offset-safe, retryable and clears on completion',
    () async {
      final entry = testMoment(kind: 'voice');
      repository.entries = [entry];
      await moments.refresh();
      expect(repository.downloads, isEmpty);
      repository.downloadFailure = StateError('offline');
      await moments.play(entry);
      expect(moments.voiceErrorId, entry.momentId);
      expect(audio.played, isEmpty);
      repository.downloadFailure = null;
      await moments.play(entry);
      expect(audio.played, hasLength(1));
      expect(validateMomentWav(audio.played.single), 1000);
      expect(moments.playingId, entry.momentId);
      final stops = audio.playbackStops;
      audio.completions.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(moments.playingId, isNull);
      expect(audio.playbackStops, greaterThan(stops));
    },
  );

  for (final change in ['background', 'cancel-download', 'sign-out']) {
    test('$change prevents a late download from reaching the player', () async {
      repository.pendingDownload = Completer<ByteData>();
      final play = moments.play(testMoment(kind: 'voice'));
      await Future<void>.delayed(Duration.zero);
      switch (change) {
        case 'background':
          moments.setForeground(false);
        case 'cancel-download':
          await moments.stopPlayback();
        case 'sign-out':
          auth.change(null);
      }
      repository.pendingDownload!.complete(
        ByteData.sublistView(momentWav(Uint8List(32000))),
      );
      await play;
      expect(audio.played, isEmpty);
      expect(moments.loadingVoiceId, isNull);
      expect(moments.playingId, isNull);
    });
  }

  test(
    'cancel cleans recording and late permission/start; new scope cannot inherit it',
    () async {
      audio.pendingStart = Completer<Stream<Uint8List>>();
      moments.openComposer();
      final recording = moments.record();
      await Future<void>.delayed(Duration.zero);
      moments.cancelDraft();
      audio.pendingStart!.complete(audio.pcm.stream);
      await recording;
      await Future<void>.delayed(Duration.zero);
      expect(moments.recording, isFalse);
      expect(moments.hasVoice, isFalse);
      expect(audio.recordStops, greaterThan(0));
      expect(moments.audioBusy, isFalse);
    },
  );

  test(
    'recording caps PCM at 30 seconds and discards unfinished audio on background',
    () async {
      await moments.record();
      audio.pcm.add(Uint8List(maxMomentPcmBytes + 100));
      await Future<void>.delayed(Duration.zero);
      expect(moments.recording, isFalse);
      expect(moments.voiceDurationMs, 30000);
      moments.cancelDraft();
      await moments.record();
      audio.pcm.add(Uint8List(32000));
      moments.setForeground(false);
      await Future<void>.delayed(Duration.zero);
      expect(moments.hasVoice, isFalse);
      expect(moments.recording, isFalse);
      expect(moments.audioError, contains('foreground'));
    },
  );

  test('delete is author-only and explicitly retryable', () async {
    final mine = testMoment();
    await moments.delete(testMoment(author: 'partner'));
    expect(repository.deletions, isEmpty);
    repository.entries = [mine];
    await moments.refresh();
    repository.deleteFailure = StateError('offline');
    await moments.delete(mine);
    expect(moments.entries, hasLength(1));
    expect(moments.deleteErrorId, mine.momentId);
    repository.deleteFailure = null;
    await moments.retryDelete();
    expect(repository.deletions, ['moment', 'moment']);
    expect(moments.entries, isEmpty);
  });

  test(
    'leaving Moments stops hidden recording and preserves the note draft',
    () async {
      moments.openComposer();
      moments.setText('Keep the written note');
      await moments.record();
      audio.pcm.add(Uint8List(32000));
      moments.leaveScreen();
      await Future<void>.delayed(Duration.zero);
      expect(moments.recording, isFalse);
      expect(moments.hasVoice, isFalse);
      expect(moments.draftText, 'Keep the written note');
      expect(audio.recordStops, greaterThan(0));
      expect(moments.audioError, contains('left Moments'));
    },
  );

  test('leaving Moments prevents a late voice download from playing', () async {
    repository.pendingDownload = Completer<ByteData>();
    final play = moments.play(testMoment(kind: 'voice'));
    await Future<void>.delayed(Duration.zero);
    moments.leaveScreen();
    repository.pendingDownload!.complete(
      ByteData.sublistView(momentWav(Uint8List(32000))),
    );
    await play;
    expect(audio.played, isEmpty);
    expect(moments.playingId, isNull);
  });

  test(
    'WAV validator rejects invalid formats, oversized and overlong clips',
    () {
      final valid = momentWav(Uint8List(32000));
      expect(validateMomentWav(valid), 1000);
      ByteData.sublistView(valid).setUint32(24, 44100, Endian.little);
      expect(() => validateMomentWav(valid), throwsFormatException);
      expect(
        () => validateMomentWav(Uint8List(maxMomentVoiceBytes + 1)),
        throwsFormatException,
      );
      expect(
        () => momentWav(Uint8List(maxMomentPcmBytes + 2)),
        throwsFormatException,
      );
      expect(() => momentWav(Uint8List(1)), throwsFormatException);
    },
  );
}
