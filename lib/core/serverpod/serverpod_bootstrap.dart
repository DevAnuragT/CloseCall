import 'package:closecall_client/closecall_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

import '../../features/auth/data/auth_session.dart';
import '../../features/couple/data/serverpod_couple_repository.dart';
import '../../features/pairing/presentation/pairing_controller.dart';

/// One client and secure persisted session per configured app instance.
class ServerpodBootstrap {
  ServerpodBootstrap(String url) {
    client = Client(url)
      ..connectivityMonitor = FlutterConnectivityMonitor()
      ..authSessionManager = FlutterAuthSessionManager();
    session = ServerpodAuthSession(client);
    pairing = PairingController(
      session: session,
      repository: ServerpodCoupleRepository(
        client,
        userId: () => session.userId,
      ),
    );
  }

  late final Client client;
  late final ServerpodAuthSession session;
  late final PairingController pairing;

  void dispose() {
    pairing.dispose();
    session.dispose();
    client.close();
  }
}

class ServerpodAuthSession extends AuthSession {
  ServerpodAuthSession(this.client) {
    client.auth.authInfoListenable.addListener(_changed);
  }

  final Client client;

  @override
  String? get userId => client.auth.authInfo?.authUserId.toString();

  void _changed() => notifyListeners();

  @override
  Future<void> initialize() async {
    if (!await client.auth.initialize()) {
      throw StateError(
        'Unable to validate the server session. Retry when online.',
      );
    }
  }

  @override
  Future<void> signInAnonymously() async {
    final auth = await client.anonymousIdp.login();
    await client.auth.updateSignedInUser(auth);
  }

  @override
  Future<void> signOut() async {
    if (!await client.auth.signOutDevice()) {
      throw StateError(
        'Signed out locally, but server session revocation failed. '
        'The guest account cannot be recovered after local sign-out.',
      );
    }
  }

  @override
  void dispose() {
    client.auth.authInfoListenable.removeListener(_changed);
    super.dispose();
  }
}
