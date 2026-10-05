import 'package:closecall_client/closecall_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

import '../../features/auth/data/auth_session.dart';
import '../../features/auth/data/session_restoration.dart';
import '../../features/couple/data/serverpod_couple_repository.dart';
import '../../features/pairing/presentation/pairing_controller.dart';
import '../../features/auth/presentation/account_controller.dart';
import '../../features/media/data/serverpod_media_repository.dart';
import '../../features/media/data/media_client.dart';
import '../../features/media/presentation/media_controller.dart';
import '../config/app_config.dart';
import '../../features/widget/data/home_widget_service.dart';
import '../../features/widget/data/local_widget_writer.dart';
import '../../features/widget/data/native_widget_timeline.dart';
import '../../features/widget/data/serverpod_schedule_repository.dart';
import '../../features/widget/data/shared_preferences_widget_consent_store.dart';
import '../../features/widget/presentation/schedule_controller.dart';
import '../permissions/notification_permission_service.dart';
import '../push/push_registration_api.dart';
import '../push/push_registration_service.dart';

/// One secure persisted session, with separate regular and media transports.
class ServerpodBootstrap {
  ServerpodBootstrap(String url) {
    client = Client(url)..connectivityMonitor = FlutterConnectivityMonitor();
    client.authSessionManager = createRestorableAuthManager(client);
    mediaClient = createMediaClient(url, authKeyProvider: client.auth);
    session = ServerpodAuthSession(client);
    pairing = PairingController(
      allowDevGuest: AppConfig.allowDevGuest,
      session: session,
      repository: ServerpodCoupleRepository(
        client,
        userId: () => session.userId,
      ),
    );
    push = PushRegistrationService(
      pairing: pairing,
      permissions: AndroidWidgetPermissionService(),
      api: ServerpodPushRegistrationApi(client),
      platform: 'android',
      appVersion: '1.0.0+1',
    );
    account = AccountController(session);
    final mediaRepository = ServerpodMediaRepository(mediaClient);
    final writer = LocalWidgetWriter(
      applyPhoto: (bytes) async {
        await HomeWidgetService.setPhoto(bytes, preserveTimeline: true);
      },
      clearPhoto: HomeWidgetService.clear,
      timeline: const AndroidWidgetTimeline(),
    );
    schedules = ScheduleController(
      pairing: pairing,
      repository: ServerpodScheduleRepository(client),
      mediaRepository: mediaRepository,
      localWriter: writer,
      consentStore: SharedPreferencesWidgetConsentStore(),
    );
    media = MediaController(
      pairing: pairing,
      repository: mediaRepository,
      applyLocalPhoto: schedules.applyManualPhoto,
      sendAsset: client.widgetSchedule.sendAsset,
      // ScheduleController owns shared auth/couple cleanup and the native queue.
    );
  }

  late final Client client;
  late final Client mediaClient;
  late final ServerpodAuthSession session;
  late final PairingController pairing;
  late final PushRegistrationService push;
  late final AccountController account;
  late final MediaController media;
  late final ScheduleController schedules;

  void dispose() {
    push.dispose();
    media.dispose();
    schedules.dispose();
    account.dispose();
    pairing.dispose();
    session.dispose();
    mediaClient.close();
    client.close();
  }
}

class ServerpodAuthSession extends AuthSession {
  ServerpodAuthSession(this.client)
    : _restoration = SessionRestoration(client.auth) {
    client.auth.authInfoListenable.addListener(_changed);
  }

  final Client client;
  final SessionRestoration _restoration;

  @override
  String? get userId => client.auth.authInfo?.authUserId.toString();

  void _changed() => notifyListeners();

  @override
  Future<void> initialize() => _restoration.initialize();

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
  Future<void> signOut() => _restoration.signOut();

  @override
  void dispose() {
    _restoration.dispose();
    client.auth.authInfoListenable.removeListener(_changed);
    super.dispose();
  }
}
