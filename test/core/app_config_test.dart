import 'dart:io';

import 'package:closecall/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing URL explicitly selects demo without an env file', () {
    expect(AppConfig().isDemo, isTrue);
    expect(AppConfig(serverpodUrl: '  ').serverpodUrl, isNull);
  });

  test('HTTP(S) URLs are trimmed and normalized for Serverpod', () {
    expect(
      AppConfig(serverpodUrl: ' http://localhost:8080 ').serverpodUrl,
      'http://localhost:8080/',
    );
    expect(
      AppConfig(serverpodUrl: 'https://api.example.com/rpc/').serverpodUrl,
      'https://api.example.com/rpc/',
    );
  });

  test('invalid configured URLs never silently select demo', () {
    for (final url in [
      'localhost:8080',
      'ftp://example.com',
      'https://',
      'https://user:secret@example.com',
      'https://example.com?key=value',
      'https://example.com#fragment',
    ]) {
      expect(() => AppConfig(serverpodUrl: url), throwsFormatException);
    }
  });

  test('app has no mandatory env asset or dotenv dependency', () {
    final manifest = File('pubspec.yaml').readAsStringSync();
    expect(manifest, isNot(contains('flutter_dotenv')));
    expect(manifest, isNot(contains('- .env')));
    final startup = File('lib/main.dart').readAsStringSync();
    expect(startup, isNot(contains('SupabaseBootstrap')));
    expect(startup, isNot(contains('dotenv')));
  });
}
