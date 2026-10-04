import 'package:flutter/material.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import 'app/app_shell.dart';
import 'core/config/app_config.dart';
import 'core/serverpod/serverpod_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  void _connect() {
    try {
      _backend = ServerpodBootstrap(widget.serverUrl);
      _error = null;
      _backend!.pairing.initialize();
    } catch (error) {
      _error = error;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backend?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backend?.schedules.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Text('Serverpod setup failed: $_error'),
              TextButton(
                onPressed: () => setState(_connect),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final backend = _backend!;
    return AuthGate(
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
      signedInBuilder: (_) => AppShell(
        pairing: backend.pairing,
        account: backend.account,
        media: backend.media,
        schedules: backend.schedules,
      ),
    );
  }
}
