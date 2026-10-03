/// Build-time configuration; no secrets file or bundled .env is required.
class AppConfig {
  static const allowDevGuest = bool.fromEnvironment('ALLOW_DEV_GUEST');
  AppConfig({String serverpodUrl = ''})
    : serverpodUrl = _normalizeUrl(serverpodUrl);

  factory AppConfig.fromEnvironment() =>
      AppConfig(serverpodUrl: const String.fromEnvironment('SERVERPOD_URL'));

  /// null means intentional, offline demo mode. Invalid URLs throw instead.
  final String? serverpodUrl;
  bool get isDemo => serverpodUrl == null;

  static String? _normalizeUrl(String raw) {
    if (raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'SERVERPOD_URL must be an absolute HTTP(S) URL without credentials, '
        'query parameters, or a fragment.',
      );
    }
    final url = uri.toString();
    return url.endsWith('/') ? url : '$url/';
  }

  // Retained only for explicitly invoked legacy Supabase code. Startup never
  // reads these or initializes Supabase.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
