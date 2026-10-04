// Standalone tests (no package:test dependency):
// dart run test/smoke_production_test.dart
import 'dart:async';
import 'dart:convert';

import 'package:closecall_client/closecall_client.dart';
import 'package:http/http.dart' as http;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart';

import '../tool/smoke_production.dart';

void check(bool condition, String name) {
  if (!condition) throw StateError(name);
}

class FakeTransport extends http.BaseClient {
  FakeTransport(this.respond);

  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  final requests = <http.BaseRequest>[];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    check(!request.headers.containsKey('authorization'), 'no_authorization');
    return respond(request);
  }

  @override
  void close() => closed = true;
}

class UnexpectedAuthProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async => null;
}

http.StreamedResponse response(
  int code, [
  String body = 'private_error_body',
]) => http.StreamedResponse(Stream.value(utf8.encode(body)), code);

Future<void> main() async {
  check(
    validateProductionApiUrl('https://api.example.invalid') ==
        'https://api.example.invalid/',
    'normalizes_origin',
  );
  check(
    validateProductionApiUrl('https://api.example.invalid:8443/') ==
        'https://api.example.invalid:8443/',
    'explicit_https_port',
  );
  final invalidUrls = [
    '',
    'api.example.invalid',
    'http://api.example.invalid',
    'https:///missing-host',
    'https://user:private_credential@api.example.invalid/',
    'https://@api.example.invalid/',
    'https://api.example.invalid/?token=private_credential',
    'https://api.example.invalid/?',
    'https://api.example.invalid/#private_credential',
    'https://api.example.invalid/#',
    'https://api.example.invalid/private_credential',
    ' https://api.example.invalid/',
    'https://api.example.invalid/\n',
    'https://api.example.invalid:0/',
    'https://api.example.invalid:65536/',
    'https://api.example.invalid:bad/',
    'https://[broken',
  ];
  for (final (index, url) in invalidUrls.indexed) {
    var rejected = false;
    try {
      validateProductionApiUrl(url);
    } on FormatException catch (error) {
      rejected = error.message == 'invalid_api_url' && error.source == null;
    }
    check(rejected, 'rejects_invalid_url_without_echo_$index');
  }

  Future<void> scenario(
    String name,
    Future<http.StreamedResponse> Function(http.BaseRequest) respond,
    bool expected, {
    int expectedRequests = 1,
    Duration timeout = productionSmokeTimeout,
  }) async {
    final transport = FakeTransport(respond);
    final lines = <String>[];
    final passed = await runProductionSmoke(
      Client(
        'https://api.example.invalid/',
        connectionTimeout: timeout,
        httpClientOverride: transport,
      ),
      timeout: timeout,
      report: lines.add,
    );
    check(passed == expected, name);
    check(transport.closed, '${name}_closes_client');
    check(transport.requests.length == expectedRequests, '${name}_fail_fast');
    check(
      lines.every(
        (line) =>
            RegExp(
              r'^[A-Za-z0-9_.]+ (PASS|FAIL) [A-Za-z0-9_]+$',
            ).hasMatch(line) &&
            !line.contains('private_'),
      ),
      '${name}_sanitized_output',
    );
    if (expectedRequests == 7) {
      check(
        transport.requests.map((r) => r.url.path).join(',') ==
            '/account/currentAccount,/pairing/currentCouple,/media/listAssets,'
                '/widgetSchedule/currentTimeline,/widgetSchedule/partnerTimeline,'
                '/media/downloadPhoto,/anonymousIdp/login',
        '${name}_only_expected_rpcs',
      );
      final download = transport.requests[5] as http.Request;
      check(
        jsonDecode(download.body)['assetId'] == productionSmokeDummyAssetId,
        '${name}_dummy_uuid',
      );
      final login = transport.requests.last as http.Request;
      check(jsonDecode(login.body)['token'] == null, '${name}_no_login_token');
    }
  }

  await scenario(
    'expected_denials',
    (request) async =>
        response(request.url.path == '/anonymousIdp/login' ? 500 : 401),
    true,
    expectedRequests: 7,
  );
  for (final code in [403, 404, 500, 502]) {
    await scenario('rejects_http_$code', (_) async => response(code), false);
  }
  await scenario(
    'rejects_network_error',
    (_) async => throw http.ClientException('private_credential'),
    false,
  );
  await scenario(
    'rejects_malformed_success',
    (_) async => response(200, 'private_invalid_json'),
    false,
  );
  await scenario(
    'rejects_unauthorized_rpc_success',
    (request) async => request.url.path == '/pairing/currentCouple'
        ? response(200, 'null')
        : response(401),
    false,
    expectedRequests: 2,
  );
  await scenario(
    'rejects_timeout',
    (_) => Completer<http.StreamedResponse>().future,
    false,
    timeout: const Duration(milliseconds: 20),
  );
  for (final code in [401, 403, 404, 502]) {
    await scenario(
      'rejects_wrong_login_$code',
      (request) async =>
          response(request.url.path == '/anonymousIdp/login' ? code : 401),
      false,
      expectedRequests: 7,
    );
  }
  await scenario(
    'rejects_login_network_error',
    (request) async => request.url.path == '/anonymousIdp/login'
        ? throw http.ClientException('private_credential')
        : response(401),
    false,
    expectedRequests: 7,
  );
  await scenario(
    'rejects_login_timeout',
    (request) => request.url.path == '/anonymousIdp/login'
        ? Completer<http.StreamedResponse>().future
        : Future.value(response(401)),
    false,
    expectedRequests: 7,
    timeout: const Duration(milliseconds: 20),
  );
  final auth = AuthSuccess(
    authStrategy: 'jwt',
    token: 'private_access_token',
    refreshToken: 'private_refresh_token',
    authUserId: UuidValue.fromString(productionSmokeDummyAssetId),
    scopeNames: {},
  );
  await scenario(
    'rejects_unexpected_auth_success',
    (request) async => request.url.path == '/anonymousIdp/login'
        ? response(200, SerializationManager.encode(auth))
        : response(401),
    false,
    expectedRequests: 7,
  );
  final authenticatedTransport = FakeTransport((_) async => response(401));
  final authenticatedClient = Client(
    'https://api.example.invalid/',
    httpClientOverride: authenticatedTransport,
  )..authKeyProvider = UnexpectedAuthProvider();
  final authLines = <String>[];
  check(
    !await runProductionSmoke(authenticatedClient, report: authLines.add) &&
        authenticatedTransport.closed &&
        authenticatedTransport.requests.isEmpty &&
        authLines.single == 'client FAIL AuthKeyProviderPresent',
    'rejects_authenticated_client_before_any_request',
  );
  print('smoke_production_tests PASS');
}
