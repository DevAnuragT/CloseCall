import 'dart:convert';
import 'dart:typed_data';
import 'package:closecall_client/closecall_client.dart';

// Development-only smoke: creates three fresh local guest identities.
// Tokens stay in memory and are never printed or saved.

class TokenProvider implements ClientAuthKeyProvider {
  TokenProvider(this.token);
  final String token;
  @override
  Future<String?> get authHeaderValue async => 'Bearer $token';
}

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> main() async {
  final clients = List.generate(3, (_) => Client('http://localhost:8080/'));
  try {
    var denied = false;
    try {
      await clients.first.pairing.currentCouple();
    } on ServerpodClientUnauthorized {
      denied = true;
    }
    check(denied, 'Unauthenticated HTTP request must be rejected.');
    for (final client in clients) {
      final auth = await client.anonymousIdp.login();
      client.authKeyProvider = TokenProvider(auth.token);
    }
    final pending = await clients[0].pairing.createCouple();
    final again = await clients[0].pairing.createCouple();
    check(pending.coupleId == again.coupleId, 'Create must be idempotent.');
    check(
      await clients[1].pairing.currentCouple() == null,
      'Identity isolation.',
    );
    final joined = await clients[1].pairing.joinByCode(pending.pairingCode!);
    check(joined.memberIds.length == 2, 'Exactly two members.');
    final read = await clients[0].pairing.currentCouple();
    check(read?.coupleId == joined.coupleId, 'Creator reads committed state.');
    check(read?.pairingCode == null, 'Invite must be consumed.');
    var consumed = false;
    try {
      await clients[2].pairing.joinByCode(pending.pairingCode!);
    } on PairingFailure catch (error) {
      consumed = error.code == 'code_not_found';
    }
    check(consumed, 'Consumed invite must be rejected over HTTP.');
    final account = await clients[0].account.currentAccount();
    check(account.isGuest && account.email == null, 'Guest account status.');
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4v+rMfwAIlgN1QhRUCQAAAABJRU5ErkJggg==',
    );
    final requestId = Uuid().v4();
    final photo = await clients[0].media.uploadPhoto(
      ByteData.sublistView(png),
      requestId,
    );
    final retry = await clients[0].media.uploadPhoto(
      ByteData.sublistView(png),
      requestId,
    );
    check(photo.assetId == retry.assetId, 'Upload retry must be idempotent.');
    final listed = await clients[1].media.listAssets();
    check(
      listed.any((a) => a.assetId == photo.assetId),
      'Partner lists photo.',
    );
    final downloaded = await clients[1].media.downloadPhoto(photo.assetId);
    final bytes = downloaded.buffer.asUint8List(
      downloaded.offsetInBytes,
      downloaded.lengthInBytes,
    );
    check(base64Encode(bytes) == base64Encode(png), 'Partner downloads PNG.');
    var private = false;
    try {
      await clients[2].media.downloadPhoto(photo.assetId);
    } on MediaFailure catch (error) {
      private = error.code == 'asset_not_found';
    }
    check(private, 'Stranger cannot download private media.');
    final now = DateTime.now().toUtc();
    final scheduled = await clients[0].widgetSchedule.createSchedule(
      photo.assetId,
      now.add(const Duration(seconds: 1)),
      now.add(const Duration(seconds: 20)),
      Uuid().v4(),
    );
    final partnerTimeline = await clients[1].widgetSchedule.currentTimeline();
    check(
      partnerTimeline.schedules.any(
        (entry) => entry.scheduleId == scheduled.scheduleId,
      ),
      'Partner timeline contains schedule.',
    );
    await clients[1].widgetSchedule.cancelSchedule(scheduled.scheduleId);
    final cancelled = await clients[1].widgetSchedule.currentTimeline();
    check(
      cancelled.schedules.every(
        (entry) => entry.scheduleId != scheduled.scheduleId,
      ),
      'Cancelled schedule leaves timeline.',
    );
    print(
      'HTTP smoke passed: auth, pairing, private media, schedule, cancel, idempotency, isolation.',
    );
  } finally {
    for (final client in clients) {
      client.close();
    }
  }
}
