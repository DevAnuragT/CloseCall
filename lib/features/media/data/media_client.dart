import 'package:closecall_client/closecall_client.dart';

/// Serverpod bounds the entire POST response, including transfer and backend
/// work. Media needs more time than the regular client's 20-second RPC budget.
const mediaRequestTimeout = Duration(seconds: 90);

/// A separate transport, not a separate session. Pass the primary client's
/// live auth provider: copying a token would survive sign-out/account changes,
/// and attaching authSessionManager here would rebind its refresh caller.
/// The owner must close this client alongside the primary client.
Client createMediaClient(
  String url, {
  required ClientAuthKeyProvider authKeyProvider,
  Duration connectionTimeout = mediaRequestTimeout,
}) =>
    Client(url, connectionTimeout: connectionTimeout)
      ..authKeyProvider = authKeyProvider;
