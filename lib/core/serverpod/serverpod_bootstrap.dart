import 'package:closecall_client/closecall_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

import '../../features/auth/data/auth_session.dart';
import '../../features/couple/data/serverpod_couple_repository.dart';
import '../../features/pairing/presentation/pairing_controller.dart';
import '../../features/auth/presentation/account_controller.dart';
import '../../features/media/data/serverpod_media_repository.dart';
import '../../features/media/presentation/media_controller.dart';
import '../config/app_config.dart';
import '../../features/widget/data/home_widget_service.dart';

/// One client and secure persisted session per configured app instance.
class ServerpodBootstrap {
  ServerpodBootstrap(String url) {
    client = Client(url)
      ..connectivityMonitor = FlutterConnectivityMonitor()
      ..authSessionManager = FlutterAuthSessionManager();
    session = ServerpodAuthSession(client);
    pairing = PairingController(
      allowDevGuest: AppConfig.allowDevGuest,
      session: session,
      repository: ServerpodCoupleRepository(
        client,
        userId: () => session.userId,
      ),
    );
    account = AccountController(session);
    media = MediaController(
      pairing: pairing,
      repository: ServerpodMediaRepository(client),
      applyLocalPhoto: (bytes) async {
        await HomeWidgetService.setPhoto(bytes);
      },
      clearLocalPhoto: HomeWidgetService.clear,
    );
  }

  late final Client client;
  late final ServerpodAuthSession session;
  late final PairingController pairing;
  late final AccountController account;
  late final MediaController media;

  void dispose() {
    media.dispose();
    account.dispose();
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
  Future<AccountState?> currentAccount() => client.account.currentAccount();

  @override
  Future<void> signInAnonymously() async {
    if (!AppConfig.allowDevGuest) {
      throw StateError('Development guest sign-in is disabled.');
    }
    final auth = await client.anonymousIdp.login();
    await client.auth.updateSignedInUser(auth);
  }

  @override
  Future<void> signOut() async {
    if (!await client.auth.signOutDevice()) {
      throw StateError(
        'Signed out locally, but server session revocation failed. '
        'Sign in again when online to verify your account.',
      );
    }
  }

  @override
  void dispose() {
    client.auth.authInfoListenable.removeListener(_changed);
    super.dispose();
  }
}
