import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/anonymous.dart';

/// Anonymous accounts are only a local development/test bootstrap.
/// A recoverable identity provider must be configured before a real deployment.
void configureAuthentication(Serverpod pod) {
  pod.initializeAuthServices(
    tokenManagerBuilders: [JwtConfigFromPasswords()],
    identityProviderBuilders: [
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
