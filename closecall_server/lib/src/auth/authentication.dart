import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/anonymous.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

/// Cloud handles transactional email in staging/production; the official
/// development/test config logs codes only on the locally running server.
void configureAuthentication(Serverpod pod) {
  pod.initializeAuthServices(
    tokenManagerBuilders: [JwtConfigFromPasswords()],
    identityProviderBuilders: [
      ServerpodCloudEmailIdpConfig(appDisplayName: 'CloseCall'),
      AnonymousIdpConfig(
        onBeforeAnonymousAccountCreated:
            (session, {token, required transaction}) {
              requireDevelopmentAuthentication(session.serverpod.runMode);
            },
      ),
    ],
  );
}

/// Fail closed for staging, production, and any unrecognized run mode.
void requireDevelopmentAuthentication(String runMode) {
  if (runMode != 'development' && runMode != 'test') {
    throw StateError(
      'Anonymous authentication is restricted to development/test.',
    );
  }
}
