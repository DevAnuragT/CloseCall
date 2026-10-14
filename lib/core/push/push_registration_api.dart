import 'package:closecall_client/closecall_client.dart' as api;

/// The registration API deliberately has no read method and no token in its
/// response. FCM tokens are private installation credentials, not app state.
abstract interface class PushRegistrationApi {
  Future<void> registerDevice({
    required String token,
    required String deviceId,
    String? platform,
    String? appVersion,
  });

  Future<void> revokeDevice({required String deviceId, required String token});
}

class ServerpodPushRegistrationApi implements PushRegistrationApi {
  ServerpodPushRegistrationApi(this.client);

  final api.Client client;

  @override
  Future<void> registerDevice({
    required String token,
    required String deviceId,
    String? platform,
    String? appVersion,
  }) => client.push.registerDevice(
    token: token,
    deviceId: deviceId,
    platform: platform,
    appVersion: appVersion,
  );

  @override
  Future<void> revokeDevice({
    required String deviceId,
    required String token,
  }) => client.push.revokeDevice(deviceId: deviceId, token: token);
}
