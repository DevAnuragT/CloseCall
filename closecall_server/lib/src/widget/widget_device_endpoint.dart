import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'widget_device_service.dart';

class WidgetDeviceEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  // Issuance returns a bearer secret. Exclude request/response session logging.
  @override
  bool get logSessions => false;

  Future<WidgetDeviceCredential> issueCredential(
    Session session, {
    required String deviceId,
  }) => WidgetDeviceService().issue(
    session,
    session.authenticated!.userIdentifier,
    deviceId,
  );

  Future<void> revokeCredential(Session session, {required String deviceId}) =>
      WidgetDeviceService().revoke(
        session,
        session.authenticated!.userIdentifier,
        deviceId,
      );
}
