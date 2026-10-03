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
import '../../features/widget/data/local_widget_writer.dart';
import '../../features/widget/data/serverpod_schedule_repository.dart';
import '../../features/widget/presentation/schedule_controller.dart';

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
    final mediaRepository = ServerpodMediaRepository(client);
    final writer = LocalWidgetWriter(
      applyPhoto: (bytes) async {
        await HomeWidgetService.setPhoto(bytes);
      },
      clearPhoto: HomeWidgetService.clear,
    );
    schedules = ScheduleController(
      pairing: pairing,
      repository: ServerpodScheduleRepository(client),
      mediaRepository: mediaRepository,
      localWriter: writer,
    );
    media = MediaController(
      pairing: pairing,
      repository: mediaRepository,
      applyLocalPhoto: schedules.applyManualPhoto,
      // ScheduleController owns shared auth/couple cleanup and the native queue.
    );
  }

  late final Client client;
  late final ServerpodAuthSession session;
  late final PairingController pairing;
  late final AccountController account;
  late final MediaController media;
  late final ScheduleController schedules;

  void dispose() {
    media.dispose();
    schedules.dispose();
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
