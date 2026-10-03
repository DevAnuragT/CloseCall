import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'png_validation.dart';

class MediaEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<MediaAsset> uploadPhoto(
    Session session,
    ByteData pngBytes,
    String requestId,
  ) async {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(requestId)) {
      throw MediaFailure(code: 'invalid_request_id');
    }
    requestId = requestId.toLowerCase();
    final user = session.authenticated!.userIdentifier;
    return session.db.transaction((transaction) async {
      final coupleId = await _currentCouple(session, user, transaction);
      if (coupleId == null) throw MediaFailure(code: 'not_paired');
      // One PostgreSQL transaction-scoped lock serializes quota and request
      // checks across processes, not just within this server's Dart isolate.
      await session.db.unsafeQuery(
        'SELECT pg_advisory_xact_lock(hashtextextended(@identity, 0))',
        parameters: QueryParameters.named({
          'identity': 'closecall/media/$coupleId',
        }),
        transaction: transaction,
      );
      if (pngBytes.lengthInBytes > 2 * 1024 * 1024) {
        throw MediaFailure(code: 'file_too_large');
      }
      final hash = sha256
          .convert(
            pngBytes.buffer.asUint8List(
              pngBytes.offsetInBytes,
              pngBytes.lengthInBytes,
            ),
          )
          .toString();
      final existing = await MediaRecord.db.findFirstRow(
        session,
        where: (t) =>
            t.coupleId.equals(coupleId) & t.requestId.equals(requestId),
        transaction: transaction,
      );
      if (existing != null) {
        if (existing.contentHash != hash || existing.uploaderId != user) {
          throw MediaFailure(code: 'request_conflict');
        }
        return _asset(existing);
      }
      final dimensions = validatePng(pngBytes);
      if (await MediaRecord.db.count(
            session,
            where: (t) => t.coupleId.equals(coupleId),
            transaction: transaction,
          ) >=
          50) {
        throw MediaFailure(code: 'quota_exceeded');
      }
      // Deterministic SERVER-derived private paths make orphan writes safe to
      // overwrite on retry after a crash/ambiguous commit. No path enters a DTO.
      final path =
          'closecall/photos/${sha256.convert(utf8.encode('$coupleId/$requestId'))}.png';
      final storage = session.serverpod.storage['private']!;
      MediaRecord record;
      try {
        await storage.storeFile(
          session: session,
          path: path,
          byteData: pngBytes,
          options: const StoreFileOptions(
            metadata: FileMetadata(contentType: 'image/png'),
          ),
        );
        record = await MediaRecord.db.insertRow(
          session,
          MediaRecord(
            coupleId: coupleId,
            uploaderId: user,
            width: dimensions.width,
            height: dimensions.height,
            requestId: requestId,
            contentHash: hash,
            storagePath: path,
          ),
          transaction: transaction,
        );
      } catch (_) {
        // Clean up before releasing the lock. If cleanup itself fails, the
        // deterministic path still permits a safe retry; metadata rolls back.
        try {
          await storage.deleteFile(session: session, path: path);
        } catch (_) {
          session.log(
            'Private photo cleanup deferred to upload retry.',
            level: LogLevel.warning,
          );
        }
        rethrow;
      }
      // Do NOT delete on an ambiguous commit failure: the metadata might have
      // committed. Retrying under the same lock discovers the committed row.
      return _asset(record);
    });
  }

  Future<List<MediaAsset>> listAssets(Session session) async {
    final coupleId = await _currentCouple(
      session,
      session.authenticated!.userIdentifier,
    );
    if (coupleId == null) throw MediaFailure(code: 'not_paired');
    final records = await MediaRecord.db.find(
      session,
      where: (t) => t.coupleId.equals(coupleId),
      orderBy: (t) => t.createdAt,
    );
    return records.map(_asset).toList();
  }

  Future<ByteData> downloadPhoto(Session session, String assetId) async {
    final coupleId = await _currentCouple(
      session,
      session.authenticated!.userIdentifier,
    );
    UuidValue id;
    try {
      if (!RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(assetId)) {
        throw const FormatException();
      }
      id = UuidValue.fromString(assetId);
    } catch (_) {
      throw MediaFailure(code: 'asset_not_found');
    }
    if (coupleId == null) throw MediaFailure(code: 'asset_not_found');
    final record = await MediaRecord.db.findFirstRow(
      session,
      where: (t) => t.id.equals(id) & t.coupleId.equals(coupleId),
    );
    if (record == null) throw MediaFailure(code: 'asset_not_found');
    try {
      return await session.serverpod.storage['private']!.retrieveFile(
        session: session,
        path: record.storagePath,
      );
    } on CloudStorageFileNotFoundException {
      throw MediaFailure(code: 'asset_not_found');
    }
  }

  Future<UuidValue?> _currentCouple(
    Session session,
    String user, [
    Transaction? transaction,
  ]) async {
    final membership = await CoupleMember.db.findFirstRow(
      session,
      where: (t) => t.userIdentifier.equals(user),
      transaction: transaction,
    );
    if (membership == null) return null;
    final couple = await Couple.db.findById(
      session,
      membership.coupleId,
      transaction: transaction,
    );
    if (couple == null || couple.pairingCode != null) return null;
    final count = await CoupleMember.db.count(
      session,
      where: (t) => t.coupleId.equals(membership.coupleId),
      transaction: transaction,
    );
    return count == 2 ? membership.coupleId : null;
  }

  MediaAsset _asset(MediaRecord record) => MediaAsset(
    assetId: record.id!.toString(),
    coupleId: record.coupleId.toString(),
    uploaderId: record.uploaderId,
    createdAt: record.createdAt,
    width: record.width,
    height: record.height,
  );
}
