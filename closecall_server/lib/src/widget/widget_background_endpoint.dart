import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'widget_device_service.dart';

/// Explicit bearer authorization, independent of the interactive login token.
/// This capability has no library, partner-view, upload, or mutation methods.
class WidgetBackgroundEndpoint extends Endpoint {
  @override
  bool get logSessions => false;

  Future<WidgetTimeline> currentTimeline(
    Session session, {
    required String credential,
  }) => WidgetDeviceService().timeline(session, credential);

  Future<ByteData> downloadPhoto(
    Session session, {
    required String credential,
    required String assetId,
  }) => WidgetDeviceService().download(session, credential, assetId);
}
