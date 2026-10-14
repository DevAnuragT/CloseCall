import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import 'app/app_shell.dart';
import 'core/config/app_config.dart';
import 'core/permissions/background_reliability_service.dart';
import 'core/permissions/background_setup_prompt.dart';
import 'core/permissions/notification_permission_service.dart';
import 'core/permissions/permission_onboarding.dart';
import 'core/permissions/widget_readiness_controller.dart';
import 'core/serverpod/serverpod_bootstrap.dart';
import 'core/push/push_registration_service.dart';
import 'core/push/moment_notification_presenter.dart';
import 'core/push/push_notification_payload.dart';
import 'core/theme/app_theme.dart';
import 'features/widget/data/native_widget_timeline.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/widget/presentation/photo_sync_settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FCM carries only an opaque wake hint. The Android manifest receiver owns
  // the limited device-credential fetch; this Dart callback remains a
  // bounded marker fallback and never restores a user session.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    FirebaseMessaging.onBackgroundMessage(
      closeCallFirebaseMessagingBackgroundHandler,
    );
  }
  // Invalid configured URLs remain an explicit startup error, never demo mode.
  try {
    runApp(CloseCallApp(config: AppConfig.fromEnvironment()));
  } on FormatException catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$error'),
            ),
          ),
        ),
      ),
    );
  }
}

class CloseCallApp extends StatelessWidget {
  const CloseCallApp({super.key, this.config});
  final AppConfig? config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloseCall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: config?.serverpodUrl == null
          ? const AppShell()
          : _LiveApp(serverUrl: config!.serverpodUrl!),
    );
  }
}

class _LiveApp extends StatefulWidget {
  const _LiveApp({required this.serverUrl});
  final String serverUrl;

  @override
  State<_LiveApp> createState() => _LiveAppState();
}

class _LiveAppState extends State<_LiveApp> with WidgetsBindingObserver {
  ServerpodBootstrap? _backend;
  WidgetReadinessController? _readiness;
  StreamSubscription<RemoteMessage>? _foregroundMessages;
  StreamSubscription<RemoteMessage>? _openedMessages;
  MomentNotificationPresenter? _momentPresenter;
  String? _pendingMomentNotificationId;
  String? _momentNotificationId;
  int _momentNotificationRevision = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  void _connect() {
    try {
      _stopMomentNotifications();
      _readiness?.bindPairing(null);
      _readiness?.dispose();
      _readiness = null;
      _backend?.dispose();
      _backend = null;
      _backend = ServerpodBootstrap(widget.serverUrl);
      unawaited(
        AndroidWidgetTimeline.configureBackgroundServerUrl(widget.serverUrl),
      );
      _error = null;
      final foreground =
          WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      _backend!.pairing.enableForegroundSync(foreground: foreground);
      _backend!.schedules.setForeground(foreground);
      _backend!.mood.setForeground(foreground);
      _backend!.moments.setForeground(foreground);
      _backend!.reminders.setForeground(foreground);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        _readiness = WidgetReadinessController(
          service: AndroidWidgetPermissionService(),
          promptStore: SharedPreferencesPermissionPromptStore(),
          background: AndroidBackgroundReliabilityService(),
          backgroundStore: SharedPreferencesBackgroundSetupStore(),
        );
        _readiness!.addListener(_permissionReadinessChanged);
        _readiness!.bindPairing(_backend!.pairing);
        _readiness!.setForeground(foreground);
        _readiness!.initialize();
      }
      _backend!.pairing.initialize();
      _backend!.pairing.addListener(_flushMomentNotification);
      _backend!.mood.start();
      _backend!.moments.start();
      _backend!.widgetCredentials.start();
      _backend!.push.start();
      _configureMomentNotifications(_backend!);
    } catch (error) {
      _error = error;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readiness?.removeListener(_permissionReadinessChanged);
    _readiness?.bindPairing(null);
    _readiness?.dispose();
    _stopMomentNotifications();
    _backend?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backend?.pairing.setForeground(state == AppLifecycleState.resumed);
    _backend?.schedules.setForeground(state == AppLifecycleState.resumed);
    _backend?.mood.setForeground(state == AppLifecycleState.resumed);
    _backend?.moments.setForeground(state == AppLifecycleState.resumed);
    _backend?.reminders.setForeground(state == AppLifecycleState.resumed);
    _readiness?.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      _readiness?.refresh();
      unawaited(_backend?.push.reconcile());
      unawaited(_backend?.widgetCredentials.reconcile());
    }
  }

  void _permissionReadinessChanged() {
    if (_readiness?.notificationAccess == NotificationAccess.granted) {
      unawaited(_backend?.push.reconcile());
    }
  }

  void _configureMomentNotifications(ServerpodBootstrap backend) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    unawaited(() async {
      if (!await FirebasePushBootstrap.ensureInitialized() ||
          !mounted ||
          !identical(_backend, backend)) {
        return;
      }
      _momentPresenter = MomentNotificationPresenter(
        onTap: (momentId) {
          _receiveMomentPayload(momentId);
        },
      );
      await _momentPresenter!.initialize();
      _foregroundMessages = FirebaseMessaging.onMessage.listen(
        (message) => _receiveMomentNotification(message, showBanner: true),
        onError: (_) {},
      );
      _openedMessages = FirebaseMessaging.onMessageOpenedApp.listen(
        _receiveMomentNotification,
        onError: (_) {},
      );
      try {
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) _receiveMomentNotification(initial);
      } catch (_) {
        // Push is optional; authentication and the private shell remain usable.
      }
    }());
  }

  void _receiveMomentNotification(
    RemoteMessage message, {
    bool showBanner = false,
  }) {
    final payload = PushNotificationPayload.parse(message.data);
    if (payload == null) return;

    final presenter = _momentPresenter;
    switch (payload.type) {
      case PushNotificationType.momentCreated:
        _receiveMomentPayload(payload.id);
        if (showBanner && presenter != null) {
          unawaited(presenter.show(payload.id));
        }
      case PushNotificationType.reminderCreated:
        if (showBanner && presenter != null) {
          unawaited(presenter.showReminder(payload.id));
        }
    }
  }

  void _receiveMomentPayload(String id) {
    _pendingMomentNotificationId = id;
    _flushMomentNotification();
  }

  void _flushMomentNotification() {
    final backend = _backend;
    final id = _pendingMomentNotificationId;
    final couple = backend?.pairing.couple;
    if (backend == null ||
        id == null ||
        !backend.pairing.hasLoadedPairing ||
        backend.pairing.userId == null ||
        couple?.isComplete != true ||
        !couple!.memberIds.contains(backend.pairing.userId)) {
      return;
    }
    _pendingMomentNotificationId = null;
    if (!mounted) return;
    setState(() {
      _momentNotificationId = id;
      _momentNotificationRevision++;
    });
  }

  void _stopMomentNotifications() {
    _backend?.pairing.removeListener(_flushMomentNotification);
    unawaited(_foregroundMessages?.cancel() ?? Future<void>.value());
    unawaited(_openedMessages?.cancel() ?? Future<void>.value());
    _foregroundMessages = null;
    _openedMessages = null;
    _momentPresenter = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [Text('Serverpod setup failed: $_error')]),
        ),
      );
    }
    final backend = _backend!;
    final gate = AuthGate(
      pairing: backend.pairing,
      emailBuilder: (_) => EmailSignInWidget(
        client: backend.client,
        startScreen: EmailFlowScreen.login,
        passwordRequirements: [
          PasswordRequirement.minLength(8),
          PasswordRequirement.containsUppercase(),
          PasswordRequirement.containsLowercase(),
          PasswordRequirement.containsNumber(),
          PasswordRequirement.containsSpecialCharacter(),
        ],
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Email authentication failed: $error')),
            );
          }
        },
      ),
      signedInBuilder: (_) {
        final child = PartnerPhotoSetupCoordinator(
          schedules: backend.schedules,
          readiness: _readiness,
          child: AppShell(
            pairing: backend.pairing,
            mood: backend.mood,
            moments: backend.moments,
            reminders: backend.reminders,
            account: backend.account,
            media: backend.media,
            schedules: backend.schedules,
            readiness: _readiness,
            momentNotificationId: _momentNotificationId,
            momentNotificationRevision: _momentNotificationRevision,
          ),
        );
        return _readiness == null
            ? child
            : PermissionOnboarding(
                controller: _readiness!,
                child: BackgroundSetupPrompt(
                  controller: _readiness!,
                  child: child,
                ),
              );
      },
    );
    return gate;
  }
}
