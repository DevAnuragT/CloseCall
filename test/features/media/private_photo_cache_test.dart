import 'dart:async';
import 'dart:typed_data';

import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/media/data/photo_preparation.dart';
import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeCouples couples;
  late PairingController pairing;
  late _PreviewMedia repository;
  late MediaController media;
  var localWrites = 0;
  var sends = 0;

  setUp(() async {
    auth = FakeAuth()..change('me');
    couples = FakeCouples();
    pairing = PairingController(session: auth, repository: couples);
    await pairing.initialize();
    repository = _PreviewMedia()..assets = [];
    localWrites = sends = 0;
    media = MediaController(
      pairing: pairing,
      repository: repository,
      prepare: (bytes) async => bytes,
      applyLocalPhoto: (_) async => localWrites++,
      sendAsset: (_, _) async {
        sends++;
        throw StateError('Preview must not send');
      },
    );
  });
  tearDown(() {
    media.dispose();
    pairing.dispose();
    auth.dispose();
  });

  test(
    'preview deduplicates, clones bytes, and never performs writes',
    () async {
      repository.hold = true;
      final first = media.loadPhoto(testAsset());
      final second = media.loadPhoto(testAsset());
      expect(identical(first, second), isTrue);
      expect(media.photoLoading('asset'), isTrue);
      expect(media.busy, isFalse);
      expect(repository.downloads, ['asset']);
      final original = Uint8List.fromList(testPng);
      repository.pending.single.complete(original);
      await Future.wait([first, second]);
      original[0] = 0;
      expect(media.photoFor('asset'), testPng);
      expect(() => media.photoFor('asset')![0] = 0, throwsUnsupportedError);
      await media.loadPhoto(testAsset());
      expect(repository.downloads, ['asset']);
      expect(media.downloadedPhoto, isNull);
      expect(media.selectedAsset, isNull);
      expect(media.error, isNull);
      expect(media.status, isNull);
      expect(repository.requestIds, isEmpty);
      expect(localWrites, 0);
      expect(sends, 0);
    },
  );

  test(
    'at most two downloads, including explicit download, are active',
    () async {
      repository.hold = true;
      final jobs = [
        media.loadPhoto(testAsset(id: 'one')),
        media.loadPhoto(testAsset(id: 'two')),
        media.loadPhoto(testAsset(id: 'three')),
        media.download(testAsset(id: 'four')),
      ];
      expect(repository.downloads, ['one', 'two']);
      expect(media.photoLoading('three'), isTrue);
      repository.pending[0].complete(testPng);
      await Future<void>.delayed(Duration.zero);
      expect(repository.downloads, ['one', 'two', 'three']);
      repository.pending[1].complete(testPng);
      await Future<void>.delayed(Duration.zero);
      expect(repository.downloads, ['one', 'two', 'three', 'four']);
      repository.pending[2].complete(testPng);
      repository.pending[3].complete(testPng);
      await Future.wait(jobs);
      expect(repository.peak, 2);
      expect(media.selectedAsset?.assetId, 'four');
      expect(media.busy, isFalse);
    },
  );

  test('LRU retains twelve photos and no more than 24 MiB', () async {
    repository.photo = Uint8List(maxPhotoBytes)
      ..setRange(0, testPng.length, testPng);
    for (var i = 0; i < 12; i++) {
      await media.loadPhoto(testAsset(id: '$i'));
    }
    expect(media.photoFor('0'), isNotNull); // promote oldest to newest
    await media.loadPhoto(testAsset(id: '12'));
    expect(media.photoFor('1'), isNull);
    expect(media.photoFor('0'), isNotNull);
    final retained = [for (var i = 0; i <= 12; i++) ?media.photoFor('$i')];
    expect(retained, hasLength(12));
    expect(
      retained.fold<int>(0, (sum, photo) => sum + photo.length),
      lessThanOrEqualTo(24 * 1024 * 1024),
    );
    await media.loadPhoto(testAsset(id: '1'));
    expect(repository.downloads.where((id) => id == '1'), hasLength(2));
  });

  test('rejects foreign couple, nonmember and malformed private PNG', () async {
    await media.loadPhoto(testAsset(couple: 'foreign'));
    await media.loadPhoto(testAsset(id: 'outsider', uploader: 'stranger'));
    expect(repository.downloads, isEmpty);
    expect(media.photoLoadErrorFor('asset'), isA<StateError>());
    expect(media.photoLoadErrorFor('outsider'), isA<StateError>());
    repository.photo = Uint8List(100);
    await media.loadPhoto(testAsset(id: 'bad'));
    expect(media.photoFor('bad'), isNull);
    expect(media.photoLoadErrorFor('bad'), isA<FormatException>());
    repository.photo = Uint8List(maxPhotoBytes + 1)
      ..setRange(0, testPng.length, testPng);
    await media.loadPhoto(testAsset(id: 'large'));
    expect(media.photoFor('large'), isNull);
    expect(media.photoLoadErrorFor('large'), isA<FormatException>());
  });

  test(
    'failed read is independently retryable during pending upload',
    () async {
      repository.uploadFailure = TimeoutException('private upload pending');
      await media.uploadConfirmed(testPng);
      final operationError = media.error;
      final request = media.pendingRequestId;
      repository.downloadFailure = TimeoutException('private preview failed');
      await media.loadPhoto(testAsset());
      expect(media.photoLoadErrorFor('asset'), isA<TimeoutException>());
      expect(media.photoLoading('asset'), isFalse);
      expect(identical(media.error, operationError), isTrue);
      expect(media.pendingRequestId, request);
      repository.downloadFailure = null;
      await media.loadPhoto(testAsset());
      expect(media.photoLoadErrorFor('asset'), isNull);
      expect(media.photoFor('asset'), testPng);
      expect(media.hasPendingUpload, isTrue);
      repository.uploadFailure = null;
      await media.retry();
      expect(repository.requestIds, [request, request]);
      expect(localWrites, 0);
      expect(sends, 0);
    },
  );

  test(
    'preview does not cancel an in-flight command or command revision',
    () async {
      repository.pendingList = Completer();
      final command = media.refresh();
      expect(media.busy, isTrue);
      await media.loadPhoto(testAsset(id: 'mine', uploader: 'me'));
      expect(media.busy, isTrue);
      repository.pendingList!.complete([testAsset(id: 'mine', uploader: 'me')]);
      await command;
      expect(media.busy, isFalse);
      expect(media.assets.single.assetId, 'mine');
      expect(media.photoFor('mine'), testPng);
    },
  );

  test(
    'upload and explicit download seed previews without another read',
    () async {
      await media.uploadConfirmed(testPng);
      await media.loadPhoto(testAsset(id: 'uploaded', uploader: 'me'));
      expect(repository.downloads, isEmpty);
      await media.download(testAsset());
      await media.loadPhoto(testAsset());
      expect(repository.downloads, ['asset']);
    },
  );

  test(
    'auth A to B to A drops queued and late old-scope bytes/errors',
    () async {
      repository.hold = true;
      final old = [
        media.loadPhoto(testAsset(id: 'one')),
        media.loadPhoto(testAsset(id: 'two')),
        media.loadPhoto(testAsset(id: 'queued')),
      ];
      final revision = pairing.authRevision;
      auth.change('partner');
      await Future<void>.delayed(Duration.zero);
      auth.change('me');
      await Future<void>.delayed(Duration.zero);
      expect(pairing.authRevision, greaterThan(revision));
      await Future.wait(
        old,
      ); // abandoned requests finish without old transports
      final fresh = media.loadPhoto(testAsset(id: 'one'));
      expect(repository.downloads, ['one', 'two']);
      repository.pending[0].complete(testPng);
      repository.pending[1].completeError(StateError('old private failure'));
      await Future<void>.delayed(Duration.zero);
      expect(repository.downloads, ['one', 'two', 'one']);
      expect(media.photoFor('one'), isNull);
      expect(media.photoLoadErrorFor('two'), isNull);
      expect(media.photoLoading('one'), isTrue);
      repository.pending[2].complete(testPng);
      await fresh;
      expect(media.photoFor('one'), testPng);
      expect(repository.peak, 2);
      expect(repository.downloads, isNot(contains('queued')));
    },
  );

  test('preview preserves the pending send and its explicit retry', () async {
    await media.sendUploaded(testAsset(id: 'mine', uploader: 'me'));
    final operationError = media.error;
    expect(media.hasPendingSend, isTrue);
    await media.loadPhoto(testAsset());
    expect(media.hasPendingSend, isTrue);
    expect(identical(media.error, operationError), isTrue);
    expect(sends, 1);
    expect(repository.requestIds, isEmpty);
    await media.retry();
    expect(sends, 2);
    expect(repository.requestIds, isEmpty);
    expect(media.hasPendingSend, isTrue);
    expect(media.photoFor('asset'), testPng);
  });

  test('membership change clears photos even with same couple id', () async {
    await media.loadPhoto(testAsset());
    couples.couple = Couple(id: 'couple', memberIds: ['me', 'new-partner']);
    await pairing.refresh();
    expect(media.photoFor('asset'), isNull);
    await media.loadPhoto(testAsset());
    expect(repository.downloads, ['asset']);
  });

  test('dispose completes queued requests and drops late bytes', () async {
    repository.hold = true;
    final jobs = [
      media.loadPhoto(testAsset(id: 'one')),
      media.loadPhoto(testAsset(id: 'two')),
      media.loadPhoto(testAsset(id: 'queued')),
    ];
    final disposed = media;
    disposed.dispose();
    await Future.wait(jobs);
    repository.pending[0].complete(testPng);
    repository.pending[1].complete(testPng);
    await Future<void>.delayed(Duration.zero);
    expect(disposed.photoFor('one'), isNull);
    expect(repository.downloads, ['one', 'two']);
    media = MediaController(pairing: pairing, repository: repository);
  });
}

class _PreviewMedia extends FakeMedia {
  bool hold = false;
  Uint8List photo = testPng;
  int active = 0;
  int peak = 0;
  final pending = <Completer<Uint8List>>[];

  @override
  Future<Uint8List> downloadPhoto(String assetId) async {
    downloads.add(assetId);
    active++;
    if (active > peak) peak = active;
    try {
      if (downloadFailure != null) throw downloadFailure!;
      if (!hold) return photo;
      final response = Completer<Uint8List>();
      pending.add(response);
      return await response.future;
    } finally {
      active--;
    }
  }
}
