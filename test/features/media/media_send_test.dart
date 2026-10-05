import 'dart:async';
import 'dart:typed_data';

import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall_client/closecall_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/live_fakes.dart';

WidgetSendReceipt receipt(
  String asset,
  String request, {
  bool enabled = true,
}) => WidgetSendReceipt(
  sendId: 'send',
  requestId: request,
  coupleId: 'couple',
  senderId: 'me',
  recipientId: 'partner',
  assetId: asset,
  version: 1,
  createdAt: DateTime.utc(2026, 10, 5),
  recipientAutoUpdateEnabled: enabled,
);

void main() {
  late FakeAuth auth;
  late PairingController pairing;
  late FakeMedia repository;
  late MediaController media;
  late Future<WidgetSendReceipt> Function(String, String) response;
  final sends = <(String, String)>[];
  var preparations = 0;
  var ids = 0;

  setUp(() async {
    auth = FakeAuth()..change('me');
    pairing = PairingController(session: auth, repository: FakeCouples());
    await pairing.initialize();
    repository = FakeMedia();
    sends.clear();
    preparations = ids = 0;
    response = (asset, request) async => receipt(asset, request);
    media = MediaController(
      pairing: pairing,
      repository: repository,
      prepare: (photo) async {
        preparations++;
        return photo;
      },
      requestId: () => 'request-${++ids}',
      sendAsset: (asset, request) async {
        sends.add((asset, request));
        return response(asset, request);
      },
    );
  });
  tearDown(() {
    media.dispose();
    pairing.dispose();
    auth.dispose();
  });

  test(
    'send acknowledges upload first; saving privately never sends',
    () async {
      await media.uploadConfirmed(testPng);
      expect(repository.requestIds, ['request-1']);
      expect(sends, isEmpty);
      await media.sendConfirmed(testPng);
      expect(repository.requestIds, ['request-1', 'request-2']);
      expect(sends, [('uploaded', 'request-3')]);
      expect(media.hasPendingUpload, isFalse);
      expect(media.hasPendingSend, isFalse);
      expect(media.status, startsWith('Sent.'));
      expect(media.status, contains('Active schedules take priority'));
      expect(media.status, isNot(contains('rendered')));
    },
  );

  test(
    'lost send reply retries only same acknowledged asset and UUID',
    () async {
      response = (_, _) async => throw TimeoutException('lost reply');
      final original = Uint8List.fromList(testPng);
      await media.sendConfirmed(original);
      original[0] = 0;
      expect(repository.requestIds, hasLength(1));
      expect(media.assets.single.assetId, 'uploaded');
      expect(media.hasPendingUpload, isFalse);
      expect(media.hasPendingSend, isTrue);
      // New actions cannot replace the uncertain send or its retry callback.
      await media.uploadConfirmed(testPng);
      await media.sendConfirmed(testPng);
      await media.sendUploaded(testAsset(id: 'other', uploader: 'me'));
      await media.refresh();
      await media.download(testAsset());
      expect(repository.downloads, isEmpty);
      expect(sends, hasLength(1));
      response = (asset, request) async => receipt(asset, request);
      await media.retry();
      expect(sends, [('uploaded', 'request-2'), ('uploaded', 'request-2')]);
      expect(repository.requestIds, ['request-1']);
      expect(preparations, 1);
      expect(media.hasPendingSend, isFalse);
    },
  );

  test('uncertain upload retries immutable upload before sending', () async {
    repository.uploadFailure = TimeoutException('lost upload reply');
    await media.sendConfirmed(testPng);
    expect(media.hasPendingUpload, isTrue);
    expect(media.hasPendingSend, isTrue);
    expect(sends, isEmpty);
    repository.uploadFailure = null;
    await media.retry();
    expect(repository.requestIds, ['request-1', 'request-1']);
    expect(repository.payloads.first, repository.payloads.last);
    expect(preparations, 1);
    expect(sends, [('uploaded', 'request-2')]);
  });

  test('already uploaded own photo sends without uploading', () async {
    response = (asset, request) async =>
        receipt(asset, request, enabled: false);
    await media.sendUploaded(testAsset(id: 'existing', uploader: 'me'));
    expect(repository.requestIds, isEmpty);
    expect(sends, [('existing', 'request-1')]);
    expect(media.status, contains('queued until your partner allows updates'));
    expect(media.status, isNot(contains('rendered')));
  });

  test('received and other-couple assets cannot be sent', () async {
    await media.sendUploaded(testAsset());
    expect(media.error, isNotNull);
    expect(media.hasPendingSend, isFalse);
    await media.sendUploaded(testAsset(uploader: 'me', couple: 'other'));
    expect(media.error, isNotNull);
    expect(repository.requestIds, isEmpty);
    expect(sends, isEmpty);
  });

  for (final field in [
    'asset',
    'request',
    'couple',
    'sender',
    'recipient',
    'send',
    'version',
  ]) {
    test('mismatched $field receipt is not acknowledged', () async {
      response = (asset, request) async {
        final valid = receipt(asset, request);
        return switch (field) {
          'asset' => valid.copyWith(assetId: 'wrong'),
          'request' => valid.copyWith(requestId: 'wrong'),
          'couple' => valid.copyWith(coupleId: 'wrong'),
          'sender' => valid.copyWith(senderId: 'wrong'),
          'recipient' => valid.copyWith(recipientId: 'wrong'),
          'send' => valid.copyWith(sendId: ''),
          _ => valid.copyWith(version: 0),
        };
      };
      await media.sendConfirmed(testPng);
      expect(media.error, isNotNull);
      expect(media.hasPendingSend, isTrue);
      expect(media.status, isNull);
      response = (asset, request) async => receipt(asset, request);
      await media.retry();
      expect(repository.requestIds, hasLength(1));
      expect(sends[0], sends[1]);
      expect(media.hasPendingSend, isFalse);
    });
  }

  for (final change in ['cancel', 'sign-out', 'account-switch']) {
    test(
      '$change discards late send and never automatically resends',
      () async {
        final pending = Completer<WidgetSendReceipt>();
        response = (_, _) => pending.future;
        final sending = media.sendConfirmed(testPng);
        await Future<void>.delayed(Duration.zero);
        expect(sends, hasLength(1));
        switch (change) {
          case 'cancel':
            media.cancel();
          case 'sign-out':
            auth.change(null);
          case 'account-switch':
            auth.change('another-user');
        }
        pending.complete(receipt(sends.single.$1, sends.single.$2));
        await sending;
        await media.retry();
        expect(sends, hasLength(1));
        expect(media.hasPendingSend, isFalse);
        expect(media.hasPendingUpload, isFalse);
        expect(media.error, isNull);
        expect(media.status ?? '', isNot(startsWith('Sent')));
      },
    );
  }

  test('cancel during upload cannot progress to send', () async {
    media.dispose();
    final delayed = _DelayedUpload();
    media = MediaController(
      pairing: pairing,
      repository: delayed,
      prepare: (photo) async => photo,
      sendAsset: (asset, request) async {
        sends.add((asset, request));
        return receipt(asset, request);
      },
    );
    final sending = media.sendConfirmed(testPng);
    await Future<void>.delayed(Duration.zero);
    media.cancel();
    delayed.pending.complete(testAsset(id: 'uploaded', uploader: 'me'));
    await sending;
    await media.retry();
    expect(sends, isEmpty);
    expect(media.hasPendingSend, isFalse);
  });

  test(
    'cancel at the upload acknowledgement prevents the send stage',
    () async {
      var cancelled = false;
      media.addListener(() {
        if (!cancelled &&
            media.busy &&
            !media.hasPendingUpload &&
            media.hasPendingSend) {
          cancelled = true;
          media.cancel();
        }
      });
      await media.sendConfirmed(testPng);
      expect(cancelled, isTrue);
      expect(repository.requestIds, hasLength(1));
      expect(sends, isEmpty);
      expect(media.hasPendingSend, isFalse);
    },
  );

  test('signed-out send never makes private calls', () async {
    auth.change(null);
    await media.sendConfirmed(testPng);
    await media.sendUploaded(testAsset(uploader: 'me'));
    expect(sends, isEmpty);
    expect(repository.requestIds, isEmpty);
  });
}

class _DelayedUpload extends FakeMedia {
  final pending = Completer<MediaAsset>();
  @override
  Future<MediaAsset> uploadPhoto(Uint8List photo, String id) => pending.future;
}
