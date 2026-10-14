import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'moment_event_dispatcher.dart';
import 'wav_validation.dart';

class MomentsEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;
  @override
  bool get logSessions => false;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<MomentEntry> createMoment(
    Session session, {
    required String requestId,
    required String text,
    ByteData? voiceBytes,
  }) async {
    if (!_uuid.hasMatch(requestId)) {
      throw MomentFailure(code: 'invalid_request_id');
    }
    requestId = requestId.toLowerCase();
    // Bound work before Unicode iteration, hashing, or any private storage write.
    if (text.length > 2000 ||
        text.runes.length > 1000 ||
        (voiceBytes == null && text.trim().isEmpty)) {
      throw MomentFailure(code: 'invalid_text');
    }
    final duration = voiceBytes == null ? null : validateMomentWav(voiceBytes);
    final voice = voiceBytes?.buffer.asUint8List(
      voiceBytes.offsetInBytes,
      voiceBytes.lengthInBytes,
    );
    final hash = sha256.convert([
      ...utf8.encode(jsonEncode([text, voiceBytes != null])),
      ...?voice,
    ]).toString();
    final user = session.authenticated!.userIdentifier;
    final result = await _run(session, (transaction) async {
      final member = await _pairedMember(session, transaction);
      final existing = await MomentRecord.db.findFirstRow(
        session,
        where: (t) =>
            t.coupleId.equals(member.coupleId) & t.requestId.equals(requestId),
        transaction: transaction,
      );
      if (existing != null) {
        if (existing.authorId != user || existing.contentHash != hash) {
          throw MomentFailure(code: 'request_conflict');
        }
        if (existing.deletedAt != null) {
          throw MomentFailure(code: 'moment_not_found');
        }
        return _entry(existing);
      }
      final count = await MomentRecord.db.count(
        session,
        where: (t) =>
            t.coupleId.equals(member.coupleId) & t.deletedAt.equals(null),
        transaction: transaction,
      );
      if (count >= 100) throw MomentFailure(code: 'quota_exceeded');
      if (voiceBytes != null &&
          await MomentRecord.db.count(
                session,
                where: (t) =>
                    t.coupleId.equals(member.coupleId) &
                    t.deletedAt.equals(null) &
                    t.kind.equals('voice'),
                transaction: transaction,
              ) >=
              50) {
        throw MomentFailure(code: 'quota_exceeded');
      }
      final path = voiceBytes == null
          ? null
          : 'closecall/moments/${sha256.convert(utf8.encode('${member.coupleId}/$requestId'))}.wav';
      final storage = session.serverpod.storage['private']!;
      try {
        if (path != null) {
          await storage.storeFile(
            session: session,
            path: path,
            byteData: voiceBytes!,
            options: const StoreFileOptions(
              metadata: FileMetadata(contentType: 'audio/wav'),
            ),
          );
        }
        final record = await MomentRecord.db.insertRow(
          session,
          MomentRecord(
            coupleId: member.coupleId,
            authorMemberId: member.id!,
            authorId: user,
            text: text,
            kind: path == null ? 'text' : 'voice',
            durationMs: duration,
            requestId: requestId,
            contentHash: hash,
            storagePath: path,
          ),
          transaction: transaction,
        );
        final members = await CoupleMember.db.find(
          session,
          where: (t) => t.coupleId.equals(member.coupleId),
          transaction: transaction,
        );
        final recipient = members
            .where((candidate) => candidate.id != member.id)
            .single;
        await MomentEventOutbox.db.insertRow(
          session,
          MomentEventOutbox(
            coupleId: member.coupleId,
            momentId: record.id!,
            recipientMemberId: recipient.id!,
            eventType: 'moment_created',
            expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
          ),
          transaction: transaction,
        );
        return _entry(record);
      } catch (_) {
        if (path != null) {
          try {
            await storage.deleteFile(session: session, path: path);
          } catch (_) {
            // A retry overwrites this deterministic orphan; do not log its path.
          }
        }
        throw MomentFailure(code: 'moment_unavailable');
      }
      // Never clean up on ambiguous COMMIT: stable retry discovers the row.
    });
    // The durable row is authoritative; this is only a bounded wake-up. A
    // duplicate request finds the existing Moment and cannot create another
    // event because insertion happens only on the first transaction.
    unawaited(MomentEventOutboxRuntime.kick(session.serverpod));
    return result;
  }

  Future<List<MomentEntry>> listMoments(
    Session session, {
    String? beforeId,
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 100) throw MomentFailure(code: 'invalid_request');
    return _run(session, (transaction) async {
      final member = await _pairedMember(session, transaction);
      final before = beforeId == null
          ? null
          : await _record(
              session,
              beforeId,
              member.coupleId,
              transaction,
              includeDeleted: true,
            );
      final rows = await session.db.unsafeQuery(
        'SELECT id::text FROM closecall_moment WHERE "coupleId" = CAST(@couple AS uuid) '
        'AND "deletedAt" IS NULL '
        '${before == null ? '' : 'AND ("createdAt", id) < (CAST(@at AS timestamp without time zone), CAST(@id AS uuid)) '}'
        'ORDER BY "createdAt" DESC, id DESC LIMIT @limit',
        parameters: QueryParameters.named({
          'couple': member.coupleId.toString(),
          'limit': limit,
          if (before != null) 'at': before.createdAt.toIso8601String(),
          if (before != null) 'id': before.id.toString(),
        }),
        transaction: transaction,
      );
      final entries = <MomentEntry>[];
      for (final row in rows) {
        entries.add(
          _entry(
            (await MomentRecord.db.findById(
              session,
              UuidValue.fromString(row.first as String),
              transaction: transaction,
            ))!,
          ),
        );
      }
      return entries;
    });
  }

  Future<ByteData> downloadVoice(Session session, {required String momentId}) =>
      _run(session, (transaction) async {
        final member = await _pairedMember(
          session,
          transaction,
          concealed: true,
        );
        final record = await _record(
          session,
          momentId,
          member.coupleId,
          transaction,
        );
        if (record.kind != 'voice' || record.storagePath == null) {
          throw MomentFailure(code: 'moment_not_found');
        }
        try {
          return await session.serverpod.storage['private']!.retrieveFile(
            session: session,
            path: record.storagePath!,
          );
        } catch (_) {
          throw MomentFailure(code: 'moment_not_found');
        }
      });

  Future<void> deleteMoment(
    Session session, {
    required String momentId,
  }) => _run(session, (transaction) async {
    final member = await _pairedMember(session, transaction, concealed: true);
    final record = await _record(
      session,
      momentId,
      member.coupleId,
      transaction,
      includeDeleted: true,
    );
    if (record.authorId != session.authenticated!.userIdentifier) {
      throw MomentFailure(code: 'moment_not_found');
    }
    if (record.deletedAt != null) return;
    if (record.storagePath != null) {
      try {
        await session.serverpod.storage['private']!.deleteFile(
          session: session,
          path: record.storagePath!,
        );
      } catch (_) {
        throw MomentFailure(code: 'moment_unavailable');
      }
    }
    // Tombstone preserves request idempotency after deletion, without text/path.
    record.deletedAt = DateTime.now().toUtc();
    record.text = '';
    record.storagePath = null;
    await MomentRecord.db.updateRow(session, record, transaction: transaction);
  });

  Future<CoupleMember> _pairedMember(
    Session session,
    Transaction transaction, {
    bool concealed = false,
  }) async {
    final user = session.authenticated!.userIdentifier;
    final failure = concealed ? 'moment_not_found' : 'not_paired';
    await session.db.unsafeQuery(
      'SELECT pg_advisory_xact_lock(hashtextextended(@identity, 0))',
      parameters: QueryParameters.named({
        'identity': 'closecall/pairing/$user',
      }),
      transaction: transaction,
    );
    final member = await CoupleMember.db.findFirstRow(
      session,
      where: (t) => t.userIdentifier.equals(user),
      transaction: transaction,
    );
    if (member == null) throw MomentFailure(code: failure);
    // Same lock order as pairing. Couple row serializes quotas, creates, reads,
    // deletes and storage operations across processes. Member locks prevent
    // revocation during an authorized private read/write.
    final couples = await session.db.unsafeQuery(
      'SELECT id FROM closecall_couple WHERE id = CAST(@id AS uuid) AND "pairingCode" IS NULL FOR UPDATE',
      parameters: QueryParameters.named({'id': member.coupleId.toString()}),
      transaction: transaction,
    );
    final members = await session.db.unsafeQuery(
      'SELECT "userIdentifier" FROM closecall_couple_member WHERE "coupleId" = CAST(@id AS uuid) FOR SHARE',
      parameters: QueryParameters.named({'id': member.coupleId.toString()}),
      transaction: transaction,
    );
    if (couples.isEmpty ||
        members.length != 2 ||
        !members.any((row) => row.first == user)) {
      throw MomentFailure(code: failure);
    }
    return member;
  }

  Future<MomentRecord> _record(
    Session session,
    String id,
    UuidValue coupleId,
    Transaction transaction, {
    bool includeDeleted = false,
  }) async {
    if (!_uuid.hasMatch(id)) throw MomentFailure(code: 'moment_not_found');
    final row = await MomentRecord.db.findFirstRow(
      session,
      where: (t) =>
          t.id.equals(UuidValue.fromString(id)) & t.coupleId.equals(coupleId),
      transaction: transaction,
    );
    if (row == null || (!includeDeleted && row.deletedAt != null)) {
      throw MomentFailure(code: 'moment_not_found');
    }
    return row;
  }

  MomentEntry _entry(MomentRecord row) => MomentEntry(
    momentId: row.id!.toString(),
    coupleId: row.coupleId.toString(),
    authorId: row.authorId,
    text: row.text,
    kind: row.kind,
    durationMs: row.durationMs,
    createdAt: row.createdAt,
  );

  Future<T> _run<T>(
    Session session,
    Future<T> Function(Transaction) action,
  ) async {
    try {
      return await session.db.transaction(action);
    } on MomentFailure {
      rethrow;
    } catch (_) {
      // Storage/database failures never expose private paths, SQL, or payloads.
      throw MomentFailure(code: 'moment_unavailable');
    }
  }
}
