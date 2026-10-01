import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app_shell.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load local secrets if present; absence just means mock-data mode.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No .env on this machine — run with mock data.
  }
  // No-ops when Supabase config isn't provided, so the app still runs with
  // mock data during early development.
  await SupabaseBootstrap.ensureInitialized();
  runApp(const CloseCallApp());
}

class CloseCallApp extends StatelessWidget {
  const CloseCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloseCall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
