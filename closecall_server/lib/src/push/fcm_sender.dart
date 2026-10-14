import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// The only FCM result details used by the outbox. Response bodies are parsed
/// for classification and are never logged or returned to callers.
enum FcmSendStatus { sent, invalidToken, transientFailure, permanentFailure }

class FcmSendResult {
  const FcmSendResult(this.status);

  final FcmSendStatus status;
}

abstract interface class FcmSender {
  Future<FcmSendResult> send({required String token, required int version});
}

/// Separate capability for user-visible Moment notifications. Keeping this
/// interface independent means existing invalidation sender fakes remain
/// source-compatible and cannot accidentally receive private Moment data.
abstract interface class MomentFcmSender {
  Future<FcmSendResult> sendMoment({
    required String token,
    required String momentId,
    required String eventType,
  });
}

/// Separate capability for user-visible Reminder notifications. Keeping this
/// interface independent prevents widget invalidation sends from carrying
/// reminder identifiers or notification text.
abstract interface class ReminderFcmSender {
  Future<FcmSendResult> sendReminder({
    required String token,
    required String reminderId,
    required String eventType,
  });
}

/// The minimum service-account fields needed for OAuth JWT bearer exchange.
/// This object deliberately does not expose a toString implementation that
/// could accidentally include the private key.
class FcmServiceAccount {
  FcmServiceAccount({
    required this.projectId,
    required this.clientEmail,
    required this.privateKey,
  });

  final String projectId;
  final String clientEmail;
  final String privateKey;

  /// Reads either FCM_SERVICE_ACCOUNT_JSON or the explicit three-variable
  /// form. A partially supplied configuration fails closed; project ID is
  /// never inferred from another setting.
  factory FcmServiceAccount.fromEnvironment([
    Map<String, String>? environment,
  ]) {
    final env = environment ?? Platform.environment;
    final json = env['FCM_SERVICE_ACCOUNT_JSON'];
    if (json != null && json.trim().isNotEmpty) {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        throw const FormatException(
          'FCM service-account JSON must be an object',
        );
      }
      return FcmServiceAccount._fromValues(
        decoded['project_id'],
        decoded['client_email'],
        decoded['private_key'],
      );
    }

    final projectId = env['FCM_PROJECT_ID'];
    final clientEmail = env['FCM_CLIENT_EMAIL'];
    final privateKey = env['FCM_PRIVATE_KEY'];
    if (projectId == null && clientEmail == null && privateKey == null) {
      throw const FormatException('FCM credentials are not configured');
    }
    return FcmServiceAccount._fromValues(projectId, clientEmail, privateKey);
  }

  /// Returns null only when all FCM variables are absent. This lets local
  /// development run with durable outbox rows while keeping production config
  /// validation strict once a secret is supplied.
  static FcmServiceAccount? tryFromEnvironment([
    Map<String, String>? environment,
  ]) {
    final env = environment ?? Platform.environment;
    final hasJson = env['FCM_SERVICE_ACCOUNT_JSON']?.trim().isNotEmpty == true;
    final hasParts = const [
      'FCM_PROJECT_ID',
      'FCM_CLIENT_EMAIL',
      'FCM_PRIVATE_KEY',
    ].any((name) => env[name] != null);
    if (!hasJson && !hasParts) return null;
    return FcmServiceAccount.fromEnvironment(env);
  }

  factory FcmServiceAccount._fromValues(
    Object? projectId,
    Object? clientEmail,
    Object? privateKey,
  ) {
    if (projectId is! String ||
        clientEmail is! String ||
        privateKey is! String ||
        projectId.isEmpty ||
        clientEmail.isEmpty ||
        privateKey.isEmpty ||
        RegExp(r'\s').hasMatch(projectId) ||
        !clientEmail.contains('@') ||
        !privateKey.contains('PRIVATE KEY')) {
      throw const FormatException('FCM service-account fields are invalid');
    }
    return FcmServiceAccount(
      projectId: projectId,
      clientEmail: clientEmail,
      privateKey: privateKey.replaceAll(r'\n', '\n'),
    );
  }
}

typedef HttpClientFactory = HttpClient Function();

/// FCM HTTP v1 sender using the service account OAuth JWT bearer flow.
class FcmHttpV1Sender implements FcmSender, MomentFcmSender, ReminderFcmSender {
  FcmHttpV1Sender(
    this.account, {
    HttpClientFactory? httpClientFactory,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final FcmServiceAccount account;
  final HttpClientFactory _httpClientFactory;
  final Duration requestTimeout;

  String? _accessToken;
  DateTime? _accessTokenExpiresAt;
  Future<String>? _accessTokenRequest;

  @override
  Future<FcmSendResult> send({
    required String token,
    required int version,
  }) async {
    try {
      final accessToken = await _accessTokenForRequest();
      final uri = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/'
        '${Uri.encodeComponent(account.projectId)}/messages:send',
      );
      final response = await _postJson(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {
          'message': {
            'token': token,
            'data': {'type': 'invalidation', 'version': '$version'},
          },
        },
      );
      return _classifyFcmResponse(response.statusCode, response.body);
    } on TimeoutException {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    } on SocketException {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    } on HttpException {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    } on FormatException {
      return const FcmSendResult(FcmSendStatus.permanentFailure);
    } catch (_) {
      // Do not leak key material, access tokens, or response bytes through
      // error logging. A bounded retry is safer than dropping an event.
      return const FcmSendResult(FcmSendStatus.transientFailure);
    }
  }

  @override
  Future<FcmSendResult> sendMoment({
    required String token,
    required String momentId,
    required String eventType,
  }) async {
    // Only opaque identifiers cross the push boundary. Text, audio paths,
    // email identities and private URLs are intentionally absent.
    if (!RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(momentId) ||
        eventType != 'moment_created') {
      return const FcmSendResult(FcmSendStatus.permanentFailure);
    }
    try {
      final accessToken = await _accessTokenForRequest();
      final uri = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/'
        '${Uri.encodeComponent(account.projectId)}/messages:send',
      );
      final response = await _postJson(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {
          'message': {
            'token': token,
            'notification': {
              'title': 'CloseCall',
              'body': 'New moment from your partner',
            },
            'data': {'type': eventType, 'momentId': momentId},
          },
        },
      );
      return _classifyFcmResponse(response.statusCode, response.body);
    } on TimeoutException {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    } on SocketException {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    } on HttpException {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    } on FormatException {
      return const FcmSendResult(FcmSendStatus.permanentFailure);
    } catch (_) {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    }
  }

  @override
  Future<FcmSendResult> sendReminder({
    required String token,
    required String reminderId,
    required String eventType,
  }) async {
    // Only opaque identifiers cross the push boundary. Reminder titles and
    // other private fields are intentionally absent from the payload.
    if (!_uuid.hasMatch(reminderId) || eventType != 'reminder_created') {
      return const FcmSendResult(FcmSendStatus.permanentFailure);
    }
    try {
      final accessToken = await _accessTokenForRequest();
      final uri = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/'
        '${Uri.encodeComponent(account.projectId)}/messages:send',
      );
      final response = await _postJson(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {
          'message': {
            'token': token,
            'notification': {
              'title': 'CloseCall',
              'body': 'Your partner added a reminder',
            },
            'data': {'type': eventType, 'reminderId': reminderId},
          },
        },
      );
      return _classifyFcmResponse(response.statusCode, response.body);
    } on TimeoutException {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    } on SocketException {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    } on HttpException {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    } on FormatException {
      return const FcmSendResult(FcmSendStatus.permanentFailure);
    } catch (_) {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    }
  }

  Future<String> _accessTokenForRequest() async {
    final now = clock.now().toUtc();
    final cached = _accessToken;
    final expiresAt = _accessTokenExpiresAt;
    if (cached != null && expiresAt != null && expiresAt.isAfter(now)) {
      return cached;
    }
    final pending = _accessTokenRequest;
    if (pending != null) return pending;
    final request = _fetchAccessToken();
    _accessTokenRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_accessTokenRequest, request)) _accessTokenRequest = null;
    }
  }

  Future<String> _fetchAccessToken() async {
    final now = clock.now().toUtc();
    final seconds = now.millisecondsSinceEpoch ~/ 1000;
    final assertion =
        JWT({
          'iss': account.clientEmail,
          'scope': 'https://www.googleapis.com/auth/firebase.messaging',
          'aud': 'https://oauth2.googleapis.com/token',
          'iat': seconds,
          'exp': seconds + 3600,
        }).sign(
          RSAPrivateKey(account.privateKey),
          algorithm: JWTAlgorithm.RS256,
          noIssueAt: true,
        );
    final response =
        await _postForm(Uri.parse('https://oauth2.googleapis.com/token'), {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': assertion,
        });
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('FCM OAuth exchange failed');
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['access_token'] is! String) {
      throw const FormatException('FCM OAuth response is invalid');
    }
    final token = body['access_token'] as String;
    final expiresIn = body['expires_in'] is num
        ? (body['expires_in'] as num).toInt()
        : 3600;
    _accessToken = token;
    _accessTokenExpiresAt = now.add(
      Duration(seconds: (expiresIn - 60).clamp(30, 3600)),
    );
    return token;
  }

  Future<_HttpResponse> _postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, Object> body,
  }) => _post(
    uri,
    headers: {'content-type': 'application/json', ...headers},
    bytes: utf8.encode(jsonEncode(body)),
  );

  Future<_HttpResponse> _postForm(Uri uri, Map<String, String> values) => _post(
    uri,
    headers: {'content-type': 'application/x-www-form-urlencoded'},
    bytes: utf8.encode(
      values.entries
          .map(
            (entry) =>
                '${Uri.encodeQueryComponent(entry.key)}='
                '${Uri.encodeQueryComponent(entry.value)}',
          )
          .join('&'),
    ),
  );

  Future<_HttpResponse> _post(
    Uri uri, {
    required Map<String, String> headers,
    required List<int> bytes,
  }) async {
    final client = _httpClientFactory();
    try {
      final request = await client.postUrl(uri).timeout(requestTimeout);
      headers.forEach(request.headers.set);
      request.add(bytes);
      final response = await request.close().timeout(requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      return _HttpResponse(response.statusCode, body);
    } finally {
      client.close(force: true);
    }
  }

  FcmSendResult _classifyFcmResponse(int statusCode, String body) {
    if (statusCode >= 200 && statusCode < 300) {
      return const FcmSendResult(FcmSendStatus.sent);
    }
    if (_hasFcmErrorCode(body, 'UNREGISTERED')) {
      return const FcmSendResult(FcmSendStatus.invalidToken);
    }
    if (statusCode == 408 ||
        statusCode == 429 ||
        statusCode == 401 ||
        statusCode == 403 ||
        statusCode == HttpStatus.notFound ||
        statusCode >= 500) {
      return const FcmSendResult(FcmSendStatus.transientFailure);
    }
    return const FcmSendResult(FcmSendStatus.permanentFailure);
  }

  bool _hasFcmErrorCode(String body, String expected) {
    try {
      final decoded = jsonDecode(body);
      final error = decoded is Map ? decoded['error'] : null;
      final details = error is Map ? error['details'] : null;
      if (details is List) {
        return details.any(
          (detail) => detail is Map && detail['errorCode'] == expected,
        );
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
}

class _HttpResponse {
  const _HttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
