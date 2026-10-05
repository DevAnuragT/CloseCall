import 'dart:async';

import 'package:closecall/core/serverpod/serverpod_bootstrap.dart';
import 'package:closecall/features/auth/data/session_restoration.dart';
import 'package:closecall_client/closecall_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

// All authentication material below is synthetic, in-memory test data. Never
// assert/print AuthSuccess itself: its generated toString includes credentials.
class _MemoryStorage implements ClientAuthSuccessStorage {
  _MemoryStorage(this._value);
  AuthSuccess? _value;
  int reads = 0;
  int writes = 0;
  bool readFails = false;
  bool writeFails = false;
  bool get populated => _value != null;

  @override
  Future<AuthSuccess?> get() async {
    reads++;
    if (readFails) throw StateError('Synthetic storage failure');
    return _value;
  }

  @override
  Future<void> set(AuthSuccess? data) async {
    writes++;
    if (writeFails) throw StateError('Synthetic storage failure');
    _value = data;
  }
}

AuthSuccess _syntheticAuth(int generation, {bool expired = false}) =>
    AuthSuccess(
      authStrategy: 'jwt',
      token: 'synthetic-access-$generation',
      refreshToken: 'synthetic-refresh-$generation',
      tokenExpiresAt: DateTime.now().toUtc().add(
        expired ? const Duration(hours: -1) : const Duration(hours: 1),
      ),
      authUserId: UuidValue.fromString('00000000-0000-0000-0000-000000000001'),
      scopeNames: {},
    );

class _SdkClient extends Client {
  _SdkClient() : super('http://localhost:1/');
  int refreshes = 0;
  int statuses = 0;
  int revocations = 0;
  int staleRequests = 0;
  int _generation = 0;
  String? _expectedRefresh = _syntheticAuth(0).refreshToken;
  Completer<void>? refreshWait;
  Completer<void>? statusWait;
  Completer<void>? revocationWait;
  Object? refreshFailure;
  Object? statusFailure;
  bool revocationFails = false;
  bool signedIn = true;

  @override
  Future<T> callServerEndpoint<T>(
    String endpoint,
    String method,
    Map<String, dynamic> args, {
    bool authenticated = true,
  }) async {
    if (method == 'refreshAccessToken') {
      refreshes++;
      if (refreshWait != null) await refreshWait!.future;
      if (refreshFailure != null) throw refreshFailure!;
      if (args['refreshToken'] != _expectedRefresh) {
        staleRequests++;
        throw RefreshTokenInvalidSecretException();
      }
      final rotated = _syntheticAuth(++_generation);
      _expectedRefresh = rotated.refreshToken;
      return rotated as T;
    }
    if (method == 'isSignedIn') {
      statuses++;
      if (statusWait != null) await statusWait!.future;
      if (statusFailure != null) throw statusFailure!;
      return signedIn as T;
    }
    if (method == 'signOutDevice') {
      revocations++;
      if (revocationWait != null) await revocationWait!.future;
      if (revocationFails) {
        throw const ServerpodClientNetworkException('Synthetic offline error');
      }
      return null as T;
    }
    throw StateError('Unexpected synthetic endpoint');
  }
}

void main() {
  late _SdkClient client;
  late _MemoryStorage storage;
  late FlutterAuthSessionManager manager;
  late SessionRestoration restoration;

  setUp(() {
    client = _SdkClient();
    storage = _MemoryStorage(_syntheticAuth(0));
    manager = createRestorableAuthManager(client, storage: storage);
    client.authSessionManager = manager;
    restoration = SessionRestoration(manager);
  });
  tearDown(() {
    restoration.dispose();
    client.close();
  });

  test(
    'fresh signed-out session needs no network and no credentials',
    () async {
      storage = _MemoryStorage(null);
      manager = createRestorableAuthManager(client, storage: storage);
      client.authSessionManager = manager;
      restoration = SessionRestoration(manager);
      await restoration.initialize();
      expect(manager.isAuthenticated, isFalse);
      expect(client.refreshes + client.statuses + client.revocations, 0);
    },
  );

  testWidgets('SDK default timeout returns false while refresh remains live', (
    tester,
  ) async {
    client.refreshWait = Completer<void>();
    bool? initialized;
    final flight = manager.initialize().then((value) => initialized = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await flight;
    expect(initialized, isFalse);
    expect(manager.isAuthenticated, isTrue);
    expect(storage.writes, 0);
    client.refreshWait!.complete();
    await tester.pump();
    expect(storage.writes, 1);
  });

  testWidgets('SDK false timeout can be followed by invalid-auth local clear', (
    tester,
  ) async {
    client.refreshFailure = RefreshTokenInvalidSecretException();
    client.revocationFails = true;
    client.revocationWait = Completer<void>();
    bool? initialized;
    final flight = manager.initialize().then((value) => initialized = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await flight;
    expect(initialized, isFalse);
    client.revocationWait!.complete();
    await tester.pump();
    expect(manager.isAuthenticated, isFalse);
    expect(storage.populated, isFalse);
  });

  test(
    'storage restore failure with no in-memory auth is not fresh signed-out',
    () async {
      storage.readFails = true;
      await expectLater(
        restoration.initialize(),
        throwsA(isA<SessionValidationException>()),
      );
      expect(manager.isAuthenticated, isFalse);
      expect(storage.populated, isTrue);
    },
  );

  test(
    'local clear failure is not mistaken for revoked signed-out state',
    () async {
      storage.writeFails = true;
      client.refreshFailure = RefreshTokenInvalidSecretException();
      await expectLater(
        restoration.initialize(),
        throwsA(isA<SessionValidationException>()),
      );
      expect(manager.isAuthenticated, isTrue);
      expect(storage.populated, isTrue);
    },
  );

  testWidgets('restoration accepts validated refresh taking over two seconds', (
    tester,
  ) async {
    client.refreshWait = Completer<void>();
    bool done = false;
    final flight = restoration.initialize().then((_) => done = true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(done, isFalse);
    client.refreshWait!.complete();
    await tester.pump();
    await flight;
    expect(done, isTrue);
    expect(client.statuses, 1);
    expect(storage.writes, 1);
  });

  test(
    'expired valid refresh persists rotation across a cold restart',
    () async {
      storage = _MemoryStorage(_syntheticAuth(0, expired: true));
      manager = createRestorableAuthManager(client, storage: storage);
      client.authSessionManager = manager;
      restoration = SessionRestoration(manager);
      await restoration.initialize();
      restoration.dispose();
      manager = createRestorableAuthManager(client, storage: storage);
      client.authSessionManager = manager;
      restoration = SessionRestoration(manager);
      await restoration.initialize();
      expect(manager.isAuthenticated, isTrue);
      expect(client.refreshes, 2);
      expect(client.staleRequests, 0);
      expect(storage.writes, 2);
    },
  );

  test('SDK validation false can mean invalid auth already cleared', () async {
    client.refreshFailure = RefreshTokenInvalidSecretException();
    client.revocationFails = true;
    await manager.restore();
    final valid = await manager.validateAuthentication();
    expect(valid, isFalse);
    expect(manager.isAuthenticated, isFalse);
    expect(storage.populated, isFalse);
  });

  for (final failure in [
    RefreshTokenInvalidSecretException(),
    RefreshTokenNotFoundException(),
    RefreshTokenExpiredException(),
    RefreshTokenMalformedException(),
  ]) {
    test(
      'invalid refresh ${failure.runtimeType} clears despite revoke failure',
      () async {
        client.refreshFailure = failure;
        client.revocationFails = true;
        await restoration.initialize();
        expect(manager.isAuthenticated, isFalse);
        expect(storage.populated, isFalse);
        expect(client.revocations, 1);
        expect(client.statuses, 0);
      },
    );
  }

  test(
    'offline failedOther preserves identity and retry validates it',
    () async {
      client.refreshFailure = const ServerpodClientNetworkException(
        'Synthetic offline error',
      );
      client.signedIn = false;
      await expectLater(
        restoration.initialize(),
        throwsA(isA<SessionValidationException>()),
      );
      expect(manager.isAuthenticated, isTrue);
      expect(storage.populated, isTrue);
      expect(storage.writes, 0);
      expect(client.statuses + client.revocations, 0);
      client.refreshFailure = null;
      client.signedIn = true;
      await restoration.initialize();
      expect(client.statuses, 1);
      expect(storage.writes, 1);
    },
  );

  test('status network failure is not logout or unchecked success', () async {
    client.statusFailure = const ServerpodClientNetworkException(
      'Synthetic offline error',
    );
    await expectLater(
      restoration.initialize(),
      throwsA(isA<SessionValidationException>()),
    );
    expect(manager.isAuthenticated, isTrue);
    expect(storage.populated, isTrue);
    expect(client.revocations, 0);
  });

  test(
    'definitively revoked status returns a normal signed-out result',
    () async {
      client.signedIn = false;
      client.revocationFails = true;
      await restoration.initialize();
      expect(manager.isAuthenticated, isFalse);
      expect(storage.populated, isFalse);
    },
  );

  testWidgets('double initialize and timed-out retry join the late flight', (
    tester,
  ) async {
    restoration = SessionRestoration(
      manager,
      timeout: const Duration(seconds: 5),
    );
    client.refreshWait = Completer<void>();
    final first = expectLater(
      restoration.initialize(),
      throwsA(isA<SessionValidationException>()),
    );
    final second = expectLater(
      restoration.initialize(),
      throwsA(isA<SessionValidationException>()),
    );
    await tester.pump();
    final reads = storage.reads;
    await tester.pump(const Duration(seconds: 6));
    await first;
    await second;
    final retry = restoration.initialize();
    await tester.pump();
    expect(client.refreshes, 1);
    expect(storage.reads, reads);
    client.refreshWait!.complete();
    await tester.pump();
    await retry;
    expect(storage.writes, 1);
    expect(client.staleRequests, 0);
  });

  testWidgets('validation and concurrent endpoint refresh keep SDK mutex', (
    tester,
  ) async {
    client.refreshWait = Completer<void>();
    final flight = restoration.initialize();
    await tester.pump();
    final concurrent = manager.refreshAuthKey(force: true);
    await tester.pump();
    expect(client.refreshes, 1);
    client.refreshWait!.complete();
    await tester.pump();
    await flight;
    expect(await concurrent, RefreshAuthKeyResult.success);
    expect(storage.writes, 1);
    expect(client.staleRequests, 0);
  });

  testWidgets('explicit sign-out waits for late rotation before local clear', (
    tester,
  ) async {
    client.refreshWait = Completer<void>();
    final flight = restoration.initialize();
    await tester.pump();
    final signOut = restoration.signOut();
    await tester.pump();
    expect(client.revocations, 0);
    client.refreshWait!.complete();
    await tester.pump();
    await flight;
    await signOut;
    expect(storage.populated, isFalse);
    expect(manager.isAuthenticated, isFalse);
    expect(storage.writes, 2);
  });

  testWidgets('account switch cannot be cleared by stale validation status', (
    tester,
  ) async {
    client.statusWait = Completer<void>();
    client.signedIn = false;
    final flight = expectLater(
      restoration.initialize(),
      throwsA(isA<SessionValidationException>()),
    );
    await tester.pump();
    final switched = _syntheticAuth(99).copyWith(
      authUserId: UuidValue.fromString('00000000-0000-0000-0000-000000000002'),
    );
    await manager.updateSignedInUser(switched);
    client.statusWait!.complete();
    await tester.pump();
    await flight;
    expect(manager.authInfo?.authUserId == switched.authUserId, isTrue);
    expect(client.revocations, 0);
  });

  testWidgets('late SDK rotation cannot overwrite a different account', (
    tester,
  ) async {
    client.refreshWait = Completer<void>();
    final flight = expectLater(
      restoration.initialize(),
      throwsA(isA<SessionValidationException>()),
    );
    await tester.pump();
    final switched = _syntheticAuth(99).copyWith(
      authUserId: UuidValue.fromString('00000000-0000-0000-0000-000000000002'),
    );
    await manager.updateSignedInUser(switched);
    client.refreshWait!.complete();
    await tester.pump();
    await flight;
    expect(manager.authInfo?.authUserId == switched.authUserId, isTrue);
    expect(client.statuses + client.revocations, 0);
  });

  testWidgets(
    'sign-out waiting on validation cannot clear a switched account',
    (tester) async {
      client.refreshWait = Completer<void>();
      final flight = expectLater(
        restoration.initialize(),
        throwsA(isA<SessionValidationException>()),
      );
      await tester.pump();
      final signOut = expectLater(
        restoration.signOut(),
        throwsA(isA<SessionValidationException>()),
      );
      final switched = _syntheticAuth(99).copyWith(
        authUserId: UuidValue.fromString(
          '00000000-0000-0000-0000-000000000002',
        ),
      );
      await manager.updateSignedInUser(switched);
      client.refreshWait!.complete();
      await tester.pump();
      await flight;
      await signOut;
      expect(manager.authInfo?.authUserId == switched.authUserId, isTrue);
      expect(client.revocations, 0);
    },
  );

  testWidgets('disposal prevents late status from clearing the session', (
    tester,
  ) async {
    client.statusWait = Completer<void>();
    client.signedIn = false;
    final flight = expectLater(
      restoration.initialize(),
      throwsA(isA<SessionValidationException>()),
    );
    await tester.pump();
    restoration.dispose();
    client.statusWait!.complete();
    await tester.pump();
    await flight;
    expect(manager.isAuthenticated, isTrue);
    expect(client.revocations, 0);
  });

  test(
    'production AuthSession accepts SDK local clear on invalid refresh',
    () async {
      client.refreshFailure = RefreshTokenInvalidSecretException();
      client.revocationFails = true;
      final session = ServerpodAuthSession(client);
      await session.initialize();
      expect(session.userId, isNull);
      session.dispose();
    },
  );
}
