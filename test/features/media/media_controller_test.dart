import 'dart:async';
import 'dart:typed_data';
import 'package:closecall_client/closecall_client.dart';
import 'package:closecall/features/media/data/media_repository.dart';
import 'package:closecall/features/media/data/photo_preparation.dart';
import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/live_fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeCouples couples;
  late FakeMedia repository;
  late PairingController pairing;
  late MediaController media;
  var preparationCalls = 0;
  final localPhotos = <Uint8List>[];
  setUp(() async {
    auth = FakeAuth()..change('me');
    couples = FakeCouples();
    pairing = PairingController(session: auth, repository: couples);
    await pairing.initialize();
    repository = FakeMedia();
    localPhotos.clear();
    preparationCalls = 0;
    media = MediaController(
      pairing: pairing,
      repository: repository,
      prepare: (bytes) async {
        preparationCalls++;
        return bytes;
      },
      requestId: () => '123e4567-e89b-42d3-a456-426614174000',
      applyLocalPhoto: (bytes) async {
        localPhotos.add(bytes);
      },
    );
  });
  tearDown(() {
    media.dispose();
    pairing.dispose();
    auth.dispose();
  });

  test(
    'retry keeps identical UUID and immutable prepared bytes; upload is not local apply',
    () async {
      repository.uploadFailure = StateError(
        'timeout after server accepted request',
      );
      final original = Uint8List.fromList(testPng);
      await media.uploadConfirmed(original);
      original[0] = 0;
      expect(media.hasPendingUpload, isTrue);
      expect(media.error, isNotNull);
      repository.uploadFailure = null;
      await media.retry();
      expect(repository.requestIds, hasLength(2));
      expect(repository.requestIds.toSet(), hasLength(1));
      expect(repository.payloads.first, repository.payloads.last);
      expect(preparationCalls, 1);
      expect(media.hasPendingUpload, isFalse);
      expect(media.assets.single.assetId, 'uploaded');
      expect(localPhotos, isEmpty);
    },
  );

  test(
    'list downloads newest partner photo and only explicit apply updates local widget',
    () async {
      repository.assets = [testAsset(id: 'mine', uploader: 'me'), testAsset()];
      await media.refresh();
      expect(repository.downloads, ['asset']);
      expect(media.downloadedPhoto, testPng);
      expect(localPhotos, isEmpty);
      await media.applyDownloadedLocally();
      expect(localPhotos.single, testPng);
      expect(media.status, contains('this device'));
    },
  );

  test(
    'auth reset clears media and late downloads cannot restore prior couple',
    () async {
      repository.pendingDownload = Completer<Uint8List>();
      final refresh = media.refresh();
      await Future<void>.delayed(Duration.zero);
      auth.change(null);
      repository.pendingDownload!.complete(testPng);
      await refresh;
      expect(media.assets, isEmpty);
      expect(media.downloadedPhoto, isNull);
      expect(media.pendingRequestId, isNull);
      expect(media.error, isNull);
    },
  );

  test(
    'late list failure after a current-user reset stays discarded',
    () async {
      repository.pendingList = Completer<List<MediaAsset>>();
      final refresh = media.refresh();
      auth.change(null);
      repository.pendingList!.completeError(StateError('old offline error'));
      await refresh;
      expect(media.error, isNull);
      expect(media.busy, isFalse);
    },
  );

  test('cancel drops pending request and ignores late list result', () async {
    repository.pendingList = Completer<List<MediaAsset>>();
    final refresh = media.refresh();
    media.cancel();
    repository.pendingList!.complete([testAsset()]);
    await refresh;
    expect(media.assets, isEmpty);
    expect(media.busy, isFalse);
  });

  test(
    'local validation prevents malformed, oversized or huge dimension upload',
    () async {
      await media.uploadConfirmed(Uint8List(12));
      expect(media.error, isA<FormatException>());
      expect(repository.requestIds, isEmpty);
      expect(
        () => validateUploadPng(Uint8List(maxPhotoBytes + 1)),
        throwsFormatException,
      );
      final huge = Uint8List.fromList(testPng);
      ByteData.sublistView(huge).setUint32(16, 2049);
      expect(() => validateUploadPng(huge), throwsFormatException);
    },
  );

  test('ByteData conversion respects slice offsets', () {
    final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);
    expect(byteDataBytes(ByteData.sublistView(bytes, 1, 4)), [1, 2, 3]);
  });

  test(
    'sign-out cleanup follows an in-flight native apply, never before it',
    () async {
      media.dispose();
      final pendingApply = Completer<void>();
      final operations = <String>[];
      media = MediaController(
        pairing: pairing,
        repository: repository,
        prepare: (bytes) async => bytes,
        applyLocalPhoto: (_) async {
          operations.add('apply-started');
          await pendingApply.future;
          operations.add('apply-completed');
        },
        clearLocalPhoto: () async {
          operations.add('cleared');
        },
      );
      await media.refresh();
      final applying = media.applyDownloadedLocally();
      await Future<void>.delayed(Duration.zero);
      auth.change(null);
      pendingApply.complete();
      await applying;
      await Future<void>.delayed(Duration.zero);
      expect(operations, ['apply-started', 'apply-completed', 'cleared']);
      expect(media.downloadedPhoto, isNull);
    },
  );

  test('disposing during download discards completion safely', () async {
    repository.pendingDownload = Completer<Uint8List>();
    final refresh = media.refresh();
    await Future<void>.delayed(Duration.zero);
    media.dispose();
    repository.pendingDownload!.complete(testPng);
    await refresh;
    expect(media.downloadedPhoto, isNull);
    // Replace the disposed test fixture so tearDown only disposes live state.
    media = MediaController(pairing: pairing, repository: repository);
  });

  for (final code in [
    'invalid_image',
    'file_too_large',
    'invalid_request_id',
    'request_conflict',
    'asset_not_found',
    'not_paired',
    'quota_exceeded',
  ]) {
    test('typed media failure $code is explicit and retryable', () async {
      repository.uploadFailure = MediaFailure(code: code);
      await media.uploadConfirmed(testPng);
      expect(media.error, isA<MediaFailure>());
      expect(mediaErrorMessage(media.error!), isNot(contains('Instance of')));
      expect(media.hasPendingUpload, isTrue);
    });
  }
}
