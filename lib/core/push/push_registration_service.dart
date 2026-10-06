import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/pairing/presentation/pairing_controller.dart';
import '../permissions/notification_permission_service.dart';
import '../../firebase_options.dart';
import 'push_registration_api.dart';

/// A narrow adapter keeps FCM platform channels out of lifecycle tests.
abstract interface class PushMessagingClient {
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
}

class FirebasePushMessagingClient implements PushMessagingClient {
  FirebasePushMessagingClient([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}

/// Initializes Firebase at most once in this isolate. Failure is an ordinary
/// unavailable state: authentication, pairing, foreground sends and widgets
/// must not depend on Firebase being configured.
class FirebasePushBootstrap {
  static Future<bool>? _initialization;

  static Future<bool> ensureInitialized() {
    final existing = _initialization;
    if (existing != null) return existing;
    final future = _initialize();
    _initialization = future;
    return future;
  }

  static Future<bool> _initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

abstract interface class PushDeviceIdentityStore {
  Future<String> deviceId();
}

/// This installation identifier is not an auth credential and is never
/// returned by an endpoint. It lets the server revoke a rotated token without
/// the client persisting the token itself.
class SharedPreferencesPushDeviceIdentityStore
    implements PushDeviceIdentityStore {
  static const key = 'closecall.push.device_id.v1';
  static const _uuid = Uuid();

  @override
  Future<String> deviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getString(key);
    if (current != null && current.isNotEmpty) return current;
    final created = _uuid.v4();
    if (!await preferences.setString(key, created)) {
      throw StateError('Could not persist push device identity.');
    }
    return created;
  }
}

/// Coordinates FCM with the validated auth/pairing scope. It never requests
/// notification permission; the onboarding flow owns that decision.
class PushRegistrationService {
  PushRegistrationService({
    required this.pairing,
    required this.permissions,
    required this.api,
    this.messaging,
    this.bootstrap = FirebasePushBootstrap.ensureInitialized,
    PushDeviceIdentityStore? deviceIdentity,
    this.platform,
    this.appVersion,
  }) : deviceIdentity =
           deviceIdentity ?? SharedPreferencesPushDeviceIdentityStore();

  final PairingController pairing;
  final WidgetPermissionService permissions;
  final PushRegistrationApi api;
  final PushMessagingClient? messaging;
  final Future<bool> Function() bootstrap;
  final PushDeviceIdentityStore deviceIdentity;
  final String? platform;
  final String? appVersion;

  StreamSubscription<String>? _tokenSubscription;
  Future<void>? _reconcileFlight;
  String? _deviceId;
  String? _registeredToken;
  String? _registeredScope;
  int _generation = 0;
  bool _started = false;
  bool _disposed = false;

  bool get started => _started;

  /// Starts listeners only. Actual registration waits for a loaded, complete
  /// pairing and a read-only granted notification status.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    pairing.addListener(_pairingChanged);
    pairing.addBeforeSignOutHook(_beforeSignOut);
    unawaited(reconcile());
  }

  Future<void> _beforeSignOut() => stop(revoke: true, keepStarted: true);

  /// Stops token work and best-effort revokes the current device scope. A
  /// remote revoke is never allowed to block sign-out or re-pairing.
  Future<void> stop({bool revoke = true, bool keepStarted = false}) async {
    if (!_started && !keepStarted) return;
    _generation++;
    // An invalidation received for the old authenticated scope is not a
    // credential and must not survive an explicit sign-out/re-pair boundary.
    await PushPendingWakeMarker.clear();
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
    final token = _registeredToken;
    final registered = token != null;
    final device = _deviceId;
    _registeredToken = null;
    _registeredScope = null;
    if (revoke && registered && device != null) {
      try {
        await api.revokeDevice(deviceId: device, token: token);
      } catch (_) {
        // Sign-out/re-pair remains usable while an offline revoke retries on
        // the next authenticated registration.
      }
    }
    if (!keepStarted) {
      _started = false;
      pairing.removeListener(_pairingChanged);
      pairing.removeBeforeSignOutHook(_beforeSignOut);
    }
  }

  Future<void> reconcile() async {
    if (!_started || _disposed) return;
    final previous = _reconcileFlight;
    if (previous != null) {
      await previous;
      if (!_started || _disposed) return;
    }
    final flight = _reconcileNow();
    _reconcileFlight = flight;
    try {
      await flight;
    } finally {
      if (identical(_reconcileFlight, flight)) _reconcileFlight = null;
    }
  }

  Future<void> _reconcileNow() async {
    final scope = _scope;
    if (scope == null) {
      await _clearRegistration();
      return;
    }
    final generation = _generation;
    NotificationAccess access;
    try {
      // Read-only status. This service intentionally never calls
      // requestNotifications().
      access = await permissions.notificationStatus();
    } catch (_) {
      return;
    }
    if (!_isCurrent(generation, scope) ||
        access != NotificationAccess.granted) {
      if (access != NotificationAccess.granted) await _clearRegistration();
      return;
    }

    final ready = await bootstrap();
    if (!ready || !_isCurrent(generation, scope)) return;
    final client = messaging ?? FirebasePushMessagingClient();
    _tokenSubscription ??= client.onTokenRefresh.listen(
      (token) => unawaited(_registerToken(token, scope)),
      onError: (_) {},
    );
    String? token;
    try {
      token = await client.getToken();
    } catch (_) {
      return;
    }
    if (token == null || token.isEmpty || !_isCurrent(generation, scope)) {
      return;
    }
    await _registerToken(token, scope, generation: generation);
  }

  Future<void> _registerToken(
    String token,
    String scope, {
    int? generation,
  }) async {
    final currentGeneration = generation ?? _generation;
    if (!_isCurrent(currentGeneration, scope) || token.isEmpty) return;
    if (_registeredToken == token && _registeredScope == scope) return;
    try {
      _deviceId ??= await deviceIdentity.deviceId();
      if (!_isCurrent(currentGeneration, scope)) return;
      await api.registerDevice(
        token: token,
        deviceId: _deviceId!,
        platform: platform,
        appVersion: appVersion,
      );
      if (!_isCurrent(currentGeneration, scope)) return;
      _registeredToken = token;
      _registeredScope = scope;
    } catch (_) {
      // Push is a delivery hint; it must not turn a usable authenticated app
      // into an error state.
    }
  }

  Future<void> _clearRegistration() async {
    _generation++;
    final device = _deviceId;
    final token = _registeredToken;
    final hadRegistration = token != null;
    _registeredToken = null;
    _registeredScope = null;
    if (!hadRegistration || device == null) return;
    try {
      await api.revokeDevice(deviceId: device, token: token);
    } catch (_) {}
  }

  String? get _scope {
    final user = pairing.userId;
    final couple = pairing.couple;
    if (!pairing.hasLoadedPairing ||
        user == null ||
        couple?.isComplete != true) {
      return null;
    }
    return '$user:${couple!.id}';
  }

  bool _isCurrent(int generation, String scope) =>
      !_disposed && _started && generation == _generation && _scope == scope;

  void _pairingChanged() {
    // Increment before scheduling so a token or status result from the old
    // account/couple cannot register under the new scope.
    if (_registeredScope != _scope) {
      unawaited(_clearRegistration().whenComplete(reconcile));
    } else {
      unawaited(reconcile());
    }
  }

  @visibleForTesting
  String? get registeredScope => _registeredScope;

  @visibleForTesting
  String? get registeredTokenForTesting => _registeredToken;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop());
  }
}

/// Receives only opaque invalidation hints. It does not download photos or
/// construct an authenticated background Serverpod client.
@pragma('vm:entry-point')
Future<void> closeCallFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (!await FirebasePushBootstrap.ensureInitialized()) return;
  final preferences = await SharedPreferences.getInstance();
  await PushPendingWakeMarker.record(
    preferences,
    type: message.data['type'],
    version: message.data['version'],
  );
}

class PushPendingWakeMarker {
  static const key = 'closecall.push.pending_wake_version.v1';
  static const _highWaterKey = 'closecall.push.high_water_version.v1';
  // Delivery versions are database values, not timestamps. Keep malformed or
  // adversarial FCM data from becoming an unbounded SharedPreferences value.
  static const maxVersion = 9000000000000000;

  @visibleForTesting
  static int? parseVersion(Object? value) {
    final parsed = value is int ? value : int.tryParse('$value');
    if (parsed == null || parsed < 0 || parsed > maxVersion) return null;
    return parsed;
  }

  @visibleForTesting
  static int? merge(int? current, Object? incoming) {
    final version = parseVersion(incoming);
    if (version == null) return current;
    if (current == null || version > current) return version;
    return current;
  }

  static Future<bool> record(
    SharedPreferences preferences, {
    required Object? type,
    required Object? version,
  }) async {
    if (type != 'invalidation') return false;
    final current = preferences.getInt(key);
    final highWater = preferences.getInt(_highWaterKey);
    final merged = merge(highWater ?? current, version);
    if (merged == null || merged == highWater) return false;
    await preferences.setInt(_highWaterKey, merged);
    return preferences.setInt(key, merge(current, merged)!);
  }

  static Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(key);
    } catch (_) {
      // Push is a hint and local cleanup must never block sign-out.
    }
  }
}
