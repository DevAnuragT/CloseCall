import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:closecall_server/src/generated/protocol.dart';
import 'package:closecall_server/src/widget/widget_background_endpoint.dart';
import 'package:closecall_server/src/widget/widget_device_endpoint.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

final denied = throwsA(
  isA<PushFailure>().having(
    (e) => e.code,
    'code',
    'unauthorized_widget_device',
  ),
);
String uuid() => Uuid().v4();
ByteData png() => ByteData.sublistView(
  image.encodePng(
    image.Image(width: 2, height: 2)..setPixelRgb(0, 0, 10, 20, 30),
  ),
);

Uint8List bytesOf(ByteData value) =>
    value.buffer.asUint8List(value.offsetInBytes, value.lengthInBytes);

// All bytes still come from the existing private database storage, with no
// network. Gates let tests cross a real retrieval-time authorization boundary.
class _ObservedStorage extends CloudStorage {
  _ObservedStorage(this.inner, {this.afterRead}) : super('private');
  final CloudStorage inner;
  final Future<void> Function()? afterRead;
  var reads = 0;
  @override
  Future<ByteData> retrieveFile({
    required Session session,
    required String path,
  }) async {
    reads++;
    final bytes = await inner.retrieveFile(session: session, path: path);
    await afterRead?.call();
    return bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('test retrieval only');
}

void main() {
  withServerpod(
    'Device-scoped widget background reads',
    (builder, endpoints) {
      TestSessionBuilder asUser(String id) => builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );
      Future<void> pair(String a, String b) async {
        final pending = await endpoints.pairing.createCouple(asUser(a));
        await endpoints.pairing.joinByCode(asUser(b), pending.pairingCode!);
      }

      Future<MediaAsset> photo(String user) =>
          endpoints.media.uploadPhoto(asUser(user), png(), uuid());
      Future<void> consent(String user, bool enabled) async {
        await endpoints.widgetSchedule.setDeliveryConsent(
          asUser(user),
          enabled,
        );
      }

      Future<WidgetDeviceCredential> issue(
        String user, [
        String device = 'device',
      ]) => endpoints.widgetDevice.issueCredential(
        asUser(user),
        deviceId: device,
      );
      Future<WidgetTimeline> timeline(String secret) => endpoints
          .widgetBackground
          .currentTimeline(builder, credential: secret);
      Future<ByteData> download(String secret, String asset) => endpoints
          .widgetBackground
          .downloadPhoto(builder, credential: secret, assetId: asset);
      Future<void> ready() async {
        await pair('alice', 'bob');
        await consent('bob', true);
      }

      Future<WidgetScheduleEntry> schedule(
        String user,
        String asset,
        DateTime from,
        DateTime until,
      ) => endpoints.widgetSchedule.createSchedule(
        asUser(user),
        asset,
        from,
        until,
        uuid(),
      );

      setUp(() async {
        final session = builder.build();
        for (final row in await MediaRecord.db.find(session)) {
          await session.serverpod.storage['private']!.deleteFile(
            session: session,
            path: row.storagePath,
          );
        }
        await Couple.db.deleteWhere(session, where: (_) => Constant.bool(true));
      });

      test(
        'issuance/revocation require login; complete current pairing and own consent required',
        () async {
          await expectLater(
            endpoints.widgetDevice.issueCredential(builder, deviceId: 'device'),
            throwsA(isA<ServerpodUnauthenticatedException>()),
          );
          await expectLater(
            endpoints.widgetDevice.revokeCredential(
              builder,
              deviceId: 'device',
            ),
            throwsA(isA<ServerpodUnauthenticatedException>()),
          );
          await expectLater(issue('stranger'), denied);
          final pending = await endpoints.pairing.createCouple(asUser('alice'));
          await expectLater(issue('alice'), denied);
          await endpoints.pairing.joinByCode(
            asUser('bob'),
            pending.pairingCode!,
          );
          await expectLater(issue('bob'), denied);
          await consent('alice', true);
          await expectLater(issue('bob'), denied);
          await consent('bob', true);
          expect((await issue('bob')).userId, 'bob');
        },
      );

      test(
        'bounded device identifiers and credential input fail without leaking values',
        () async {
          await ready();
          for (final device in ['', 'x' * 129, 'a b', 'a\n', 'a\u0000']) {
            await expectLater(
              issue('bob', device),
              throwsA(
                isA<PushFailure>().having(
                  (e) => e.code,
                  'code',
                  'invalid_device',
                ),
              ),
            );
          }
          await issue('bob', 'x' * 128);
          for (final secret in [
            '',
            'x' * 42,
            'x' * 44,
            '!' * 43,
            'x' * 4096,
            'A' * 42 + 'B',
            'A' * 43,
          ]) {
            await expectLater(timeline(secret), denied);
            await expectLater(download(secret, uuid()), denied);
          }
        },
      );

      test(
        '32-byte cryptographic issuance persists only digest with exactly 24h expiry',
        () async {
          await ready();
          final now = DateTime.now().toUtc();
          final issued = await withClock(Clock.fixed(now), () => issue('bob'));
          expect(base64Url.decode('${issued.credential}='), hasLength(32));
          expect(issued.credential, matches(r'^[A-Za-z0-9_-]{43}$'));
          expect(issued.deviceId, 'device');
          expect(issued.userId, 'bob');
          expect(issued.expiresAt, now.add(const Duration(hours: 24)));
          final record = (await WidgetDeviceCredentialRecord.db.find(
            builder.build(),
          )).single;
          expect(
            record.credentialHash,
            sha256.convert(utf8.encode(issued.credential)).toString(),
          );
          expect(
            jsonEncode(record.toJson()),
            isNot(contains(issued.credential)),
          );
          expect(record.createdAt, now);
          expect(record.expiresAt, issued.expiresAt);
          expect(record.coupleId.toString(), issued.coupleId);
          expect(WidgetDeviceEndpoint().logSessions, isFalse);
          expect(WidgetBackgroundEndpoint().logSessions, isFalse);
          expect(WidgetBackgroundEndpoint().requireLogin, isFalse);
          expect((await timeline(issued.credential)).recipientId, 'bob');
          // Interactive identity cannot widen or redirect this recipient capability.
          expect(
            (await endpoints.widgetBackground.currentTimeline(
              asUser('alice'),
              credential: issued.credential,
            )).recipientId,
            'bob',
          );
        },
      );

      test(
        'concurrent rotations leave one current credential per device; other device survives',
        () async {
          await ready();
          final old = await issue('bob');
          final other = await issue('bob', 'second-device');
          final issued = await Future.wait(
            List.generate(8, (_) => issue('bob')),
          );
          final records = await WidgetDeviceCredentialRecord.db.find(
            builder.build(),
          );
          expect(records, hasLength(2));
          final current = records
              .singleWhere((r) => r.deviceId == 'device')
              .credentialHash;
          for (final value in [old, ...issued]) {
            final hash = sha256
                .convert(utf8.encode(value.credential))
                .toString();
            if (hash == current) {
              await timeline(value.credential);
            } else {
              await expectLater(timeline(value.credential), denied);
            }
          }
          await timeline(other.credential);
        },
      );

      test('expiry is end-exclusive for both timeline and download', () async {
        await ready();
        final asset = await photo('alice');
        await endpoints.widgetSchedule.sendAsset(
          asUser('alice'),
          asset.assetId,
          uuid(),
        );
        final issued = await issue('bob');
        await withClock(
          Clock.fixed(
            issued.expiresAt.subtract(const Duration(microseconds: 1)),
          ),
          () async {
            await timeline(issued.credential);
            await download(issued.credential, asset.assetId);
          },
        );
        await withClock(Clock.fixed(issued.expiresAt), () async {
          await expectLater(timeline(issued.credential), denied);
          await expectLater(download(issued.credential, asset.assetId), denied);
        });
      });

      test(
        'revocation is own-user/device scoped, idempotent, and allowed after consent withdrawal',
        () async {
          await ready();
          final issued = await issue('bob');
          final other = await issue('bob', 'other');
          await endpoints.widgetDevice.revokeCredential(
            asUser('alice'),
            deviceId: 'device',
          );
          await timeline(issued.credential);
          await consent('bob', false);
          await endpoints.widgetDevice.revokeCredential(
            asUser('bob'),
            deviceId: 'device',
          );
          await endpoints.widgetDevice.revokeCredential(
            asUser('bob'),
            deviceId: 'device',
          );
          await consent('bob', true);
          await expectLater(timeline(issued.credential), denied);
          await timeline(other.credential);
        },
      );

      test(
        'push rotation and notification revocation preserve independent read consent',
        () async {
          await ready();
          final issued = await issue('bob');
          for (final token in [
            'opaque-test-fcm-token-000001',
            'opaque-test-fcm-token-000002',
          ]) {
            await endpoints.push.registerDevice(
              asUser('bob'),
              token: token,
              deviceId: 'device',
            );
            await timeline(issued.credential);
          }
          await consent('bob', false);
          await endpoints.push.revokeDevice(
            asUser('bob'),
            deviceId: 'device',
            token: 'opaque-test-fcm-token-000002',
          );
          expect(
            await WidgetDeviceCredentialRecord.db.count(builder.build()),
            1,
          );
          await consent('bob', true);
          await timeline(issued.credential);
          await endpoints.widgetDevice.revokeCredential(
            asUser('bob'),
            deviceId: 'device',
          );
          await expectLater(timeline(issued.credential), denied);
        },
      );

      test(
        'only actual recipient horizon winners readable; library, foreign, cancelled, expired and masked assets denied',
        () async {
          await ready();
          await pair('charlie', 'dave');
          final library = await photo('alice');
          final foreign = await photo('charlie');
          final personal = await photo('bob');
          final latest = await photo('alice');
          final masked = await photo('alice');
          final winner = await photo('alice');
          final cancelled = await photo('alice');
          final outside = await photo('alice');
          final expired = await photo('alice');
          final senderOnly = await photo('bob');
          final now = DateTime.now().toUtc();
          await withClock(Clock.fixed(now), () async {
            await endpoints.widgetSchedule.setFallback(
              asUser('bob'),
              personal.assetId,
            );
            await endpoints.widgetSchedule.sendAsset(
              asUser('alice'),
              latest.assetId,
              uuid(),
            );
            await schedule(
              'alice',
              masked.assetId,
              now,
              now.add(const Duration(hours: 1)),
            );
            final canceled = await schedule(
              'alice',
              cancelled.assetId,
              now.add(const Duration(hours: 2)),
              now.add(const Duration(hours: 3)),
            );
            await endpoints.widgetSchedule.cancelSchedule(
              asUser('alice'),
              canceled.scheduleId,
            );
            await schedule(
              'alice',
              outside.assetId,
              now.add(const Duration(hours: 25)),
              now.add(const Duration(hours: 26)),
            );
            await schedule(
              'bob',
              senderOnly.assetId,
              now,
              now.add(const Duration(hours: 1)),
            );
          });
          await withClock(
            Clock.fixed(now.subtract(const Duration(hours: 2))),
            () => schedule(
              'alice',
              expired.assetId,
              now.subtract(const Duration(hours: 2)),
              now.subtract(const Duration(hours: 1)),
            ),
          );
          final entry = await withClock(
            Clock.fixed(now.add(const Duration(microseconds: 1))),
            () => schedule(
              'alice',
              winner.assetId,
              now,
              now.add(const Duration(hours: 1)),
            ),
          );
          final issued = await issue('bob');
          final narrowed = await timeline(issued.credential);
          expect(narrowed.recipientId, 'bob');
          expect(narrowed.currentAssetId, winner.assetId);
          expect(narrowed.latestAssetId, latest.assetId);
          expect(narrowed.fallbackAssetId, isNull);
          expect(narrowed.schedules.map((e) => e.scheduleId), [
            entry.scheduleId,
          ]);
          expect(narrowed.schedules.single.activeFrom, narrowed.serverTime);
          for (final asset in [
            library,
            foreign,
            personal,
            masked,
            cancelled,
            outside,
            expired,
            senderOnly,
          ]) {
            await expectLater(
              download(issued.credential, asset.assetId),
              denied,
            );
          }
          for (final id in ['../private', uuid()]) {
            await expectLater(download(issued.credential, id), denied);
          }
          final downloaded = await download(issued.credential, winner.assetId);
          expect(
            downloaded.buffer.asUint8List(
              downloaded.offsetInBytes,
              downloaded.lengthInBytes,
            ),
            bytesOf(png()),
          );
          await download(issued.credential, latest.assetId);
          // At exact expiry the old winner ceases to authorize even if its bytes
          // were previously listed. Latest sent baseline remains permitted.
          await withClock(
            Clock.fixed(entry.activeUntil),
            () => expectLater(
              download(issued.credential, winner.assetId),
              denied,
            ),
          );
        },
      );

      test(
        'personal fallback is readable when it is the actual recipient baseline',
        () async {
          await ready();
          final asset = await photo('bob');
          await endpoints.widgetSchedule.setFallback(
            asUser('bob'),
            asset.assetId,
          );
          final issued = await issue('bob');
          final value = await timeline(issued.credential);
          expect(value.currentAssetId, asset.assetId);
          expect(value.fallbackAssetId, asset.assetId);
          expect(value.latestAssetId, isNull);
          final bytes = await download(issued.credential, asset.assetId);
          expect(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
            bytesOf(png()),
          );
        },
      );

      test(
        'masked baseline absent; future winners included and windows clipped to credential horizon',
        () async {
          await ready();
          final baseline = await photo('alice');
          final current = await photo('alice');
          final future = await photo('alice');
          final now = DateTime.now().toUtc();
          await endpoints.widgetSchedule.sendAsset(
            asUser('alice'),
            baseline.assetId,
            uuid(),
          );
          await withClock(
            Clock.fixed(now),
            () => schedule(
              'alice',
              current.assetId,
              now,
              now.add(const Duration(hours: 25)),
            ),
          );
          await withClock(
            Clock.fixed(now.add(const Duration(microseconds: 1))),
            () => schedule(
              'alice',
              future.assetId,
              now.add(const Duration(hours: 2)),
              now.add(const Duration(hours: 26)),
            ),
          );
          final issued = await issue('bob');
          final value = await timeline(issued.credential);
          expect(value.latestAssetId, isNull);
          expect(value.schedules.map((e) => e.assetId).toSet(), {
            current.assetId,
            future.assetId,
          });
          expect(
            value.schedules.every(
              (e) => !e.activeUntil.isAfter(issued.expiresAt),
            ),
            isTrue,
          );
          await expectLater(
            download(issued.credential, baseline.assetId),
            denied,
          );
          await download(issued.credential, future.assetId);
        },
      );

      test(
        'consent withdrawal and current membership/pairing loss immediately deny both reads',
        () async {
          await ready();
          final asset = await photo('alice');
          await endpoints.widgetSchedule.sendAsset(
            asUser('alice'),
            asset.assetId,
            uuid(),
          );
          final issued = await issue('bob');
          await consent('bob', false);
          await expectLater(timeline(issued.credential), denied);
          await expectLater(download(issued.credential, asset.assetId), denied);
          await expectLater(issue('bob'), denied);
          await consent('bob', true);
          final session = builder.build();
          final partner = (await CoupleMember.db.findFirstRow(
            session,
            where: (t) => t.userIdentifier.equals('alice'),
          ))!;
          await CoupleMember.db.deleteRow(session, partner);
          await expectLater(timeline(issued.credential), denied);
          await expectLater(download(issued.credential, asset.assetId), denied);
          await expectLater(issue('bob'), denied);
          final recipient = (await CoupleMember.db.findFirstRow(
            session,
            where: (t) => t.userIdentifier.equals('bob'),
          ))!;
          await CoupleMember.db.deleteRow(session, recipient);
          expect(await WidgetDeviceCredentialRecord.db.count(session), 0);
          await pair('bob', 'new-partner');
          await consent('bob', true);
          await expectLater(timeline(issued.credential), denied);
          expect((await issue('bob')).coupleId, isNot(issued.coupleId));
        },
      );

      test(
        'changed member identity and incomplete couple fail closed',
        () async {
          await ready();
          final issued = await issue('bob');
          final session = builder.build();
          final member = (await CoupleMember.db.findFirstRow(
            session,
            where: (t) => t.userIdentifier.equals('bob'),
          ))!;
          await CoupleMember.db.updateRow(
            session,
            member.copyWith(userIdentifier: 'replacement'),
          );
          await expectLater(timeline(issued.credential), denied);
          await CoupleMember.db.updateRow(session, member);
          final couple = (await Couple.db.findById(session, member.coupleId))!;
          await Couple.db.updateRow(
            session,
            couple.copyWith(pairingCode: '123456'),
          );
          await expectLater(timeline(issued.credential), denied);
          await expectLater(issue('bob'), denied);
        },
      );

      test(
        'allowlist fails closed when more than twelve actual horizon photos are needed',
        () async {
          await ready();
          final now = DateTime.now().toUtc();
          for (var i = 0; i < 13; i++) {
            final asset = await photo('alice');
            await schedule(
              'alice',
              asset.assetId,
              now.add(Duration(hours: i)),
              now.add(Duration(hours: i + 1)),
            );
          }
          final issued = await issue('bob');
          await expectLater(timeline(issued.credential), denied);
        },
      );

      test(
        'retrieval rechecks time: expiry and expired winning asset release no bytes',
        () async {
          await ready();
          final asset = await photo('alice');
          var time = DateTime.now().toUtc();
          final entry = await schedule(
            'alice',
            asset.assetId,
            time,
            time.add(const Duration(hours: 1)),
          );
          final issued = await issue('bob');
          final pod = builder.build().serverpod;
          final original = pod.storage['private']!;
          final observed = _ObservedStorage(
            original,
            afterRead: () async {
              time = entry.activeUntil;
            },
          );
          pod.storage['private'] = observed;
          try {
            await withClock(
              Clock(() => time),
              () => expectLater(
                download(issued.credential, asset.assetId),
                denied,
              ),
            );
            expect(observed.reads, 1);
          } finally {
            pod.storage['private'] = original;
          }
          await endpoints.widgetSchedule.sendAsset(
            asUser('alice'),
            asset.assetId,
            uuid(),
          );
          time = DateTime.now().toUtc();
          pod.storage['private'] = _ObservedStorage(
            original,
            afterRead: () async {
              time = issued.expiresAt;
            },
          );
          try {
            await withClock(
              Clock(() => time),
              () => expectLater(
                download(issued.credential, asset.assetId),
                denied,
              ),
            );
          } finally {
            pod.storage['private'] = original;
          }
        },
      );

      test(
        'consent revocation serializes behind an in-flight private retrieval then blocks later reads',
        () async {
          await ready();
          final asset = await photo('alice');
          await endpoints.widgetSchedule.sendAsset(
            asUser('alice'),
            asset.assetId,
            uuid(),
          );
          final issued = await issue('bob');
          final entered = Completer<void>();
          final release = Completer<void>();
          final pod = builder.build().serverpod;
          final original = pod.storage['private']!;
          pod.storage['private'] = _ObservedStorage(
            original,
            afterRead: () async {
              entered.complete();
              await release.future;
            },
          );
          Future<void>? withdrawal;
          try {
            final reading = download(issued.credential, asset.assetId);
            await entered.future.timeout(const Duration(seconds: 5));
            var completed = false;
            withdrawal = consent('bob', false).then((_) {
              completed = true;
            });
            await Future<void>.delayed(const Duration(milliseconds: 100));
            expect(completed, isFalse);
            release.complete();
            await reading.timeout(const Duration(seconds: 5));
            await withdrawal.timeout(const Duration(seconds: 5));
            await expectLater(timeline(issued.credential), denied);
          } finally {
            if (!release.isCompleted) release.complete();
            await withdrawal;
            pod.storage['private'] = original;
          }
        },
      );

      test(
        'database enforces same-couple, digest/device/expiry checks, uniqueness and cascades',
        () async {
          await ready();
          await pair('charlie', 'dave');
          await issue('bob');
          final session = builder.build();
          final row = (await WidgetDeviceCredentialRecord.db.find(
            session,
          )).single;
          final foreign = (await CoupleMember.db.findFirstRow(
            session,
            where: (t) => t.userIdentifier.equals('dave'),
          ))!;
          for (final invalid in [
            row.copyWith(coupleId: foreign.coupleId),
            row.copyWith(memberId: foreign.id!),
            row.copyWith(credentialHash: 'raw-secret'),
            row.copyWith(deviceId: ''),
            row.copyWith(deviceId: 'a b'),
            row.copyWith(expiresAt: row.createdAt),
            row.copyWith(
              expiresAt: row.createdAt.add(const Duration(hours: 25)),
            ),
          ]) {
            await expectLater(
              WidgetDeviceCredentialRecord.db.updateRow(session, invalid),
              throwsA(isA<DatabaseException>()),
            );
          }
          await expectLater(
            WidgetDeviceCredentialRecord.db.insertRow(
              session,
              row.copyWith(id: null),
            ),
            throwsA(isA<DatabaseException>()),
          );
          await Couple.db.deleteWhere(
            session,
            where: (t) => t.id.equals(row.coupleId),
          );
          expect(await WidgetDeviceCredentialRecord.db.count(session), 0);
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
    configOverride: (config) => config.copyWith(
      futureCallExecutionEnabled: false,
      futureCall: const FutureCallConfig(enabled: false),
    ),
    testServerOutputMode: TestServerOutputMode.silent,
  );
}
