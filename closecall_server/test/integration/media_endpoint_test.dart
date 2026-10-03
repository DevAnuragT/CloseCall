import 'dart:typed_data';

import 'package:closecall_server/src/generated/protocol.dart';
import 'package:image/image.dart' as image;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

Matcher mediaFailure(String code) =>
    isA<MediaFailure>().having((e) => e.code, 'code', code);
ByteData photo([int color = 10]) {
  final pixels = image.Image(width: 3, height: 2);
  pixels.setPixelRgb(0, 0, color, 20, 30);
  return ByteData.sublistView(image.encodePng(pixels));
}

void main() {
  withServerpod(
    'Private membership-authorized photos',
    (builder, endpoints) {
      TestSessionBuilder asUser(String id) => builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );
      final png = photo();
      String request() => Uuid().v4();
      Future<PairingState> pair(String first, String second) async {
        final pending = await endpoints.pairing.createCouple(asUser(first));
        return endpoints.pairing.joinByCode(
          asUser(second),
          pending.pairingCode!,
        );
      }

      setUp(() async {
        final session = builder.build();
        final records = await MediaRecord.db.find(session);
        for (final record in records) {
          await session.serverpod.storage['private']!.deleteFile(
            session: session,
            path: record.storagePath,
          );
        }
        await Couple.db.deleteWhere(session, where: (_) => Constant.bool(true));
      });

      test('every media RPC requires authentication', () async {
        await expectLater(
          endpoints.media.uploadPhoto(builder, png, request()),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
        await expectLater(
          endpoints.media.listAssets(builder),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
        await expectLater(
          endpoints.media.downloadPhoto(builder, request()),
          throwsA(isA<ServerpodUnauthenticatedException>()),
        );
      });

      test('unpaired and incomplete couples cannot upload or list', () async {
        for (final user in ['unpaired', 'owner']) {
          if (user == 'owner') {
            await endpoints.pairing.createCouple(asUser(user));
          }
          await expectLater(
            endpoints.media.uploadPhoto(asUser(user), png, request()),
            throwsA(mediaFailure('not_paired')),
          );
          await expectLater(
            endpoints.media.listAssets(asUser(user)),
            throwsA(mediaFailure('not_paired')),
          );
        }
      });

      test(
        'paired members upload/list/download the exact bytes with a path-free DTO',
        () async {
          final paired = await pair('alice', 'bob');
          final uploaded = await endpoints.media.uploadPhoto(
            asUser('alice'),
            png,
            request(),
          );
          expect(uploaded.coupleId, paired.coupleId);
          expect(uploaded.uploaderId, 'alice');
          expect(uploaded.width, 3);
          expect(uploaded.height, 2);
          expect(uploaded.createdAt.isUtc, isTrue);
          expect(
            uploaded.toJson().keys.where((k) => k != '__className__').toSet(),
            {
              'assetId',
              'coupleId',
              'uploaderId',
              'createdAt',
              'width',
              'height',
            },
          );
          for (final user in ['alice', 'bob']) {
            expect(
              (await endpoints.media.listAssets(asUser(user))).single.assetId,
              uploaded.assetId,
            );
            final downloaded = await endpoints.media.downloadPhoto(
              asUser(user),
              uploaded.assetId,
            );
            expect(
              downloaded.buffer.asUint8List(
                downloaded.offsetInBytes,
                downloaded.lengthInBytes,
              ),
              png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            );
          }
          final row = (await MediaRecord.db.find(builder.build())).single;
          await expectLater(
            builder.build().serverpod.storage['private']!.publicDownloadUrl(
              session: builder.build(),
              path: row.storagePath,
            ),
            throwsA(isA<CloudStorageUnsupportedOperationException>()),
          );
        },
      );

      test(
        'strangers, another couple and nonexistent assets share asset_not_found',
        () async {
          await pair('alice', 'bob');
          await pair('charlie', 'dave');
          final asset = await endpoints.media.uploadPhoto(
            asUser('alice'),
            png,
            request(),
          );
          for (final user in ['stranger', 'charlie', 'dave']) {
            for (final id in [asset.assetId, request(), 'not-a-uuid']) {
              await expectLater(
                endpoints.media.downloadPhoto(asUser(user), id),
                throwsA(mediaFailure('asset_not_found')),
              );
            }
          }
          expect(await endpoints.media.listAssets(asUser('charlie')), isEmpty);
        },
      );

      test(
        'validation rejects bad UUID, non-PNG, truncation, CRC and oversized payloads',
        () async {
          await pair('alice', 'bob');
          await expectLater(
            endpoints.media.uploadPhoto(asUser('alice'), png, '../file'),
            throwsA(mediaFailure('invalid_request_id')),
          );
          final corrupt = Uint8List.fromList(png.buffer.asUint8List());
          corrupt[corrupt.length - 1] ^= 1;
          final hugeDimensions = Uint8List.fromList(png.buffer.asUint8List());
          ByteData.sublistView(hugeDimensions).setUint32(16, 0x7fffffff);
          for (final bad in [
            ByteData(100),
            ByteData.sublistView(corrupt),
            ByteData.sublistView(hugeDimensions),
            ByteData.sublistView(png.buffer.asUint8List(0, 40)),
          ]) {
            await expectLater(
              endpoints.media.uploadPhoto(asUser('alice'), bad, request()),
              throwsA(mediaFailure('invalid_image')),
            );
          }
          await expectLater(
            endpoints.media.uploadPhoto(
              asUser('alice'),
              ByteData(2 * 1024 * 1024 + 1),
              request(),
            ),
            throwsA(mediaFailure('file_too_large')),
          );
          expect(await MediaRecord.db.count(builder.build()), 0);
        },
      );

      test(
        'stable request is idempotent across sessions; changed bytes or uploader conflict',
        () async {
          await pair('alice', 'bob');
          final id = request();
          final results = await Future.wait(
            List.generate(
              8,
              (_) => endpoints.media.uploadPhoto(asUser('alice'), png, id),
            ),
          );
          expect(results.map((r) => r.assetId).toSet(), hasLength(1));
          expect(await MediaRecord.db.count(builder.build()), 1);
          await expectLater(
            endpoints.media.uploadPhoto(asUser('alice'), photo(11), id),
            throwsA(mediaFailure('request_conflict')),
          );
          await expectLater(
            endpoints.media.uploadPhoto(asUser('bob'), png, id),
            throwsA(mediaFailure('request_conflict')),
          );
          final retry = await endpoints.media.uploadPhoto(
            asUser('alice'),
            png,
            id.toUpperCase(),
          );
          expect(retry.assetId, results.first.assetId);
          await pair('charlie', 'dave');
          final other = await endpoints.media.uploadPhoto(
            asUser('charlie'),
            photo(11),
            id,
          );
          expect(other.assetId == retry.assetId, isFalse);
        },
      );

      test(
        'database uniqueness also rejects bypassing endpoint request checks',
        () async {
          await pair('alice', 'bob');
          await endpoints.media.uploadPhoto(asUser('alice'), png, request());
          final row = (await MediaRecord.db.find(builder.build())).single;
          await expectLater(
            MediaRecord.db.insertRow(builder.build(), row.copyWith(id: null)),
            throwsA(isA<DatabaseUniqueViolationException>()),
          );
        },
      );

      test(
        'quota is 50 per couple; concurrent requests cannot exceed it; retries still succeed',
        () async {
          await pair('alice', 'bob');
          final stable = request();
          final first = await endpoints.media.uploadPhoto(
            asUser('alice'),
            png,
            stable,
          );
          for (var i = 1; i < 49; i++) {
            await endpoints.media.uploadPhoto(asUser('alice'), png, request());
          }
          Future<Object> upload() async {
            try {
              return await endpoints.media.uploadPhoto(
                asUser('bob'),
                png,
                request(),
              );
            } on MediaFailure catch (e) {
              return e;
            }
          }

          final races = await Future.wait(List.generate(8, (_) => upload()));
          expect(races.whereType<MediaAsset>(), hasLength(1));
          expect(
            races.whereType<MediaFailure>().map((e) => e.code),
            everyElement('quota_exceeded'),
          );
          expect(await MediaRecord.db.count(builder.build()), 50);
          expect(
            (await endpoints.media.uploadPhoto(
              asUser('alice'),
              png,
              stable,
            )).assetId,
            first.assetId,
          );
          await pair('charlie', 'dave');
          await endpoints.media.uploadPhoto(asUser('charlie'), png, request());
        },
      );

      test(
        'partial storage write failure is cleaned up and the same request safely retries',
        () async {
          await pair('alice', 'bob');
          final pod = builder.build().serverpod;
          final original = pod.storage['private']!;
          final failing = _FailAfterWrite(original);
          pod.addCloudStorage(failing);
          final id = request();
          try {
            await expectLater(
              endpoints.media.uploadPhoto(asUser('alice'), png, id),
              throwsStateError,
            );
            expect(await MediaRecord.db.count(builder.build()), 0);
            expect(failing.cleaned, isTrue);
          } finally {
            pod.addCloudStorage(original);
          }
          final asset = await endpoints.media.uploadPhoto(
            asUser('alice'),
            png,
            id,
          );
          expect(
            (await endpoints.media.listAssets(asUser('bob'))).single.assetId,
            asset.assetId,
          );
        },
      );

      test('metadata failure removes the private write before retry', () async {
        await pair('alice', 'bob');
        final session = builder.build();
        await session.db.unsafeQuery(
          'CREATE FUNCTION closecall_test_fail_media() RETURNS trigger LANGUAGE plpgsql AS '
          r"'BEGIN RAISE EXCEPTION ''test metadata failure''; END;'",
        );
        await session.db.unsafeQuery(
          'CREATE TRIGGER closecall_test_fail_media BEFORE INSERT ON closecall_media '
          'FOR EACH ROW EXECUTE FUNCTION closecall_test_fail_media()',
        );
        final id = request();
        final pod = session.serverpod;
        final original = pod.storage['private']!;
        final tracker = _TrackCleanup(original);
        pod.addCloudStorage(tracker);
        try {
          await expectLater(
            endpoints.media.uploadPhoto(asUser('alice'), png, id),
            throwsA(isA<DatabaseException>()),
          );
          expect(tracker.cleaned, isTrue);
          expect(await MediaRecord.db.count(session), 0);
        } finally {
          pod.addCloudStorage(original);
          await session.db.unsafeQuery(
            'DROP TRIGGER closecall_test_fail_media ON closecall_media',
          );
          await session.db.unsafeQuery(
            'DROP FUNCTION closecall_test_fail_media()',
          );
        }
        await endpoints.media.uploadPhoto(asUser('alice'), png, id);
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
  );
}

class _TrackCleanup extends CloudStorage {
  _TrackCleanup(this.delegate) : super('private');
  final CloudStorage delegate;
  bool cleaned = false;
  @override
  Future<void> storeFile({
    required Session session,
    required String path,
    required ByteData byteData,
    StoreFileOptions options = const StoreFileOptions(),
  }) => delegate.storeFile(
    session: session,
    path: path,
    byteData: byteData,
    options: options,
  );
  @override
  Future<void> deleteFile({
    required Session session,
    required String path,
  }) async {
    await delegate.deleteFile(session: session, path: path);
    cleaned = true;
    expect(await delegate.fileExists(session: session, path: path), isFalse);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unused test storage method');
}

class _FailAfterWrite extends _TrackCleanup {
  _FailAfterWrite(super.delegate);
  @override
  Future<void> storeFile({
    required Session session,
    required String path,
    required ByteData byteData,
    StoreFileOptions options = const StoreFileOptions(),
  }) async {
    await super.storeFile(
      session: session,
      path: path,
      byteData: byteData,
      options: options,
    );
    throw StateError('Injected partial storage write failure');
  }
}
