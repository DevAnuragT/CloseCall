import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Initializes the Supabase client once at startup. Safe to call when config
/// is missing — it simply no-ops so the app (and widget tests) still run with
/// mock data until credentials are wired in.
abstract final class SupabaseBootstrap {
  static bool _initialized = false;

  static bool get isReady => _initialized;

  static Future<void> ensureInitialized() async {
    if (_initialized || !AppConfig.hasSupabase) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // The user's key is a `sb_publishable_...` key — the current API.
      publishableKey: AppConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  /// The shared client. Only valid after [ensureInitialized] succeeds.
  static SupabaseClient get client => Supabase.instance.client;
}
