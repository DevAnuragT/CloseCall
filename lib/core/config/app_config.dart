import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration, loaded from a gitignored `.env` file at startup
/// (see `.env.example` for the keys). Nothing sensitive lives in source
/// control.
///
/// The Supabase *publishable/anon* key is safe to ship in a client **only
/// because every table is protected by Row Level Security** (see
/// `supabase/migrations`). It is not a service-role key.
abstract final class AppConfig {
  static String _get(String key) =>
      dotenv.isInitialized ? (dotenv.maybeGet(key) ?? '') : '';

  static String get supabaseUrl => _get('SUPABASE_URL');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');

  /// True when both Supabase values were provided in `.env`.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
