import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:closecall_server/src/generated/protocol.dart';
import 'package:closecall_server/src/widget/widget_schedule_endpoint.dart';
import 'package:closecall_server/src/widget/widget_schedule_policy.dart';
import 'package:closecall_server/src/widget/widget_timeline_service.dart';
import 'package:image/image.dart' as image;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod/protocol.dart' show FutureCallEntry;
import 'package:serverpod/src/server/serverpod.dart'
    show ServerpodInternalMethods;
import 'package:serverpod_database/serverpod_database.dart' as database;
// The official pinned SQL generator exercises JSON actions, not hand-written SQL.
import 'package:serverpod_cli/src/database/dialects/postgres.dart';
import 'package:test/test.dart';

import '../../tool/schedule_migration_sql.dart';

import 'test_tools/serverpod_test_tools.dart';

Matcher failure(String code) =>
    isA<ScheduleFailure>().having((e) => e.code, 'code', code);
final reference = DateTime.utc(2026, 10, 4, 12);
String uuid() => Uuid().v4();

void main() {
  withServerpod(
    'Persisted private widget schedules',
    (builder, endpoints) {
      TestSessionBuilder asUser(String id) => builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );
      Future<PairingState> pair(String first, String second) async {
        final pending = await endpoints.pairing.createCouple(asUser(first));
        return endpoints.pairing.joinByCode(
          asUser(second),
          pending.pairingCode!,
        );
      }

      Future<MediaAsset> photo(String user, [int color = 10]) {
        final pixels = image.Image(width: 2, height: 2)
          ..setPixelRgb(0, 0, color, 20, 30);
        return endpoints.media.uploadPhoto(
          asUser(user),
          ByteData.sublistView(image.encodePng(pixels)),
          uuid(),
        );
      }

      Future<WidgetScheduleEntry> create(
        String user,
        String asset, {
        DateTime? from,
        DateTime? until,
        String? request,
      }) => endpoints.widgetSchedule.createSchedule(
        asUser(user),
        asset,
        from ?? reference,
        until ?? reference.add(const Duration(hours: 1)),
        request ?? uuid(),
      );
      Future<CoupleMember> member(String user) async =>
          (await CoupleMember.db.findFirstRow(
            builder.build(),
            where: (t) => t.userIdentifier.equals(user),
          ))!;

      setUp(() async {
        final session = builder.build();
        await FutureCallEntry.db.deleteWhere(
          session,
          where: (_) => Constant.bool(true),
        );
        for (final row in await MediaRecord.db.find(session)) {
          await session.serverpod.storage['private']!.deleteFile(
            session: session,
            path: row.storagePath,
          );
        }
        await Couple.db.deleteWhere(session, where: (_) => Constant.bool(true));
      });

      test('all RPCs and watch reject unauthenticated users', () async {
        final now = DateTime.now().toUtc();
        final denied = throwsA(isA<ServerpodUnauthenticatedException>());
        await expectLater(
          endpoints.widgetSchedule.currentTimeline(builder),
          denied,
        );
        await expectLater(
          endpoints.widgetSchedule.partnerTimeline(builder),
          denied,
        );
        await expectLater(
          endpoints.widgetSchedule.setFallback(builder, uuid()),
          denied,
        );
        await expectLater(
          endpoints.widgetSchedule.createSchedule(
            builder,
            uuid(),
            now,
            now.add(const Duration(hours: 1)),
            uuid(),
          ),
          denied,
        );
        await expectLater(
          endpoints.widgetSchedule.cancelSchedule(builder, uuid()),
          denied,
        );
        await expectLater(
          endpoints.widgetSchedule.watchTimeline(builder).first,
          denied,
        );
      });

      test(
        'complete couple required for all scheduling and stream methods',
        () async {
          await endpoints.pairing.createCouple(asUser('pending'));
          for (final user in ['stranger', 'pending']) {
            await expectLater(
              endpoints.widgetSchedule.currentTimeline(asUser(user)),
              throwsA(failure('not_paired')),
            );
            await expectLater(
              endpoints.widgetSchedule.partnerTimeline(asUser(user)),
              throwsA(failure('not_paired')),
            );
            await expectLater(
              endpoints.widgetSchedule.setFallback(asUser(user), uuid()),
              throwsA(failure('not_paired')),
            );
            await expectLater(
              create(user, uuid()),
              throwsA(failure('not_paired')),
            );
            await expectLater(
              endpoints.widgetSchedule.cancelSchedule(asUser(user), uuid()),
              throwsA(failure('not_paired')),
            );
            await expectLater(
              endpoints.widgetSchedule.watchTimeline(asUser(user)).first,
              throwsA(failure('not_paired')),
            );
          }
        },
      );

      test(
        'sender/recipient derived from membership; fallback only changes current owner',
        () async {
          await pair('alice', 'bob');
          final a = await photo('alice');
          final b = await photo('bob', 11);
          await withClock(Clock.fixed(reference), () async {
            final empty = await endpoints.widgetSchedule.currentTimeline(
              asUser('alice'),
            );
            expect(empty.currentAssetId, isNull);
            expect(empty.fallbackAssetId, isNull);
            expect(empty.recipientId, 'alice');
            await endpoints.widgetSchedule.setFallback(
              asUser('alice'),
              a.assetId,
            );
            expect(
              (await endpoints.widgetSchedule.currentTimeline(
                asUser('bob'),
              )).fallbackAssetId,
              isNull,
            );
            await endpoints.widgetSchedule.setFallback(
              asUser('bob'),
              b.assetId,
            );
            final entry = await create('alice', a.assetId);
            expect(entry.senderId, 'alice');
            expect(entry.recipientId, 'bob');
            expect(
              entry.activeFrom.isUtc &&
                  entry.activeUntil.isUtc &&
                  entry.createdAt.isUtc,
              isTrue,
            );
            final current = await endpoints.widgetSchedule.currentTimeline(
              asUser('alice'),
            );
            final partner = await endpoints.widgetSchedule.partnerTimeline(
              asUser('alice'),
            );
            expect(current.fallbackAssetId, a.assetId);
            expect(current.schedules, isEmpty);
            expect(partner.recipientId, 'bob');
            expect(partner.fallbackAssetId, b.assetId);
            expect(partner.currentAssetId, a.assetId);
            expect(partner.schedules.single.scheduleId, entry.scheduleId);
            expect(
              (await endpoints.widgetSchedule.currentTimeline(
                asUser('bob'),
              )).toJson(),
              partner.toJson(),
            );
          });
        },
      );

      test(
        'cross-couple and nonexistent assets indistinguishable; strangers cannot cancel',
        () async {
          await pair('alice', 'bob');
          await pair('charlie', 'dave');
          final a = await photo('alice');
          final other = await photo('charlie');
          await withClock(Clock.fixed(reference), () async {
            for (final id in [other.assetId, uuid(), 'bad']) {
              await expectLater(
                create('alice', id),
                throwsA(failure('asset_not_found')),
              );
              await expectLater(
                endpoints.widgetSchedule.setFallback(asUser('bob'), id),
                throwsA(failure('asset_not_found')),
              );
            }
            final entry = await create('alice', a.assetId);
            for (final id in [entry.scheduleId, uuid(), 'bad']) {
              await expectLater(
                endpoints.widgetSchedule.cancelSchedule(asUser('charlie'), id),
                throwsA(failure('schedule_not_found')),
              );
            }
            expect(
              (await endpoints.widgetSchedule.currentTimeline(
                asUser('charlie'),
              )).schedules,
              isEmpty,
            );
          });
        },
      );

      test(
        'UTC windows positive <=7 days, starts <=30 days ahead, new expiry future',
        () async {
          await pair('alice', 'bob');
          final asset = await photo('alice');
          await withClock(Clock.fixed(reference), () async {
            for (final (from, until) in [
              (reference, reference),
              (reference, reference.subtract(const Duration(seconds: 1))),
              (
                reference,
                reference.add(const Duration(days: 7, microseconds: 1)),
              ),
              (
                reference.add(const Duration(days: 30, microseconds: 1)),
                reference.add(const Duration(days: 31)),
              ),
              (reference.subtract(const Duration(hours: 1)), reference),
            ]) {
              await expectLater(
                create('alice', asset.assetId, from: from, until: until),
                throwsA(failure('invalid_window')),
              );
            }
            await expectLater(
              create('alice', asset.assetId, request: '../invalid'),
              throwsA(failure('invalid_request_id')),
            );
            final allowed = await create(
              'alice',
              asset.assetId,
              from: reference.add(const Duration(days: 30)).toLocal(),
              until: reference.add(const Duration(days: 37)).toLocal(),
            );
            expect(allowed.activeFrom, reference.add(const Duration(days: 30)));
            expect(
              allowed.activeUntil.difference(allowed.activeFrom),
              const Duration(days: 7),
            );
            expect(await WidgetScheduleRecord.db.count(builder.build()), 1);
            expect(await FutureCallEntry.db.count(builder.build()), 2);
          });
        },
      );

      test(
        'exact payload idempotency survives expiry/cancel; changed bytes of payload conflict',
        () async {
          await pair('alice', 'bob');
          final asset = await photo('alice');
          final request = uuid();
          final original = await withClock(
            Clock.fixed(reference),
            () => create('alice', asset.assetId, request: request),
          );
          await withClock(
            Clock.fixed(reference.add(const Duration(days: 1))),
            () async {
              final retry = await create(
                'alice',
                asset.assetId.toUpperCase(),
                request: request.toUpperCase(),
              );
              expect(retry.scheduleId, original.scheduleId);
              await expectLater(
                create(
                  'alice',
                  asset.assetId,
                  request: request,
                  until: reference.add(
                    const Duration(hours: 1, microseconds: 1),
                  ),
                ),
                throwsA(failure('request_conflict')),
              );
              await expectLater(
                create('alice', asset.assetId),
                throwsA(failure('invalid_window')),
              );
            },
          );
          await endpoints.widgetSchedule.cancelSchedule(
            asUser('bob'),
            original.scheduleId,
          );
          await endpoints.widgetSchedule.cancelSchedule(
            asUser('alice'),
            original.scheduleId,
          );
          final retry = await create('alice', asset.assetId, request: request);
          expect(retry.scheduleId, original.scheduleId);
          expect(
            (await endpoints.widgetSchedule.currentTimeline(
              asUser('bob'),
            )).schedules,
            isEmpty,
          );
          expect(await WidgetScheduleRecord.db.count(builder.build()), 1);
          expect(await FutureCallEntry.db.count(builder.build()), 2);
        },
      );

      test(
        'shared resolver newest overlap, equal-time ID tie, then older/fallback transitions',
        () async {
          await pair('alice', 'bob');
          final fallback = await photo('bob');
          final oldPhoto = await photo('alice', 11);
          final newPhoto = await photo('alice', 12);
          await endpoints.widgetSchedule.setFallback(
            asUser('bob'),
            fallback.assetId,
          );
          await withClock(
            Clock.fixed(reference),
            () => create(
              'alice',
              oldPhoto.assetId,
              until: reference.add(const Duration(hours: 3)),
            ),
          );
          final newest = await withClock(
            Clock.fixed(reference.add(const Duration(minutes: 1))),
            () => create(
              'alice',
              newPhoto.assetId,
              until: reference.add(const Duration(hours: 2)),
            ),
          );
          await withClock(
            Clock.fixed(reference.add(const Duration(hours: 1))),
            () async {
              final timeline = await endpoints.widgetSchedule.currentTimeline(
                asUser('bob'),
              );
              expect(timeline.currentAssetId, newPhoto.assetId);
              expect(timeline.nextTransition, newest.activeUntil);
            },
          );
          await withClock(Clock.fixed(newest.activeUntil), () async {
            final timeline = await endpoints.widgetSchedule.currentTimeline(
              asUser('bob'),
            );
            expect(timeline.currentAssetId, oldPhoto.assetId);
            expect(
              timeline.nextTransition,
              reference.add(const Duration(hours: 3)),
            );
          });
          await withClock(
            Clock.fixed(reference.add(const Duration(hours: 3))),
            () async {
              final timeline = await endpoints.widgetSchedule.currentTimeline(
                asUser('bob'),
              );
              expect(timeline.currentAssetId, fallback.assetId);
              expect(timeline.nextTransition, isNull);
            },
          );
          final equalTime = reference.add(const Duration(days: 1));
          final tied = await withClock(
            Clock.fixed(equalTime),
            () async => [
              await create(
                'alice',
                oldPhoto.assetId,
                from: equalTime,
                until: equalTime.add(const Duration(hours: 1)),
              ),
              await create(
                'alice',
                newPhoto.assetId,
                from: equalTime,
                until: equalTime.add(const Duration(hours: 1)),
              ),
            ],
          );
          tied.sort((a, b) => a.scheduleId.compareTo(b.scheduleId));
          final timeline = await withClock(
            Clock.fixed(equalTime),
            () => endpoints.widgetSchedule.currentTimeline(asUser('bob')),
          );
          expect(timeline.currentAssetId, tied.last.assetId);
          expect(
            timeline.schedules.map((s) => s.scheduleId),
            tied.map((s) => s.scheduleId),
          );
        },
      );

      test(
        'either sender or recipient can cancel active schedules and restore fallback',
        () async {
          await pair('alice', 'bob');
          final fallback = await photo('bob');
          final surprise = await photo('alice', 11);
          await withClock(Clock.fixed(reference), () async {
            await endpoints.widgetSchedule.setFallback(
              asUser('bob'),
              fallback.assetId,
            );
            for (final canceller in ['alice', 'bob']) {
              final request = uuid();
              final entry = await create(
                'alice',
                surprise.assetId,
                request: request,
              );
              expect(
                (await endpoints.widgetSchedule.currentTimeline(
                  asUser('bob'),
                )).currentAssetId,
                surprise.assetId,
              );
              await endpoints.widgetSchedule.cancelSchedule(
                asUser(canceller),
                entry.scheduleId,
              );
              final timeline = await endpoints.widgetSchedule.currentTimeline(
                asUser('bob'),
              );
              expect(timeline.currentAssetId, fallback.assetId);
              expect(timeline.schedules, isEmpty);
              expect(timeline.nextTransition, isNull);
              expect(
                (await create(
                  'alice',
                  surprise.assetId,
                  request: request,
                )).scheduleId,
                entry.scheduleId,
              );
              expect(
                (await endpoints.widgetSchedule.currentTimeline(
                  asUser('bob'),
                )).schedules,
                isEmpty,
              );
            }
          });
        },
      );

      test(
        'same-DB multi-session concurrency atomically deduplicates and enforces quota',
        () async {
          await pair('alice', 'bob');
          final asset = await photo('alice');
          await withClock(Clock.fixed(reference), () async {
            final request = uuid();
            final duplicated = await Future.wait(
              List.generate(
                8,
                (_) => create('alice', asset.assetId, request: request),
              ),
            );
            expect(duplicated.map((e) => e.scheduleId).toSet(), hasLength(1));
            expect(await FutureCallEntry.db.count(builder.build()), 2);
            for (var i = 1; i < 99; i++) {
              await create('alice', asset.assetId);
            }
            Future<Object> contender(String user) async {
              try {
                return await create(user, asset.assetId);
              } on ScheduleFailure catch (e) {
                return e;
              }
            }

            final racers = await Future.wait(
              List.generate(8, (i) => contender(i.isEven ? 'alice' : 'bob')),
            );
            expect(racers.whereType<WidgetScheduleEntry>(), hasLength(1));
            expect(
              racers.whereType<ScheduleFailure>().map((e) => e.code),
              everyElement('quota_exceeded'),
            );
            expect(await WidgetScheduleRecord.db.count(builder.build()), 100);
            expect(await FutureCallEntry.db.count(builder.build()), 200);
            expect(
              (await create(
                'alice',
                asset.assetId,
                request: request,
              )).scheduleId,
              duplicated.first.scheduleId,
            );
            await endpoints.widgetSchedule.cancelSchedule(
              asUser('bob'),
              duplicated.first.scheduleId,
            );
            await create('bob', asset.assetId);
            expect(await WidgetScheduleRecord.db.count(builder.build()), 101);
          });
        },
      );

      test(
        'disabled durable wakes preserve atomic create, idempotency, cancellation and privacy',
        () async {
          await pair('alice', 'bob');
          await pair('charlie', 'dave');
          final asset = await photo('alice');
          final foreignAsset = await photo('charlie');
          final session = builder.build();
          final service = WidgetTimelineService(
            policy: const WidgetSchedulePolicy(futureCallsEnabled: false),
          );
          // A failing INSERT trigger proves disabled mode never even attempts
          // a durable wake write, rather than inserting and cleaning it up.
          await session.db.unsafeSimpleExecute(
            r"CREATE FUNCTION closecall_reject_disabled_wake() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'unexpected disabled wake'; END; $$;",
          );
          await session.db.unsafeExecute(
            'CREATE TRIGGER closecall_reject_disabled_wake BEFORE INSERT ON serverpod_future_call '
            'FOR EACH ROW EXECUTE FUNCTION closecall_reject_disabled_wake()',
          );
          final request = uuid();
          Future<WidgetScheduleEntry> disabledCreate({
            String? user,
            String? id,
            String? requestId,
            DateTime? until,
          }) => service.create(
            session,
            user ?? 'alice',
            id ?? asset.assetId,
            reference,
            until ?? reference.add(const Duration(hours: 1)),
            requestId ?? request,
          );
          try {
            await withClock(Clock.fixed(reference), () async {
              final entries = await Future.wait(
                List.generate(8, (_) => disabledCreate()),
              );
              final original = entries.first;
              expect(entries.map((e) => e.scheduleId).toSet(), hasLength(1));
              expect(await WidgetScheduleRecord.db.count(session), 1);
              expect(await FutureCallEntry.db.count(session), 0);
              expect(
                (await service.timeline(session, 'bob')).currentAssetId,
                asset.assetId,
              );
              expect(
                (await service.timeline(session, 'charlie')).schedules,
                isEmpty,
              );
              await expectLater(
                disabledCreate(
                  until: reference.add(
                    const Duration(hours: 1, microseconds: 1),
                  ),
                ),
                throwsA(failure('request_conflict')),
              );
              for (final id in [foreignAsset.assetId, uuid(), 'bad']) {
                await expectLater(
                  disabledCreate(id: id, requestId: uuid()),
                  throwsA(failure('asset_not_found')),
                );
              }
              await expectLater(
                disabledCreate(user: 'stranger', requestId: uuid()),
                throwsA(failure('not_paired')),
              );
              for (final id in [original.scheduleId, uuid(), 'bad']) {
                await expectLater(
                  service.cancel(session, 'charlie', id),
                  throwsA(failure('schedule_not_found')),
                );
              }
              await service.cancel(session, 'bob', original.scheduleId);
              await service.cancel(session, 'alice', original.scheduleId);
              expect((await disabledCreate()).scheduleId, original.scheduleId);
              expect(
                (await service.timeline(session, 'bob')).schedules,
                isEmpty,
              );
              await withClock(
                Clock.fixed(reference.add(const Duration(days: 1))),
                () async {
                  expect(
                    (await disabledCreate()).scheduleId,
                    original.scheduleId,
                  );
                  await expectLater(
                    disabledCreate(requestId: uuid()),
                    throwsA(failure('invalid_window')),
                  );
                },
              );
              expect(await WidgetScheduleRecord.db.count(session), 1);
              expect(await FutureCallEntry.db.count(session), 0);
            });
          } finally {
            await session.db.unsafeExecute(
              'DROP TRIGGER closecall_reject_disabled_wake ON serverpod_future_call',
            );
            await session.db.unsafeExecute(
              'DROP FUNCTION closecall_reject_disabled_wake()',
            );
          }
        },
      );

      test(
        'future call write failure rolls back schedule plus earlier wake atomically',
        () async {
          await pair('alice', 'bob');
          final asset = await photo('alice');
          final session = builder.build();
          await session.db.unsafeSimpleExecute(
            r"CREATE FUNCTION closecall_fail_end() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.identifier LIKE '%/end' THEN RAISE EXCEPTION 'test wake failure'; END IF; RETURN NEW; END; $$;",
          );
          await session.db.unsafeExecute(
            'CREATE TRIGGER closecall_fail_end BEFORE INSERT ON serverpod_future_call '
            'FOR EACH ROW EXECUTE FUNCTION closecall_fail_end()',
          );
          final request = uuid();
          try {
            await withClock(
              Clock.fixed(reference),
              () => expectLater(
                create('alice', asset.assetId, request: request),
                throwsA(isA<DatabaseException>()),
              ),
            );
            expect(await WidgetScheduleRecord.db.count(session), 0);
            expect(await FutureCallEntry.db.count(session), 0);
          } finally {
            await session.db.unsafeExecute(
              'DROP TRIGGER closecall_fail_end ON serverpod_future_call',
            );
            await session.db.unsafeExecute(
              'DROP FUNCTION closecall_fail_end()',
            );
          }
          await withClock(
            Clock.fixed(reference),
            () => create('alice', asset.assetId, request: request),
          );
          expect(await FutureCallEntry.db.count(session), 2);
        },
      );

      test(
        'typed durable wakes execute via real manager and tolerate cancellation/repetition',
        () async {
          await pair('alice', 'bob');
          final asset = await photo('alice');
          final now = DateTime.now().toUtc();
          final entry = await create(
            'alice',
            asset.assetId,
            from: now.subtract(const Duration(seconds: 1)),
            until: now.add(const Duration(hours: 1)),
          );
          final session = builder.build();
          final wakes = await FutureCallEntry.db.find(session);
          expect(wakes, hasLength(2));
          expect(
            wakes.every((e) => e.name == 'WidgetTimelineWakeFutureCall'),
            isTrue,
          );
          expect(
            wakes.every(
              (e) =>
                  jsonDecode(e.serializedObject!)['scheduleId'] ==
                  entry.scheduleId,
            ),
            isTrue,
          );
          await endpoints.futureCalls.widgetTimeline.wake(
            builder,
            entry.scheduleId,
          );
          expect(
            (await endpoints.widgetSchedule.currentTimeline(
              asUser('bob'),
            )).currentAssetId,
            asset.assetId,
          );
          await endpoints.widgetSchedule.cancelSchedule(
            asUser('bob'),
            entry.scheduleId,
          );
          await endpoints.futureCalls.widgetTimeline.wake(
            builder,
            entry.scheduleId,
          );
          await endpoints.futureCalls.widgetTimeline.wake(
            builder,
            entry.scheduleId,
          );
          await endpoints.futureCalls.widgetTimeline.wake(builder, uuid());
          expect(
            (await endpoints.widgetSchedule.currentTimeline(
              asUser('bob'),
            )).currentAssetId,
            isNull,
          );
          final end = (await FutureCallEntry.db.find(
            session,
          )).singleWhere((e) => e.identifier!.endsWith('/end'));
          end.time = DateTime.now().toUtc().subtract(
            const Duration(seconds: 1),
          );
          await FutureCallEntry.db.updateRow(session, end);
          final notices = StreamIterator(
            session.messages.createStream<TimelineNotice>(
              timelineChannel('bob'),
            ),
          );
          final next = notices.moveNext();
          // runScheduledFutureCalls is the framework's one-shot maintenance runner;
          // drain both durable boundaries in a single invocation.
          await session.serverpod.futureCallManager!.runScheduledFutureCalls();
          expect(await next.timeout(const Duration(seconds: 5)), isTrue);
          expect(notices.current.recipientId, 'bob');
          expect(await FutureCallEntry.db.count(session), 0);
          await notices.cancel();
        },
      );

      for (final futureCallsEnabled in [true, false]) {
        test(
          'watch initial/current isolation, DB-only changes, start/end, membership loss, cancellation (durable wakes: $futureCallsEnabled)',
          () async {
            await pair('alice', 'bob');
            final fallback = await photo('bob');
            final surprise = await photo('alice', 11);
            final otherSession = builder.build();
            final ownSession = asUser('bob').build();
            final service = WidgetTimelineService(
              policy: WidgetSchedulePolicy(
                futureCallsEnabled: futureCallsEnabled,
              ),
            );
            // Direct endpoint stream has the same production lifecycle, permitting
            // explicit cancellation assertions without test transport buffering.
            final iterator = StreamIterator(
              WidgetScheduleEndpoint(
                service: service,
              ).watchTimeline(ownSession),
            );
            expect(
              await iterator.moveNext().timeout(const Duration(seconds: 5)),
              isTrue,
            );
            expect(iterator.current.recipientId, 'bob');
            expect(iterator.current.currentAssetId, isNull);
            var changed = iterator.moveNext();
            final bob = await member('bob');
            await WidgetFallbackRecord.db.insertRow(
              otherSession,
              WidgetFallbackRecord(
                coupleId: bob.coupleId,
                recipientMemberId: bob.id!,
                assetId: UuidValue.fromString(fallback.assetId),
              ),
            ); // No local event.
            expect(await changed.timeout(const Duration(seconds: 5)), isTrue);
            expect(iterator.current.currentAssetId, fallback.assetId);
            final now = DateTime.now().toUtc();
            changed = iterator.moveNext();
            await service.create(
              otherSession,
              'alice',
              surprise.assetId,
              now.add(const Duration(seconds: 2)),
              now.add(const Duration(seconds: 4)),
              uuid(),
            );
            expect(
              await FutureCallEntry.db.count(otherSession),
              futureCallsEnabled ? 2 : 0,
            );
            expect(await changed.timeout(const Duration(seconds: 5)), isTrue);
            expect(iterator.current.currentAssetId, fallback.assetId);
            expect(iterator.current.schedules.single.recipientId, 'bob');
            final senderView = await endpoints.widgetSchedule
                .watchTimeline(asUser('alice'))
                .first;
            expect(senderView.recipientId, 'alice');
            expect(senderView.schedules, isEmpty);
            expect(senderView.currentAssetId, isNull);
            expect(
              await iterator.moveNext().timeout(const Duration(seconds: 5)),
              isTrue,
            );
            expect(iterator.current.currentAssetId, surprise.assetId);
            expect(
              await iterator.moveNext().timeout(const Duration(seconds: 5)),
              isTrue,
            );
            expect(iterator.current.currentAssetId, fallback.assetId);
            expect(iterator.current.schedules, isEmpty);
            changed = iterator.moveNext();
            await CoupleMember.db.deleteRow(otherSession, bob);
            await expectLater(
              changed.timeout(const Duration(seconds: 5)),
              throwsA(failure('not_paired')),
            );
            await iterator.cancel().timeout(const Duration(seconds: 2));
            await ownSession.close();
            // A fresh complete membership can open and immediately cancel a watcher.
            await pair('charlie', 'dave');
            final cancellable = asUser('charlie').build();
            final watch = StreamIterator(
              WidgetScheduleEndpoint().watchTimeline(cancellable),
            );
            await watch.moveNext();
            await watch.cancel().timeout(const Duration(seconds: 2));
            await cancellable.close();
            await otherSession.close();
          },
        );
      }

      test(
        'database FK/check invariants reject cross-couple assets/members and malformed windows',
        () async {
          await pair('alice', 'bob');
          await pair('charlie', 'dave');
          final asset = await photo('alice');
          final other = await photo('charlie');
          final entry = await withClock(
            Clock.fixed(reference),
            () => create('alice', asset.assetId),
          );
          final session = builder.build();
          final row = (await WidgetScheduleRecord.db.findById(
            session,
            UuidValue.fromString(entry.scheduleId),
          ))!;
          final outsider = await member('charlie');
          final denied = throwsA(isA<DatabaseException>());
          for (final changed in [
            row.copyWith(assetId: UuidValue.fromString(other.assetId)),
            row.copyWith(senderMemberId: outsider.id),
            row.copyWith(recipientMemberId: outsider.id),
            row.copyWith(recipientMemberId: row.senderMemberId),
            row.copyWith(activeUntil: row.activeFrom),
            row.copyWith(
              activeUntil: row.activeFrom.add(const Duration(days: 8)),
            ),
          ]) {
            await expectLater(
              WidgetScheduleRecord.db.updateRow(session, changed),
              denied,
            );
          }
          await expectLater(
            WidgetFallbackRecord.db.insertRow(
              session,
              WidgetFallbackRecord(
                coupleId: row.coupleId,
                recipientMemberId: row.recipientMemberId,
                assetId: UuidValue.fromString(other.assetId),
              ),
            ),
            denied,
          );
          await expectLater(
            WidgetFallbackRecord.db.insertRow(
              session,
              WidgetFallbackRecord(
                coupleId: row.coupleId,
                recipientMemberId: outsider.id!,
                assetId: row.assetId,
              ),
            ),
            denied,
          );
          await expectLater(
            WidgetScheduleRecord.db.insertRow(session, row.copyWith(id: null)),
            throwsA(isA<DatabaseUniqueViolationException>()),
          );
        },
      );

      test(
        'old JSON-only incremental schema repairs to latest; SQL/JSON reruns safe and preserve media',
        () async {
          const old = '20261003161232234';
          const repair = '20261004000100000';
          await pair('alice', 'bob');
          final asset = await photo('alice');
          final session = builder.build();
          final oldDir = 'migrations/$old';
          final oldMigration = database.DatabaseMigration.fromJson(
            jsonDecode(File('$oldDir/migration.json').readAsStringSync()),
          );
          final oldDefinition = database.DatabaseDefinition.fromJson(
            jsonDecode(File('$oldDir/definition.json').readAsStringSync()),
          );
          // Inside an ephemeral database only: reproduce the prior scheduling
          // actions on a real pre-scheduling schema, not the happy fresh-install SQL.
          await session.db.unsafeSimpleExecute(
            'DROP TABLE closecall_widget_device_credential; '
            'DROP TABLE closecall_push_outbox; '
            'DROP TABLE closecall_push_device_registration; '
            'DROP TABLE closecall_widget_schedule, closecall_widget_fallback, closecall_widget_delivery, closecall_widget_send; '
            'DROP INDEX IF EXISTS closecall_widget_send_couple_id_unique; '
            'DROP INDEX closecall_member_couple_id_unique; DROP INDEX closecall_media_couple_asset_unique;',
          );
          final generator = PostgresSqlGenerator();
          final originalJsonSql = generator.generateDatabaseMigrationSql(
            oldMigration,
            oldDefinition,
            installedModules: [],
            removedModules: [],
          );
          await session.db.unsafeSimpleExecute(originalJsonSql);
          await session.db.unsafeExecute(
            "UPDATE serverpod_migrations SET version = '$old' WHERE module = 'closecall'",
          );
          final missing = await session.db.unsafeQuery(
            "SELECT conname FROM pg_constraint WHERE conname LIKE 'closecall_widget_%same_couple%'",
          );
          expect(missing, isEmpty);
          final manager = database.MigrationManager.fromDirectory(
            Directory.current,
            runMode: 'test',
          );
          expect(await manager.migrateToLatest(session), [
            repair,
            '20261005132731105',
            '20261005201637360-push-registration',
            '20261006081030595-nicknames',
            '20261006120000000-fcm-outbox',
            '20261006224415374-widget-device-credentials',
            '20261007041835495-live-mood',
          ]);
          expect(
            await database.MigrationManager.verifyDatabaseIntegrity(session),
            isTrue,
          );
          final repairDir = 'migrations/$repair';
          final json = database.DatabaseMigration.fromJson(
            jsonDecode(File('$repairDir/migration.json').readAsStringSync()),
          );
          final definition = database.DatabaseDefinition.fromJson(
            jsonDecode(File('$repairDir/definition.json').readAsStringSync()),
          );
          final rendered = scheduleMigrationSql(json, definition);
          // Pinned CLI has a composite quoting bug: correct it locally instead of
          // corrupting column names in JSON or patching the global tooling cache.
          final upstream = generator.generateDatabaseMigrationSql(
            json,
            definition,
            installedModules: [],
            removedModules: [],
          );
          expect(upstream.contains('FOREIGN KEY("coupleId, assetId")'), isTrue);
          expect(
            rendered.contains('FOREIGN KEY("coupleId", "assetId")'),
            isTrue,
          );
          // JSON actions work both when missing and when already installed.
          for (final action in json.actions) {
            for (final key in action.alterTable!.addForeignKeys) {
              await session.db.unsafeExecute(
                'ALTER TABLE "${action.alterTable!.name}" DROP CONSTRAINT "${key.constraintName}"',
              );
            }
          }
          await session.db.unsafeSimpleExecute(rendered);
          await session.db.unsafeSimpleExecute(rendered);
          await session.db.unsafeSimpleExecute(
            File('$repairDir/migration.sql').readAsStringSync(),
          );
          await session.db.unsafeSimpleExecute(
            File('$repairDir/migration.sql').readAsStringSync(),
          );
          expect(
            await database.MigrationManager.verifyDatabaseIntegrity(session),
            isTrue,
          );
          expect(
            await MediaRecord.db.findById(
              session,
              UuidValue.fromString(asset.assetId),
            ),
            isNotNull,
          );
          final constraints = await session.db.unsafeQuery(
            "SELECT conname FROM pg_constraint WHERE conname LIKE 'closecall_widget_%same_couple%'",
          );
          expect(constraints, hasLength(12));
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
    configOverride: (config) => config.copyWith(
      futureCallExecutionEnabled: false,
      futureCall: const FutureCallConfig(enabled: true),
    ),
    testServerOutputMode: TestServerOutputMode.silent,
  );

  withServerpod(
    'Serverpod future-call feature disabled',
    (builder, endpoints) {
      test(
        'official feature switch prevents wake writes even with enabled policy',
        () async {
          TestSessionBuilder asUser(String id) => builder.copyWith(
            authentication: AuthenticationOverride.authenticationInfo(id, {}),
          );
          final pending = await endpoints.pairing.createCouple(asUser('alice'));
          await endpoints.pairing.joinByCode(
            asUser('bob'),
            pending.pairingCode!,
          );
          final pixels = image.Image(width: 2, height: 2)
            ..setPixelRgb(0, 0, 10, 20, 30);
          final asset = await endpoints.media.uploadPhoto(
            asUser('alice'),
            ByteData.sublistView(image.encodePng(pixels)),
            uuid(),
          );
          final session = builder.build();
          expect(session.serverpod.config.futureCall.enabled, isFalse);
          final now = DateTime.now().toUtc();
          await endpoints.widgetSchedule.createSchedule(
            asUser('alice'),
            asset.assetId,
            now,
            now.add(const Duration(hours: 1)),
            uuid(),
          );
          await WidgetTimelineService(
            policy: const WidgetSchedulePolicy(),
          ).create(
            session,
            'alice',
            asset.assetId,
            now,
            now.add(const Duration(hours: 1)),
            uuid(),
          );
          expect(await WidgetScheduleRecord.db.count(session), 2);
          expect(await FutureCallEntry.db.count(session), 0);
          expect(
            (await endpoints.widgetSchedule.currentTimeline(
              asUser('bob'),
            )).currentAssetId,
            asset.assetId,
          );
          await session.serverpod.storage['private']!.deleteFile(
            session: session,
            path: (await MediaRecord.db.find(session)).single.storagePath,
          );
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
    configOverride: (config) =>
        config.copyWith(futureCall: const FutureCallConfig(enabled: false)),
    testServerOutputMode: TestServerOutputMode.silent,
  );
}
