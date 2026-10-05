import 'dart:async';

import 'package:closecall_client/closecall_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import 'auth_session.dart';
export 'auth_session.dart'
    show SessionValidationException, LocalSignOutException;

/// Uses the SDK JWT provider unchanged, with an identity guard at its public
/// persistence callback so a late rotation cannot replace a newer account.
FlutterAuthSessionManager createRestorableAuthManager(
  Client client, {
  ClientAuthSuccessStorage? storage,
}) {
  late final FlutterAuthSessionManager manager;
  manager = FlutterAuthSessionManager(
    storage: storage,
    authKeyProviderDelegates: {
      'jwt': JwtAuthKeyProvider(
        getAuthInfo: () async => manager.authInfo,
        onRefreshAuthInfo: (auth) async {
          if (manager.authInfo?.authUserId != auth.authUserId ||
              manager.authInfo?.authStrategy != auth.authStrategy) {
            throw const SessionValidationException();
          }
          await manager.updateSignedInUser(auth);
        },
        // Public equivalent of the SDK's cache invalidation/restoration hook.
        invalidateCachedAuthInfo: () => manager.restore(),
        refreshEndpoint: client.getEndpointOfType<EndpointRefreshJwtTokens>(),
        usesCookieAuth: () => client.cookieAuth,
        getCrossTabRefreshLock: () => client.authRefreshCrossTabLock,
      ),
    },
  );
  return manager;
}

/// Public SDK operations only: the SDK still owns credentials, persistence,
/// and the JWT refresh mutex. A timeout bounds the UI wait, not the operation.
class SessionRestoration {
  SessionRestoration(
    this.manager, {
    this.timeout = const Duration(seconds: 30),
  });

  final FlutterAuthSessionManager manager;
  final Duration timeout;
  Future<void>? _flight;
  bool _restored = false;
  bool _disposed = false;

  Future<void> initialize() {
    if (_disposed) return Future.error(const SessionValidationException());
    // Retain the underlying flight after a UI timeout. Retrying joins it rather
    // than restoring an obsolete persisted copy during a token rotation.
    final flight = _flight ??= _initialize().whenComplete(() => _flight = null);
    return flight.timeout(
      timeout,
      onTimeout: () {
        throw const SessionValidationException();
      },
    );
  }

  Future<void> _initialize() async {
    try {
      if (!_restored) {
        await manager.restore();
        _restored = true;
      }
      _ensureActive();
      if (!manager.isAuthenticated) return;
      final identity = manager.authInfo!.authUserId;
      final strategy = manager.authInfo!.authStrategy;
      bool current() =>
          !_disposed &&
          manager.authInfo?.authUserId == identity &&
          manager.authInfo?.authStrategy == strategy;

      final result = await manager.refreshAuthKey(force: true);
      _ensureActive();
      if (!current()) throw const SessionValidationException();
      // SDK 4.0.3 validateAuthentication ignores failedOther and proceeds to
      // status. A failed refresh must not become a logout or unchecked success.
      if (result == RefreshAuthKeyResult.failedOther) {
        throw const SessionValidationException();
      }
      final invalid =
          result == RefreshAuthKeyResult.failedUnauthorized ||
          !await manager.caller.status.isSignedIn();
      _ensureActive();
      if (!current()) throw const SessionValidationException();
      if (invalid) {
        // The SDK clears locally in finally even if remote revocation fails.
        // That is a normal signed-out result, not a connection failure.
        await manager.signOutDevice();
        _ensureActive();
        if (manager.isAuthenticated) throw const SessionValidationException();
      }
    } catch (_) {
      // Do not expose endpoint errors, which may include authentication data.
      throw const SessionValidationException();
    }
  }

  Future<void> signOut() async {
    final identity = manager.authInfo?.authUserId;
    final strategy = manager.authInfo?.authStrategy;
    // A late refresh must finish persisting before explicit sign-out clears it.
    final flight = _flight;
    if (flight != null) {
      try {
        await flight;
      } catch (_) {
        // Explicit sign-out is allowed after failed validation as well.
      }
    }
    _ensureActive();
    if (manager.isAuthenticated &&
        (manager.authInfo?.authUserId != identity ||
            manager.authInfo?.authStrategy != strategy)) {
      throw const SessionValidationException();
    }
    try {
      final revoked = await manager.signOutDevice();
      if (manager.isAuthenticated) throw const SessionValidationException();
      if (!revoked) throw const LocalSignOutException();
    } on LocalSignOutException {
      rethrow;
    } catch (_) {
      throw const SessionValidationException();
    }
  }

  void _ensureActive() {
    if (_disposed) throw const SessionValidationException();
  }

  void dispose() => _disposed = true;
}
