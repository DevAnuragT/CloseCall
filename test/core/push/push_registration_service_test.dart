import 'dart:async';

import 'package:closecall/core/permissions/notification_permission_service.dart';
import 'package:closecall/core/push/push_registration_api.dart';
import 'package:closecall/core/push/push_registration_service.dart';
import 'package:closecall/features/pairing/presentation/pairing_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/live_fakes.dart';

class _Permissions implements WidgetPermissionService {
  NotificationAccess access = NotificationAccess.granted;
  int requests = 0;

  @override
  Future<NotificationAccess> notificationStatus() async => access;
  @override
  Future<NotificationAccess> requestNotifications() async {
    requests++;
    return access;
  }

  @override
  Future<bool> hasInstalledWidget() async => false;
  @override
  Future<bool> canPinWidget() async => false;
  @override
  Future<void> requestPinWidget() async {}
  @override
  Future<bool> openSettings() async => false;
}

class _Messaging implements PushMessagingClient {
  final refresh = StreamController<String>.broadcast();
  String? token = 'opaque-token-12345678901234567890';
  Completer<String?>? pending;
  int gets = 0;

  @override
  Future<String?> getToken() {
    gets++;
    return pending?.future ?? Future.value(token);
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  Future<void> dispose() => refresh.close();
}

class _Api implements PushRegistrationApi {
  final registrations = <String>[];
  final revocations = <String>[];

  @override
  Future<void> registerDevice({
    required String token,
    required String deviceId,
    String? platform,
    String? appVersion,
  }) async => registrations.add('$deviceId:$token');

  @override
  Future<void> revokeDevice({
    required String deviceId,
    required String token,
  }) async => revocations.add(deviceId);
}

class _Identity implements PushDeviceIdentityStore {
  @override
  Future<String> deviceId() async => 'device';
}

Future<PairingController> _pairing({String? identity = 'me'}) async {
  final auth = FakeAuth()..change(identity);
  final pairing = PairingController(session: auth, repository: FakeCouples());
  await pairing.initialize();
  return pairing;
}

PushRegistrationService _service(
  PairingController pairing,
  _Permissions permissions,
  _Api api,
  _Messaging messaging, {
  Future<bool> Function()? bootstrap,
}) => PushRegistrationService(
  pairing: pairing,
  permissions: permissions,
  api: api,
  messaging: messaging,
  bootstrap: bootstrap ?? (() async => true),
  deviceIdentity: _Identity(),
);

void main() {
  test('pending wake marker keeps greatest valid version only', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    expect(PushPendingWakeMarker.merge(null, '8'), 8);
    expect(PushPendingWakeMarker.merge(8, '7'), 8);
    expect(PushPendingWakeMarker.merge(8, '8'), 8);
    expect(PushPendingWakeMarker.merge(8, '9'), 9);
    expect(
      PushPendingWakeMarker.merge(9, PushPendingWakeMarker.maxVersion + 1),
      9,
    );
    expect(
      await PushPendingWakeMarker.record(
        preferences,
        type: 'heartbeat',
        version: 10,
      ),
      isFalse,
    );
    expect(
      await PushPendingWakeMarker.record(
        preferences,
        type: 'invalidation',
        version: '8',
      ),
      isTrue,
    );
    expect(
      await PushPendingWakeMarker.record(
        preferences,
        type: 'invalidation',
        version: '7',
      ),
      isFalse,
    );
    expect(preferences.getInt(PushPendingWakeMarker.key), 8);
  });

  test('pending wake marker can be cleared at an identity boundary', () async {
    SharedPreferences.setMockInitialValues({PushPendingWakeMarker.key: 42});
    expect(
      (await SharedPreferences.getInstance()).getInt(PushPendingWakeMarker.key),
      42,
    );
    await PushPendingWakeMarker.clear();
    expect(
      (await SharedPreferences.getInstance()).getInt(PushPendingWakeMarker.key),
      isNull,
    );
  });

  test(
    'denied notifications and unavailable Firebase never block pairing',
    () async {
      final pairing = await _pairing();
      final permissions = _Permissions()..access = NotificationAccess.denied;
      final api = _Api();
      final messaging = _Messaging();
      final service = _service(pairing, permissions, api, messaging);
      service.start();
      await service.reconcile();
      expect(api.registrations, isEmpty);
      expect(permissions.requests, 0);
      expect(messaging.gets, 0);
      service.dispose();
      await messaging.dispose();
      pairing.dispose();
    },
  );

  test(
    'Firebase unavailable and incomplete pairing are non-blocking',
    () async {
      final pairing = await _pairing();
      final permissions = _Permissions();
      final api = _Api();
      final messaging = _Messaging();
      final unavailable = _service(
        pairing,
        permissions,
        api,
        messaging,
        bootstrap: () async => false,
      );
      unavailable.start();
      await unavailable.reconcile();
      expect(api.registrations, isEmpty);
      expect(messaging.gets, 0);
      unavailable.dispose();
      await messaging.dispose();
      pairing.dispose();

      final auth = FakeAuth()..change('me');
      final repository = FakeCouples()..couple = null;
      final unpaired = PairingController(session: auth, repository: repository);
      await unpaired.initialize();
      final secondApi = _Api();
      final secondMessaging = _Messaging();
      final blocked = _service(
        unpaired,
        permissions,
        secondApi,
        secondMessaging,
      );
      blocked.start();
      await blocked.reconcile();
      expect(secondApi.registrations, isEmpty);
      blocked.dispose();
      await secondMessaging.dispose();
      unpaired.dispose();
      auth.dispose();
    },
  );

  test(
    'registers only for a complete paired granted scope and is idempotent',
    () async {
      final pairing = await _pairing();
      final permissions = _Permissions();
      final api = _Api();
      final messaging = _Messaging();
      final service = _service(pairing, permissions, api, messaging);
      service.start();
      await service.reconcile();
      expect(api.registrations, ['device:opaque-token-12345678901234567890']);
      await service.reconcile();
      expect(api.registrations, ['device:opaque-token-12345678901234567890']);
      messaging.refresh.add('rotated-token-12345678901234567890');
      await Future<void>.delayed(Duration.zero);
      expect(api.registrations, [
        'device:opaque-token-12345678901234567890',
        'device:rotated-token-12345678901234567890',
      ]);
      service.dispose();
      await messaging.dispose();
      pairing.dispose();
    },
  );

  test('scope change revokes and late token result is discarded', () async {
    final pairing = await _pairing();
    final permissions = _Permissions();
    final api = _Api();
    final messaging = _Messaging()..pending = Completer<String?>();
    final service = _service(pairing, permissions, api, messaging);
    service.start();
    final pending = service.reconcile();
    await Future<void>.delayed(Duration.zero);
    (pairing.session as FakeAuth).change(null);
    messaging.pending!.complete('late-token');
    await pending;
    expect(api.registrations, isEmpty);
    expect(api.revocations, isEmpty);
    service.dispose();
    await messaging.dispose();
    pairing.dispose();
  });
}
