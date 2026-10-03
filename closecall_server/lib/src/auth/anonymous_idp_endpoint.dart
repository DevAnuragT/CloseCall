import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/providers/anonymous.dart';

import 'authentication.dart';

/// Development/test only. The callback also guards non-endpoint creation paths.
class AnonymousIdpEndpoint extends AnonymousIdpBaseEndpoint {
  @override
  Future<AuthSuccess> login(Session session, {String? token}) async {
    requireDevelopmentAuthentication(session.serverpod.runMode);
    return super.login(session, token: token);
  }
}
