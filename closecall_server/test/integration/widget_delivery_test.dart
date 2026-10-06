import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:closecall_server/src/generated/protocol.dart';
import 'package:closecall_server/src/push/fcm_sender.dart';
import 'package:closecall_server/src/push/push_outbox_dispatcher.dart';
import 'package:closecall_server/src/widget/widget_schedule_endpoint.dart';
import 'package:closecall_server/src/widget/widget_timeline_service.dart';
import 'package:image/image.dart' as image;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

Matcher failure(String code) =>
    isA<ScheduleFailure>().having((e) => e.code, 'code', code);
String uuid() => Uuid().v4();

class _FakeFcmSender implements FcmSender {
  _FakeFcmSender([Iterable<FcmSendStatus> statuses = const []])
    : statuses = [...statuses];

  final List<FcmSendStatus> statuses;
  final calls = <({String token, int version})>[];

  @override
  Future<FcmSendResult> send({
    required String token,
    required int version,
  }) async {
    calls.add((token: token, version: version));
    final status = statuses.isEmpty ? FcmSendStatus.sent : statuses.removeAt(0);
    return FcmSendResult(status);
  }
}

void main() {
  withServerpod(
    'Private send-now delivery',
    (builder, endpoints) {
      TestSessionBuilder asUser(String id) => builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );
      Future<void> pair(String sender, String recipient) async {
        final pending = await endpoints.pairing.createCouple(asUser(sender));
        await endpoints.pairing.joinByCode(
          asUser(recipient),
          pending.pairingCode!,
        );
      }

      Future<MediaAsset> photo(String user, [int color = 10]) =>
          endpoints.media.uploadPhoto(
            asUser(user),
            ByteData.sublistView(
              image.encodePng(
                image.Image(width: 2, height: 2)
                  ..setPixelRgb(0, 0, color, 20, 30),
              ),
            ),
            uuid(),
          );
      Future<WidgetSendReceipt> send(
        String user,
        String asset, [
        String? request,
      ]) => endpoints.widgetSchedule.sendAsset(
        asUser(user),
        asset,
        request ?? uuid(),
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
        'all delivery RPCs require authentication and a completed pair',
        () async {
          final denied = throwsA(isA<ServerpodUnauthenticatedException>());
          await expectLater(
            endpoints.widgetSchedule.getDeliveryState(builder),
            denied,
          );
          await expectLater(
            endpoints.widgetSchedule.setDeliveryConsent(builder, true),
            denied,
          );
          await expectLater(
            endpoints.widgetSchedule.sendAsset(builder, uuid(), uuid()),
            denied,
          );
          await endpoints.pairing.createCouple(asUser('pending'));
          for (final user in ['pending', 'stranger']) {
            await expectLater(
              endpoints.widgetSchedule.getDeliveryState(asUser(user)),
              throwsA(failure('not_paired')),
            );
            await expectLater(
              endpoints.widgetSchedule.setDeliveryConsent(asUser(user), true),
              throwsA(failure('not_paired')),
            );
            await expectLater(
              send(user, uuid()),
              throwsA(failure('not_paired')),
            );
          }
        },
      );

      test(
        'consent defaults off, persists for recipient only; uploads never send',
        () async {
          await pair('alice', 'bob');
          final initial = await endpoints.widgetSchedule.getDeliveryState(
            asUser('bob'),
          );
          expect(initial.autoUpdateEnabled, isFalse);
          expect(initial.version, 0);
          expect(initial.latestAssetId, isNull);
          await photo('alice');
          expect(await WidgetSendRecord.db.count(builder.build()), 0);
          expect(
            (await endpoints.widgetSchedule.currentTimeline(
              asUser('bob'),
            )).currentAssetId,
            isNull,
          );
          final enabled = await endpoints.widgetSchedule.setDeliveryConsent(
            asUser('bob'),
            true,
          );
          expect(enabled.recipientId, 'bob');
          expect(enabled.autoUpdateEnabled, isTrue);
          expect(
            (await endpoints.widgetSchedule.getDeliveryState(
              asUser('bob'),
            )).autoUpdateEnabled,
            isTrue,
          );
          expect(
            (await endpoints.widgetSchedule.getDeliveryState(
              asUser('alice'),
            )).autoUpdateEnabled,
            isFalse,
          );
          expect(
            (await endpoints.widgetSchedule.setDeliveryConsent(
              asUser('bob'),
              false,
            )).autoUpdateEnabled,
            isFalse,
          );
          expect(await WidgetDeliveryRecord.db.count(builder.build()), 1);
        },
      );

      test(
        'send derives partner, preserves fallback, and exposes latest even while opted out',
        () async {
          await pair('alice', 'bob');
          final asset = await photo('alice');
          final fallback = await photo('bob');
          await endpoints.widgetSchedule.setFallback(
            asUser('bob'),
            fallback.assetId,
          );
          final receipt = await send('alice', asset.assetId);
          expect(receipt.senderId, 'alice');
          expect(receipt.recipientId, 'bob');
          expect(receipt.recipientAutoUpdateEnabled, isFalse);
          expect(receipt.version, 1);
          final state = await endpoints.widgetSchedule.getDeliveryState(
            asUser('bob'),
          );
          expect(state.latestSenderId, 'alice');
          expect(state.latestAssetId, asset.assetId);
          expect(state.latestSentAt, receipt.createdAt);
          expect(state.version, 1);
          final timeline = await endpoints.widgetSchedule.currentTimeline(
            asUser('bob'),
          );
          expect(timeline.currentAssetId, asset.assetId);
          expect(timeline.latestAssetId, asset.assetId);
          expect(timeline.deliveryVersion, 1);
          expect(timeline.autoUpdateEnabled, isFalse);
          expect(timeline.fallbackAssetId, fallback.assetId);
          expect(
            (await endpoints.widgetSchedule.currentTimeline(
              asUser('alice'),
            )).latestAssetId,
            isNull,
          );
          final partnerView = await endpoints.widgetSchedule.partnerTimeline(
            asUser('alice'),
          );
          expect(partnerView.latestAssetId, asset.assetId);
          expect(partnerView.recipientId, 'bob');
        },
      );

      test(
        'concurrent retries deduplicate; old retries never replace a newer latest state',
        () async {
          await pair('alice', 'bob');
          final first = await photo('alice');
          final second = await photo('alice', 11);
          final request = uuid();
          final receipts = await Future.wait(
            List.generate(8, (_) => send('alice', first.assetId, request)),
          );
          expect(receipts.map((r) => r.sendId).toSet(), hasLength(1));
          expect(receipts.map((r) => r.version), everyElement(1));
          final newest = await send('alice', second.assetId);
          expect(newest.version, 2);
          final staleRetry = await send(
            'alice',
            first.assetId.toUpperCase(),
            request.toUpperCase(),
          );
          expect(staleRetry.toJson(), receipts.first.toJson());
          final state = await endpoints.widgetSchedule.getDeliveryState(
            asUser('bob'),
          );
          expect(state.version, 2);
          expect(state.latestAssetId, second.assetId);
          expect(await WidgetSendRecord.db.count(builder.build()), 2);
          await expectLater(
            send('alice', second.assetId, request),
            throwsA(failure('request_conflict')),
          );
          await expectLater(
            send('bob', first.assetId, request),
            throwsA(failure('request_conflict')),
          );
          await expectLater(
            send('alice', first.assetId, '../bad'),
            throwsA(failure('invalid_request_id')),
          );
        },
      );

      test(
        'foreign, nonexistent and partner-owned assets rejected without mutation',
        () async {
          await pair('alice', 'bob');
          await pair('charlie', 'dave');
          final partnerOwned = await photo('bob');
          final foreign = await photo('charlie');
          for (final id in [
            partnerOwned.assetId,
            foreign.assetId,
            uuid(),
            'bad',
          ]) {
            await expectLater(
              send('alice', id),
              throwsA(failure('asset_not_found')),
            );
          }
          await expectLater(
            send('stranger', foreign.assetId),
            throwsA(failure('not_paired')),
          );
          expect(await WidgetSendRecord.db.count(builder.build()), 0);
          expect(await WidgetDeliveryRecord.db.count(builder.build()), 0);
        },
      );

      test(
        'only opted-in send posts lightweight notice, and the event observes committed state',
        () async {
          await pair('alice', 'bob');
          final asset = await photo('alice');
          final session = builder.build();
          final notices = <TimelineNotice>[];
          final observed = Completer<WidgetDeliveryRecord>();
          final subscription = session.messages
              .createStream<TimelineNotice>(timelineChannel('bob'))
              .listen((notice) async {
                if (notice.deliveryVersion == null) return;
                notices.add(notice);
                final committed = (await WidgetDeliveryRecord.db.findFirstRow(
                  session,
                  where: (t) => t.version.equals(notice.deliveryVersion!),
                ))!;
                if (!observed.isCompleted) observed.complete(committed);
              });
          try {
            await send('alice', asset.assetId);
            await Future<void>.delayed(const Duration(milliseconds: 100));
            expect(notices, isEmpty);
            expect(await PushOutbox.db.count(builder.build()), 0);
            await endpoints.widgetSchedule.setDeliveryConsent(
              asUser('bob'),
              true,
            );
            final request = uuid();
            final receipt = await send('alice', asset.assetId, request);
            final committed = await observed.future.timeout(
              const Duration(seconds: 5),
            );
            expect(committed.assetId.toString(), receipt.assetId);
            expect(committed.version, receipt.version);
            expect(notices.single.toJson().keys.toSet(), {
              '__className__',
              'recipientId',
              'deliveryVersion',
            });
            expect(await PushOutbox.db.count(builder.build()), 1);
            await send('alice', asset.assetId, request);
            await Future<void>.delayed(const Duration(milliseconds: 100));
            expect(notices, hasLength(1));
          } finally {
            await subscription.cancel();
            await session.close();
          }
        },
      );

      test(
        'outbox leases, retries, revokes invalid tokens, and is idempotent',
        () async {
          await pair('alice', 'bob');
          final asset = await photo('alice');
          await endpoints.widgetSchedule.setDeliveryConsent(
            asUser('bob'),
            true,
          );
          await endpoints.push.registerDevice(
            asUser('bob'),
            token: 'opaque-token-for-outbox-1234567890',
            deviceId: 'device',
          );
          final receipt = await send('alice', asset.assetId);
          final session = builder.build();
          final outbox = (await PushOutbox.db.find(session)).single;
          expect(outbox.version, receipt.version);
          expect(outbox.sendId.toString(), receipt.sendId);

          final sender = _FakeFcmSender();
          final dispatcher = PushOutboxDispatcher(
            sender: sender,
            owner: 'test-owner',
            baseBackoff: Duration.zero,
            maxBackoff: Duration.zero,
          );
          outbox.leasedUntil = DateTime.now().toUtc().add(
            const Duration(minutes: 1),
          );
          outbox.leaseOwner = 'another-pod';
          await PushOutbox.db.updateRow(session, outbox);
          await dispatcher.reconcile(session.serverpod);
          expect(sender.calls, isEmpty);
          outbox.leasedUntil = DateTime.now().toUtc().subtract(
            const Duration(seconds: 1),
          );
          outbox.leaseOwner = null;
          await PushOutbox.db.updateRow(session, outbox);
          await dispatcher.reconcile(session.serverpod);
          expect(sender.calls, [
            (token: 'opaque-token-for-outbox-1234567890', version: 1),
          ]);
          expect(
            (await PushOutbox.db.find(session)).single.completedAt,
            isNotNull,
          );
          await dispatcher.reconcile(session.serverpod);
          expect(sender.calls, hasLength(1));

          // A transient response clears the lease and is available again with
          // the configured zero backoff; the second attempt completes it.
          final second = await photo('alice', 11);
          final secondReceipt = await send('alice', second.assetId);
          final secondRow = (await PushOutbox.db.find(
            session,
            where: (t) => t.version.equals(secondReceipt.version),
          )).single;
          final retrySender = _FakeFcmSender([
            FcmSendStatus.transientFailure,
            FcmSendStatus.sent,
          ]);
          final retryDispatcher = PushOutboxDispatcher(
            sender: retrySender,
            owner: 'retry-owner',
            baseBackoff: Duration.zero,
            maxBackoff: Duration.zero,
          );
          await retryDispatcher.reconcile(session.serverpod, maxRows: 1);
          expect(
            (await PushOutbox.db.findById(session, secondRow.id!))!.completedAt,
            isNull,
          );
          await retryDispatcher.reconcile(session.serverpod, maxRows: 1);
          expect(retrySender.calls, hasLength(2));
          expect(
            (await PushOutbox.db.findById(session, secondRow.id!))!.completedAt,
            isNotNull,
          );

          // FCM UNREGISTERED is terminal for the device, not the committed
          // send. The event still completes after revoking that registration.
          final third = await photo('alice', 12);
          await send('alice', third.assetId);
          final invalidSender = _FakeFcmSender([FcmSendStatus.invalidToken]);
          await PushOutboxDispatcher(
            sender: invalidSender,
            owner: 'invalid-owner',
          ).reconcile(session.serverpod);
          final registration = await PushDeviceRegistration.db.findFirstRow(
            session,
          );
          expect(registration?.revokedAt, isNotNull);
          expect(
            (await PushOutbox.db.find(
              session,
            )).where((row) => row.version == 3).single.completedAt,
            isNotNull,
          );
          await session.close();
        },
      );

      test(
        'failed send transaction produces neither pointer nor send notice',
        () async {
          await pair('alice', 'bob');
          final asset = await photo('alice');
          await endpoints.widgetSchedule.setDeliveryConsent(
            asUser('bob'),
            true,
          );
          final session = builder.build();
          final notices = <TimelineNotice>[];
          final subscription = session.messages
              .createStream<TimelineNotice>(timelineChannel('bob'))
              .listen(notices.add);
          await session.db.unsafeSimpleExecute(
            r"CREATE FUNCTION closecall_reject_send() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'test rollback'; END; $$;",
          );
          await session.db.unsafeExecute(
            'CREATE TRIGGER closecall_reject_send BEFORE INSERT ON closecall_widget_send FOR EACH ROW EXECUTE FUNCTION closecall_reject_send()',
          );
          final request = uuid();
          try {
            await expectLater(
              send('alice', asset.assetId, request),
              throwsA(isA<DatabaseException>()),
            );
            expect(await WidgetSendRecord.db.count(session), 0);
            expect(await PushOutbox.db.count(session), 0);
            expect(
              (await endpoints.widgetSchedule.getDeliveryState(
                asUser('bob'),
              )).version,
              0,
            );
            await Future<void>.delayed(const Duration(milliseconds: 100));
            expect(notices, isEmpty);
          } finally {
            await session.db.unsafeExecute(
              'DROP TRIGGER closecall_reject_send ON closecall_widget_send',
            );
            await session.db.unsafeExecute(
              'DROP FUNCTION closecall_reject_send()',
            );
            await subscription.cancel();
            await session.close();
          }
          expect((await send('alice', asset.assetId, request)).version, 1);
        },
      );

      test(
        'watch recipient receives latest state and persistent consent; sender sees no incoming asset',
        () async {
          await pair('alice', 'bob');
          final asset = await photo('alice');
          await endpoints.widgetSchedule.setDeliveryConsent(
            asUser('bob'),
            true,
          );
          final ownSession = asUser('bob').build();
          final iterator = StreamIterator(
            WidgetScheduleEndpoint().watchTimeline(ownSession),
          );
          try {
            expect(
              await iterator.moveNext().timeout(const Duration(seconds: 5)),
              isTrue,
            );
            expect(iterator.current.autoUpdateEnabled, isTrue);
            final next = iterator.moveNext();
            final receipt = await send('alice', asset.assetId);
            expect(await next.timeout(const Duration(seconds: 5)), isTrue);
            expect(iterator.current.currentAssetId, asset.assetId);
            expect(iterator.current.deliveryVersion, receipt.version);
            expect(iterator.current.recipientId, 'bob');
            expect(
              (await endpoints.widgetSchedule
                      .watchTimeline(asUser('alice'))
                      .first)
                  .latestAssetId,
              isNull,
            );
          } finally {
            await iterator.cancel();
            await ownSession.close();
          }
        },
      );

      test(
        'schedule priority and personal fallback remain; expiry restores latest sent baseline',
        () async {
          await pair('alice', 'bob');
          final baseline = await photo('alice');
          final scheduled = await photo('alice', 11);
          final fallback = await photo('bob');
          final now = DateTime.now().toUtc();
          await endpoints.widgetSchedule.setFallback(
            asUser('bob'),
            fallback.assetId,
          );
          await send('alice', baseline.assetId);
          final entry = await endpoints.widgetSchedule.createSchedule(
            asUser('alice'),
            scheduled.assetId,
            now,
            now.add(const Duration(hours: 1)),
            uuid(),
          );
          final current = await endpoints.widgetSchedule.currentTimeline(
            asUser('bob'),
          );
          expect(current.currentAssetId, scheduled.assetId);
          expect(current.latestAssetId, baseline.assetId);
          expect(current.fallbackAssetId, fallback.assetId);
          expect(current.schedules.single.scheduleId, entry.scheduleId);
          expect(current.nextTransition, entry.activeUntil);
          final expired = await withClock(
            Clock.fixed(entry.activeUntil),
            () => endpoints.widgetSchedule.currentTimeline(asUser('bob')),
          );
          expect(expired.currentAssetId, baseline.assetId);
          expect(expired.schedules, isEmpty);
        },
      );

      test(
        'database rejects cross-couple delivery state and membership loss clears consent',
        () async {
          await pair('alice', 'bob');
          await pair('charlie', 'dave');
          final asset = await photo('alice');
          final foreign = await photo('charlie');
          await endpoints.widgetSchedule.setDeliveryConsent(
            asUser('bob'),
            true,
          );
          await send('alice', asset.assetId);
          final session = builder.build();
          final state = (await WidgetDeliveryRecord.db.find(session)).single;
          await expectLater(
            WidgetDeliveryRecord.db.updateRow(
              session,
              state.copyWith(assetId: UuidValue.fromString(foreign.assetId)),
            ),
            throwsA(isA<DatabaseException>()),
          );
          final member = (await CoupleMember.db.findFirstRow(
            session,
            where: (t) => t.userIdentifier.equals('bob'),
          ))!;
          await CoupleMember.db.deleteRow(session, member);
          expect(await WidgetDeliveryRecord.db.count(session), 0);
          expect(await WidgetSendRecord.db.count(session), 0);
          await expectLater(
            endpoints.widgetSchedule.getDeliveryState(asUser('bob')),
            throwsA(failure('not_paired')),
          );
          await expectLater(
            send('alice', asset.assetId),
            throwsA(failure('not_paired')),
          );
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
