import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:closecall/features/auth/data/session_restoration.dart';
import 'package:closecall/features/media/data/media_client.dart';
import 'package:closecall/features/media/data/media_repository.dart';
import 'package:closecall/features/media/data/serverpod_media_repository.dart';
import 'package:closecall/features/media/presentation/media_controller.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:closecall_client/closecall_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../../support/live_fakes.dart';

// All auth values and HTTP data here are synthetic and stay on loopback.
class _MemoryStorage implements ClientAuthSuccessStorage {
  AuthSuccess? value;
  int reads = 0;
  int writes = 0;
  @override
  Future<AuthSuccess?> get() async {
    reads++;
    return value;
  }

  @override
  Future<void> set(AuthSuccess? data) async {
    writes++;
    value = data;
  }
}

AuthSuccess _auth(int generation, {int user = 1, bool expired = false}) =>
    AuthSuccess(
      authStrategy: 'jwt',
      token: 'synthetic-access-$generation',
      refreshToken: 'synthetic-refresh-$generation',
      tokenExpiresAt: DateTime.now().toUtc().add(
        Duration(hours: expired ? -1 : 1),
      ),
      authUserId: UuidValue.fromString(
        '123e4567-e89b-42d3-a456-${user.toString().padLeft(12, '0')}',
      ),
      scopeNames: {},
    );

class _Call {
  _Call(this.path, this.authorization, this.arguments);
  final String path;
  final String? authorization;
  final Map<String, dynamic> arguments;
}

class _Reply {
  _Reply(this.value, {this.status = HttpStatus.ok});
  final Object? value;
  final int status;
}

class _LocalServer {
  _LocalServer(this.server, this.handle) {
    server.listen((request) => pending.add(_respond(request)));
  }
  final HttpServer server;
  final Future<_Reply> Function(_Call) handle;
  final calls = <_Call>[];
  final pending = <Future<void>>[];
  String get url => 'http://127.0.0.1:${server.port}/';

  static Future<_LocalServer> start(
    Future<_Reply> Function(_Call) handle,
  ) async => _LocalServer(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    handle,
  );

  Future<void> _respond(HttpRequest request) async {
    final arguments =
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
    final call = _Call(
      request.uri.path,
      request.headers.value(HttpHeaders.authorizationHeader),
      arguments,
    );
    calls.add(call);
    final reply = await handle(call);
    request.response
      ..statusCode = reply.status
      ..headers.contentType = ContentType.json
      ..write(SerializationManager.encode(reply.value));
    await request.response.close();
  }

  Future<void> close() async {
    await Future.wait(pending);
    await server.close(force: true);
  }
}

class _SignedOutProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async => null;
}

void main() {
  test(
    '90-second media transport shares one live manager; regular stays 20',
    () {
      final primary = Client('http://localhost:1/');
      final storage = _MemoryStorage();
      primary.authSessionManager = createRestorableAuthManager(
        primary,
        storage: storage,
      );
      final manager = primary.auth;
      final media = createMediaClient(primary.host, authKeyProvider: manager);
      addTearDown(primary.close);
      addTearDown(media.close);

      expect(primary.connectionTimeout, const Duration(seconds: 20));
      expect(media.connectionTimeout, const Duration(seconds: 90));
      expect(media.authKeyProvider, same(primary.authKeyProvider));
      expect(manager.caller.client, same(primary));
      expect(storage.reads, 0);
      expect(storage.writes, 0);
      expect(SessionRestoration(manager).timeout, const Duration(seconds: 30));
    },
  );

  test(
    'SDK full-response timeout: binary upload/list/download outlast regular budget',
    () async {
      final payload = Uint8List.fromList(
        List.generate(256 * 1024, (index) => index % 251),
      );
      final server = await _LocalServer.start((call) async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return _Reply(switch (call.path) {
          '/media/uploadPhoto' => testAsset(),
          '/media/listAssets' => [testAsset()],
          '/media/downloadPhoto' => ByteData.sublistView(payload),
          _ => throw StateError('Unexpected synthetic endpoint'),
        });
      });
      addTearDown(server.close);
      // Scale 20s/90s to 200ms/900ms; use the real SDK HTTP delegate, not a
      // repository fake. The response delay occurs after receiving the payload.
      final primary = Client(
        server.url,
        connectionTimeout: const Duration(milliseconds: 200),
      );
      final media = createMediaClient(
        server.url,
        authKeyProvider: _SignedOutProvider(),
        connectionTimeout: const Duration(milliseconds: 900),
      );
      addTearDown(primary.close);
      addTearDown(media.close);
      await expectLater(
        ServerpodMediaRepository(
          primary,
        ).uploadPhoto(payload, 'regular-budget'),
        throwsA(isA<ServerpodClientNetworkException>()),
      );
      final repository = ServerpodMediaRepository(media);
      expect(
        (await repository.uploadPhoto(payload, 'media-budget')).assetId,
        'asset',
      );
      expect((await repository.listAssets()).single.assetId, 'asset');
      expect(await repository.downloadPhoto('asset'), payload);
      final uploads = server.calls.where((c) => c.path == '/media/uploadPhoto');
      expect(uploads, hasLength(2));
      for (final upload in uploads) {
        expect(
          byteDataBytes(
            ByteDataJsonExtension.fromJson(upload.arguments['pngBytes']),
          ),
          payload,
        );
      }
    },
  );

  test(
    'media budget remains bounded; lost committed response needs explicit same-UUID retry',
    () async {
      final releaseFirstResponse = Completer<void>();
      final records = <String, MediaAsset>{};
      final payloads = <Uint8List>[];
      var submissions = 0;
      final server = await _LocalServer.start((call) async {
        if (call.path != '/media/uploadPhoto') {
          throw StateError('Unexpected synthetic endpoint');
        }
        submissions++;
        final id = call.arguments['requestId'] as String;
        payloads.add(
          byteDataBytes(
            ByteDataJsonExtension.fromJson(call.arguments['pngBytes']),
          ),
        );
        final asset = records.putIfAbsent(
          id,
          () => testAsset(id: 'committed', uploader: 'me'),
        );
        if (submissions == 1) await releaseFirstResponse.future;
        return _Reply(asset);
      });
      addTearDown(() async {
        if (!releaseFirstResponse.isCompleted) releaseFirstResponse.complete();
        await server.close();
      });
      final client = createMediaClient(
        server.url,
        authKeyProvider: _SignedOutProvider(),
        connectionTimeout: const Duration(milliseconds: 300),
      );
      addTearDown(client.close);
      final auth = FakeAuth()..change('me');
      final pairing = PairingController(
        session: auth,
        repository: FakeCouples(),
      );
      await pairing.initialize();
      var preparations = 0;
      final media = MediaController(
        pairing: pairing,
        repository: ServerpodMediaRepository(client),
        prepare: (bytes) async {
          preparations++;
          return bytes;
        },
        requestId: () => '123e4567-e89b-42d3-a456-426614174000',
      );
      addTearDown(() {
        media.dispose();
        pairing.dispose();
        auth.dispose();
      });
      final photo = Uint8List.fromList(testPng);
      await media.uploadConfirmed(photo);
      photo[0] = 0;
      expect(media.error, isNull);
      expect(media.status, contains('waiting for server confirmation'));
      expect(media.busy, isFalse);
      expect(media.hasPendingUpload, isTrue);
      final pendingId = media.pendingRequestId;
      expect(records, hasLength(1));
      expect(submissions, 1);
      releaseFirstResponse.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        submissions,
        1,
      ); // No automatic replay, even after the late response.
      expect(media.hasPendingUpload, isTrue);
      expect(media.assets, isEmpty);

      await media.retry();
      expect(submissions, 2);
      expect(records, hasLength(1));
      expect(server.calls.map((c) => c.arguments['requestId']).toSet(), {
        pendingId,
      });
      expect(payloads.first, payloads.last);
      expect(preparations, 1);
      expect(media.assets.single.assetId, 'committed');
      expect(media.hasPendingUpload, isFalse);
    },
  );

  test(
    'shared auth refresh uses primary caller; account switch/sign-out change media headers',
    () async {
      final storage = _MemoryStorage();
      var refreshes = 0;
      final authServer = await _LocalServer.start((call) async {
        if (call.path == '/jwtRefresh/refreshAccessToken') {
          refreshes++;
          return _Reply(_auth(2));
        }
        if (call.path == '/serverpod_auth_core.status/signOutDevice') {
          return _Reply(null);
        }
        throw StateError('Unexpected synthetic auth endpoint');
      });
      addTearDown(authServer.close);
      final authErrors = <Type>[];
      final primary = Client(
        authServer.url,
        onFailedCall: (_, error, _) => authErrors.add(error.runtimeType),
      );
      primary.authSessionManager = createRestorableAuthManager(
        primary,
        storage: storage,
      );
      final manager = primary.auth;
      await manager.updateSignedInUser(_auth(1));
      var rejectFirst = true;
      final mediaServer = await _LocalServer.start((call) async {
        if (rejectFirst) {
          rejectFirst = false;
          // Expire the live credentials so the SDK's 401 refresh path rotates.
          await manager.updateSignedInUser(_auth(1, expired: true));
          return _Reply(null, status: HttpStatus.unauthorized);
        }
        return _Reply(<MediaAsset>[]);
      });
      addTearDown(mediaServer.close);
      final media = createMediaClient(
        mediaServer.url,
        authKeyProvider: manager,
      );
      addTearDown(primary.close);
      addTearDown(media.close);
      expect(manager.caller.client, same(primary));
      expect(media.authKeyProvider, same(manager));
      try {
        await media.media.listAssets();
      } catch (_) {
        expect(
          refreshes,
          1,
          reason: '401 should reach the primary refresh caller',
        );
        expect(authErrors, isEmpty, reason: 'Synthetic refresh should decode');
        rethrow;
      }
      expect(refreshes, 1);
      expect(mediaServer.calls.map((c) => c.authorization), [
        'Bearer synthetic-access-1',
        'Bearer synthetic-access-2',
      ]);
      expect(authServer.calls.single.authorization, isNull);
      expect(
        authServer.calls.single.arguments['refreshToken'],
        'synthetic-refresh-1',
      );
      await manager.updateSignedInUser(_auth(3, user: 2));
      await media.media.listAssets();
      expect(mediaServer.calls.last.authorization, 'Bearer synthetic-access-3');
      await manager.signOutDevice();
      await media.media.listAssets();
      expect(mediaServer.calls.last.authorization, isNull);
      expect(manager.isAuthenticated, isFalse);
      expect(manager.caller.client, same(primary));
      expect(authServer.calls, hasLength(2));
    },
  );

  test('regular and media requests join the same SDK refresh flight', () async {
    var refreshes = 0;
    final storage = _MemoryStorage();
    final primaryServer = await _LocalServer.start((call) async {
      if (call.path == '/jwtRefresh/refreshAccessToken') {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return _Reply(_auth(2));
      }
      return _Reply(<MediaAsset>[]);
    });
    final mediaServer = await _LocalServer.start(
      (_) async => _Reply(<MediaAsset>[]),
    );
    addTearDown(primaryServer.close);
    addTearDown(mediaServer.close);
    final primary = Client(primaryServer.url);
    primary.authSessionManager = createRestorableAuthManager(
      primary,
      storage: storage,
    );
    final manager = primary.auth;
    final media = createMediaClient(mediaServer.url, authKeyProvider: manager);
    addTearDown(primary.close);
    addTearDown(media.close);
    await manager.updateSignedInUser(_auth(1, expired: true));

    await Future.wait([primary.media.listAssets(), media.media.listAssets()]);
    expect(refreshes, 1);
    expect(storage.writes, 2); // Initial identity plus one rotation only.
    expect(manager.caller.client, same(primary));
    expect(primaryServer.calls.last.authorization, 'Bearer synthetic-access-2');
    expect(mediaServer.calls.single.authorization, 'Bearer synthetic-access-2');
  });
}
