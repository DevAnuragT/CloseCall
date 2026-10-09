import 'package:closecall_client/closecall_client.dart' as api;

import 'widget_read_credential.dart';

abstract interface class WidgetReadCredentialApi {
  Future<WidgetReadCredential> issueCredential({required String deviceId});
  Future<void> revokeCredential({required String deviceId});
}

/// Uses the foreground shared authenticated client. Background code must never
/// construct/refresh a user session to renew this limited credential.
class ServerpodWidgetReadCredentialApi implements WidgetReadCredentialApi {
  ServerpodWidgetReadCredentialApi(this.client);
  final api.Client client;

  @override
  Future<WidgetReadCredential> issueCredential({
    required String deviceId,
  }) async {
    final result = await client.widgetDevice.issueCredential(
      deviceId: deviceId,
    );
    return WidgetReadCredential(
      credential: result.credential,
      deviceId: result.deviceId,
      userId: result.userId,
      coupleId: result.coupleId,
      expiresAt: result.expiresAt.toUtc(),
    );
  }

  @override
  Future<void> revokeCredential({required String deviceId}) =>
      client.widgetDevice.revokeCredential(deviceId: deviceId);
}
