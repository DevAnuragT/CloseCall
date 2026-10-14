import 'dart:async';
import 'dart:typed_data';

import 'package:closecall_server/src/generated/protocol.dart';
import 'package:closecall_server/src/moments/moments_endpoint.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/moment_wav.dart';
import 'test_tools/serverpod_test_tools.dart';

Matcher failure(String code) =>
    isA<MomentFailure>().having((e) => e.code, 'code', code);

void main() {
  withServerpod(
    'Private text and voice Moments',
    (builder, endpoints) {
      TestSessionBuilder asUser(String id) => builder.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(id, {}),
      );
      String request() => Uuid().v4();
      Future<PairingState> pair([String a = 'alice', String b = 'bob']) async {
        final pending = await endpoints.pairing.createCouple(asUser(a));
        return endpoints.pairing.joinByCode(asUser(b), pending.pairingCode!);
      }

      Future<MomentEntry> create({
        String user = 'alice',
        String? id,
        String text = 'A private memory',
        ByteData? voice,
      }) => endpoints.moments.createMoment(
        asUser(user),
        requestId: id ?? request(),
        text: text,
        voiceBytes: voice,
      );

      setUp(() async {
        final session = builder.build();
        for (final row in await MomentRecord.db.find(session)) {
          if (row.storagePath != null) {
            await session.serverpod.storage['private']!.deleteFile(
              session: session,
              path: row.storagePath!,
            );
          }
        }
        await Couple.db.deleteWhere(session, where: (_) => Constant.bool(true));
      });

      test(
        'all RPCs require authentication and private payload session logs are disabled',
        () async {
          expect(MomentsEndpoint().logSessions, isFalse);
          final unauthenticated = throwsA(
            isA<ServerpodUnauthenticatedException>(),
          );
          await expectLater(
            endpoints.moments.createMoment(
              builder,
              requestId: request(),
              text: 'hi',
            ),
            unauthenticated,
          );
          await expectLater(
            endpoints.moments.listMoments(builder),
            unauthenticated,
          );
          await expectLater(
            endpoints.moments.downloadVoice(builder, momentId: request()),
            unauthenticated,
          );
          await expectLater(
            endpoints.moments.deleteMoment(builder, momentId: request()),
            unauthenticated,
          );
        },
      );

      test(
        'complete pairing is mandatory; resource operations conceal lack of membership',
        () async {
          await endpoints.pairing.createCouple(asUser('owner'));
          for (final user in ['stranger', 'owner']) {
            await expectLater(
              create(user: user),
              throwsA(failure('not_paired')),
            );
            await expectLater(
              endpoints.moments.listMoments(asUser(user)),
              throwsA(failure('not_paired')),
            );
            await expectLater(
              endpoints.moments.downloadVoice(
                asUser(user),
                momentId: request(),
              ),
              throwsA(failure('moment_not_found')),
            );
            await expectLater(
              endpoints.moments.deleteMoment(asUser(user), momentId: request()),
              throwsA(failure('moment_not_found')),
            );
          }
        },
      );

      test(
        'text/voice share authoritative DTOs with derived duration and exact private bytes',
        () async {
          final paired = await pair();
          final text = await create();
          expect(text.kind, 'text');
          expect(text.durationMs, isNull);
          final wav = momentWav(frames: 16001, sample: 42);
          final voice = await create(user: 'bob', text: '', voice: wav);
          expect(voice.kind, 'voice');
          expect(voice.durationMs, 1001);
          expect(voice.authorId, 'bob');
          expect(voice.coupleId, paired.coupleId);
          expect(voice.createdAt.isUtc, isTrue);
          expect(
            voice.toJson().keys.where((k) => k != '__className__').toSet(),
            {
              'momentId',
              'coupleId',
              'authorId',
              'text',
              'kind',
              'durationMs',
              'createdAt',
            },
          );
          for (final user in ['alice', 'bob']) {
            expect(
              (await endpoints.moments.listMoments(
                asUser(user),
              )).map((r) => r.momentId),
              [voice.momentId, text.momentId],
            );
            final bytes = await endpoints.moments.downloadVoice(
              asUser(user),
              momentId: voice.momentId,
            );
            expect(momentBytes(bytes), momentBytes(wav));
          }
          final session = builder.build();
          final row = (await MomentRecord.db.find(
            session,
            where: (t) => t.kind.equals('voice'),
          )).single;
          await expectLater(
            session.serverpod.storage['private']!.publicDownloadUrl(
              session: session,
              path: row.storagePath!,
            ),
            throwsA(isA<CloudStorageUnsupportedOperationException>()),
          );
          await expectLater(
            endpoints.moments.downloadVoice(
              asUser('alice'),
              momentId: text.momentId,
            ),
            throwsA(failure('moment_not_found')),
          );
        },
      );

      test(
        'same request is serialized/idempotent; changes or another author conflict; deleted retries never resurrect',
        () async {
          await pair();
          final id = request();
          final voice = momentWav();
          final rows = await Future.wait(
            List.generate(8, (_) => create(id: id, voice: voice)),
          );
          expect(rows.map((r) => r.momentId).toSet(), hasLength(1));
          expect(await MomentRecord.db.count(builder.build()), 1);
          expect(
            (await create(id: id.toUpperCase(), voice: voice)).momentId,
            rows.first.momentId,
          );
          final session = builder.build();
          final privatePath = (await MomentRecord.db.find(
            session,
          )).single.storagePath!;
          for (final changed in [
            () => create(id: id, text: 'changed', voice: voice),
            () => create(id: id, voice: momentWav(sample: 1)),
            () => create(id: id),
            () => create(id: id, user: 'bob', voice: voice),
          ]) {
            await expectLater(changed(), throwsA(failure('request_conflict')));
          }
          await endpoints.moments.deleteMoment(
            asUser('alice'),
            momentId: rows.first.momentId,
          );
          expect(
            await session.serverpod.storage['private']!.fileExists(
              session: session,
              path: privatePath,
            ),
            isFalse,
          );
          await expectLater(
            endpoints.moments.downloadVoice(
              asUser('bob'),
              momentId: rows.first.momentId,
            ),
            throwsA(failure('moment_not_found')),
          );
          await expectLater(
            create(id: id, voice: voice),
            throwsA(failure('moment_not_found')),
          );
          expect(await endpoints.moments.listMoments(asUser('bob')), isEmpty);
          final tombstone = (await MomentRecord.db.find(
            builder.build(),
          )).single;
          expect(tombstone.text, isEmpty);
          expect(tombstone.storagePath, isNull);
          await pair('charlie', 'dave');
          expect(
            (await create(user: 'charlie', id: id)).momentId,
            isNot(rows.first.momentId),
          );
        },
      );

      test(
        'keyset newest-first pages use UUID tie-breakers, support deleted cursor and reject foreign cursors',
        () async {
          await pair();
          final entries = <MomentEntry>[];
          for (var i = 0; i < 7; i++) {
            entries.add(await create(text: '$i'));
          }
          final session = builder.build();
          final at = DateTime.utc(2026, 10, 10);
          for (final row in await MomentRecord.db.find(session)) {
            row.createdAt = at;
            await MomentRecord.db.updateRow(session, row);
          }
          final expected = entries.map((r) => r.momentId).toList()
            ..sort((a, b) => b.compareTo(a));
          final first = await endpoints.moments.listMoments(
            asUser('alice'),
            limit: 3,
          );
          expect(first.map((r) => r.momentId), expected.take(3));
          await endpoints.moments.deleteMoment(
            asUser('alice'),
            momentId: first.last.momentId,
          );
          final second = await endpoints.moments.listMoments(
            asUser('bob'),
            beforeId: first.last.momentId,
            limit: 3,
          );
          final third = await endpoints.moments.listMoments(
            asUser('alice'),
            beforeId: second.last.momentId,
            limit: 3,
          );
          expect(
            [...first, ...second, ...third].map((r) => r.momentId),
            expected,
          );
          // A later insertion does not shift the cursor or create offset duplicates.
          await create(text: 'new');
          expect(
            (await endpoints.moments.listMoments(
              asUser('alice'),
              beforeId: second.last.momentId,
            )).single.momentId,
            third.single.momentId,
          );
          await pair('charlie', 'dave');
          final other = await create(user: 'charlie');
          for (final id in [other.momentId, request(), '../private']) {
            await expectLater(
              endpoints.moments.listMoments(asUser('alice'), beforeId: id),
              throwsA(failure('moment_not_found')),
            );
          }
          for (final limit in [0, -1, 101]) {
            await expectLater(
              endpoints.moments.listMoments(asUser('alice'), limit: limit),
              throwsA(failure('invalid_request')),
            );
          }
        },
      );

      test(
        'cross-couple access and partner deletion are concealed; revocation checked on every operation',
        () async {
          await pair();
          await pair('charlie', 'dave');
          final voice = await create(voice: momentWav());
          for (final user in ['stranger', 'charlie', 'dave']) {
            for (final id in [voice.momentId, request(), 'bad-id']) {
              await expectLater(
                endpoints.moments.downloadVoice(asUser(user), momentId: id),
                throwsA(failure('moment_not_found')),
              );
              await expectLater(
                endpoints.moments.deleteMoment(asUser(user), momentId: id),
                throwsA(failure('moment_not_found')),
              );
            }
          }
          await expectLater(
            endpoints.moments.deleteMoment(
              asUser('bob'),
              momentId: voice.momentId,
            ),
            throwsA(failure('moment_not_found')),
          );
          final session = builder.build();
          await CoupleMember.db.deleteWhere(
            session,
            where: (t) => t.userIdentifier.equals('bob'),
          );
          for (final user in ['alice', 'bob']) {
            await expectLater(
              endpoints.moments.downloadVoice(
                asUser(user),
                momentId: voice.momentId,
              ),
              throwsA(failure('moment_not_found')),
            );
            await expectLater(
              endpoints.moments.deleteMoment(
                asUser(user),
                momentId: voice.momentId,
              ),
              throwsA(failure('moment_not_found')),
            );
            await expectLater(
              create(user: user),
              throwsA(failure('not_paired')),
            );
          }
        },
      );

      test(
        'validation rejects empty/oversized text and actual invalid voice before storage',
        () async {
          await pair();
          await expectLater(
            create(id: '../bad'),
            throwsA(failure('invalid_request_id')),
          );
          for (final text in ['', ' \n ', 'x' * 1001, '😀' * 1001]) {
            await expectLater(
              create(text: text),
              throwsA(failure('invalid_text')),
            );
          }
          for (final bad in [
            ByteData(10),
            ByteData(100),
            momentWav(frames: 0),
            momentWav(frames: 480001),
          ]) {
            await expectLater(
              create(voice: bad),
              throwsA(failure('invalid_voice')),
            );
          }
          await expectLater(
            create(voice: ByteData(1024 * 1024 + 1)),
            throwsA(failure('file_too_large')),
          );
          expect(await MomentRecord.db.count(builder.build()), 0);
          await create(text: '😀' * 1000);
          await create(text: '', voice: momentWav(frames: 480000));
        },
      );

      test(
        '100 Moments/50 voices quotas serialize both authors; retries and deletion free capacity',
        () async {
          await pair();
          final stable = request();
          final first = await create(id: stable, voice: momentWav());
          for (var i = 1; i < 49; i++) {
            await create(voice: momentWav());
          }
          Future<Object> attempt(int i, {bool voice = true}) async {
            try {
              return await create(
                user: i.isEven ? 'alice' : 'bob',
                voice: voice ? momentWav() : null,
              );
            } on MomentFailure catch (e) {
              return e;
            }
          }

          final voices = await Future.wait(List.generate(8, (i) => attempt(i)));
          expect(voices.whereType<MomentEntry>(), hasLength(1));
          expect(
            voices.whereType<MomentFailure>().map((e) => e.code),
            everyElement('quota_exceeded'),
          );
          for (var i = 0; i < 49; i++) {
            await create();
          }
          final texts = await Future.wait(
            List.generate(8, (i) => attempt(i, voice: false)),
          );
          expect(texts.whereType<MomentEntry>(), hasLength(1));
          expect(
            texts.whereType<MomentFailure>().map((e) => e.code),
            everyElement('quota_exceeded'),
          );
          expect(
            (await endpoints.moments.listMoments(asUser('bob'), limit: 100)),
            hasLength(100),
          );
          expect(
            (await create(id: stable, voice: momentWav())).momentId,
            first.momentId,
          );
          await endpoints.moments.deleteMoment(
            asUser('alice'),
            momentId: first.momentId,
          );
          await endpoints.moments.deleteMoment(
            asUser('alice'),
            momentId: first.momentId,
          );
          await create(voice: momentWav());
          expect(
            await MomentRecord.db.count(
              builder.build(),
              where: (t) => t.deletedAt.equals(null),
            ),
            100,
          );
        },
      );

      test(
        'DB enforces unique requests, valid rows and same-couple authors',
        () async {
          await pair();
          await pair('charlie', 'dave');
          await create();
          final session = builder.build();
          final row = (await MomentRecord.db.find(session)).single;
          await expectLater(
            MomentRecord.db.insertRow(session, row.copyWith(id: null)),
            throwsA(isA<DatabaseUniqueViolationException>()),
          );
          final outsider = (await CoupleMember.db.find(
            session,
            where: (t) => t.userIdentifier.equals('charlie'),
          )).single;
          for (final changed in [
            row.copyWith(authorMemberId: outsider.id),
            row.copyWith(text: ''),
            row.copyWith(kind: 'public'),
            row.copyWith(text: 'x' * 1001),
          ]) {
            await expectLater(
              MomentRecord.db.updateRow(session, changed),
              throwsA(isA<DatabaseException>()),
            );
          }
        },
      );

      test(
        'partial private write failure is cleaned and safely retried without exposing failure details',
        () async {
          await pair();
          final pod = builder.build().serverpod;
          final original = pod.storage['private']!;
          final failing = _FailAfterWrite(original);
          final id = request();
          pod.addCloudStorage(failing);
          try {
            await expectLater(
              create(id: id, voice: momentWav()),
              throwsA(failure('moment_unavailable')),
            );
            expect(failing.cleaned, isTrue);
            expect(await MomentRecord.db.count(builder.build()), 0);
          } finally {
            pod.addCloudStorage(original);
          }
          await create(id: id, voice: momentWav());
        },
      );

      test(
        'membership cannot be revoked midway through private download',
        () async {
          await pair();
          final voice = await create(voice: momentWav());
          final session = builder.build();
          final pod = session.serverpod;
          final original = pod.storage['private']!;
          final blocking = _BlockingRead(original);
          pod.addCloudStorage(blocking);
          final download = endpoints.moments.downloadVoice(
            asUser('bob'),
            momentId: voice.momentId,
          );
          await blocking.entered.future;
          var revoked = false;
          final revoke = CoupleMember.db
              .deleteWhere(
                session,
                where: (t) => t.userIdentifier.equals('bob'),
              )
              .then((_) => revoked = true);
          try {
            await Future<void>.delayed(const Duration(milliseconds: 75));
            expect(revoked, isFalse);
            blocking.release.complete();
            expect(momentBytes(await download), momentBytes(momentWav()));
            await revoke;
            await expectLater(
              endpoints.moments.downloadVoice(
                asUser('alice'),
                momentId: voice.momentId,
              ),
              throwsA(failure('moment_not_found')),
            );
          } finally {
            if (!blocking.release.isCompleted) blocking.release.complete();
            pod.addCloudStorage(original);
          }
        },
      );

      test(
        'metadata failure cleans private write and generic retry succeeds',
        () async {
          await pair();
          final session = builder.build();
          await session.db.unsafeQuery(
            'CREATE FUNCTION closecall_test_fail_moment() RETURNS trigger LANGUAGE plpgsql AS '
            r"'BEGIN RAISE EXCEPTION ''private metadata error''; END;'",
          );
          await session.db.unsafeQuery(
            'CREATE TRIGGER closecall_test_fail_moment BEFORE INSERT ON closecall_moment '
            'FOR EACH ROW EXECUTE FUNCTION closecall_test_fail_moment()',
          );
          final id = request();
          final pod = session.serverpod;
          final original = pod.storage['private']!;
          final tracker = _CleanupTracker(original);
          pod.addCloudStorage(tracker);
          try {
            await expectLater(
              create(id: id, voice: momentWav()),
              throwsA(failure('moment_unavailable')),
            );
            expect(tracker.cleaned, isTrue);
            expect(await MomentRecord.db.count(session), 0);
          } finally {
            pod.addCloudStorage(original);
            await session.db.unsafeQuery(
              'DROP TRIGGER closecall_test_fail_moment ON closecall_moment',
            );
            await session.db.unsafeQuery(
              'DROP FUNCTION closecall_test_fail_moment()',
            );
          }
          final entry = await create(id: id, voice: momentWav());
          final row = (await MomentRecord.db.find(session)).single;
          await original.deleteFile(session: session, path: row.storagePath!);
          await expectLater(
            endpoints.moments.downloadVoice(
              asUser('bob'),
              momentId: entry.momentId,
            ),
            throwsA(failure('moment_not_found')),
          );
          await endpoints.moments.deleteMoment(
            asUser('alice'),
            momentId: entry.momentId,
          );
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
    ephemeralDatabase: true,
    testServerOutputMode: TestServerOutputMode.silent,
  );
}

class _FailAfterWrite extends CloudStorage {
  _FailAfterWrite(this.delegate) : super('private');
  final CloudStorage delegate;
  bool cleaned = false;
  @override
  Future<void> storeFile({
    required Session session,
    required String path,
    required ByteData byteData,
    StoreFileOptions options = const StoreFileOptions(),
  }) async {
    await delegate.storeFile(
      session: session,
      path: path,
      byteData: byteData,
      options: options,
    );
    throw StateError('private path and payload must not escape');
  }

  @override
  Future<void> deleteFile({
    required Session session,
    required String path,
  }) async {
    await delegate.deleteFile(session: session, path: path);
    cleaned = !await delegate.fileExists(session: session, path: path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unused test storage method');
}

class _CleanupTracker extends _FailAfterWrite {
  _CleanupTracker(super.delegate);
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
}

class _BlockingRead extends CloudStorage {
  _BlockingRead(this.delegate) : super('private');
  final CloudStorage delegate;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<ByteData> retrieveFile({
    required Session session,
    required String path,
  }) async {
    entered.complete();
    await release.future;
    return delegate.retrieveFile(session: session, path: path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unused test storage method');
}
