import 'dart:async';
import 'dart:io';

import 'package:closecall_client/closecall_client.dart';

const productionSmokeTimeout = Duration(seconds: 10);
const productionSmokeDummyAssetId = '00000000-0000-4000-8000-000000000000';

/// Requires an explicit HTTPS API origin, not a web URL or credential-bearing URL.
/// Invalid input is never included in an exception or console output.
String validateProductionApiUrl(String input) {
  try {
    final uri = Uri.parse(input);
    if (input.isEmpty ||
        input.contains('@') ||
        RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(input) ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.authority.contains('@') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const FormatException('invalid_api_url');
    }
    return uri.replace(path: '/').toString();
  } on FormatException {
    throw const FormatException('invalid_api_url');
  }
}

/// Read-only RPC probes plus an anonymous login denial probe.
/// Run only against a deployment whose server guard rejects anonymous login
/// before account creation. HTTP 500 confirms a generic server-error denial;
/// it does not prove the guard's reason or independently verify no account was
/// created. A successful login is a failure; its response is discarded, never
/// printed or installed.
/// No email registration, pairing mutation, upload, or schedule write is sent.
/// Takes ownership of [client] and closes it even on failure or timeout.
Future<bool> runProductionSmoke(
  Client client, {
  Duration timeout = productionSmokeTimeout,
  void Function(String) report = print,
}) async {
  try {
    if (client.authKeyProvider != null) {
      report('client FAIL AuthKeyProviderPresent');
      return false;
    }
    final probes = <String, Future<Object?> Function()>{
      'currentAccount': client.account.currentAccount,
      'currentCouple': client.pairing.currentCouple,
      'listAssets': client.media.listAssets,
      'currentTimeline': client.widgetSchedule.currentTimeline,
      'partnerTimeline': client.widgetSchedule.partnerTimeline,
      'downloadPhoto': () =>
          client.media.downloadPhoto(productionSmokeDummyAssetId),
      'anonymousIdp.login': () => client.anonymousIdp.login(),
    };
    for (final probe in probes.entries) {
      try {
        await Future<Object?>.sync(probe.value).timeout(timeout);
        report('${probe.key} FAIL UnexpectedSuccess');
        return false;
      } catch (error) {
        final expected = probe.key == 'anonymousIdp.login'
            // Expected transport status for the production guard, but any
            // generic HTTP 500 meets this check. Do not infer its cause.
            ? error is ServerpodClientInternalServerError &&
                  error.statusCode == 500
            : error is ServerpodClientUnauthorized && error.statusCode == 401;
        final type = error.runtimeType.toString().replaceAll(
          RegExp(r'[^A-Za-z0-9_]'),
          '',
        );
        report('${probe.key} ${expected ? 'PASS' : 'FAIL'} $type');
        if (!expected) return false;
      }
    }
    return true;
  } finally {
    client.close();
  }
}

/// Run from closecall_client: `dart run tool/smoke_production.dart <https-api-origin>`
/// Obtain the API origin from deployment metadata; there is no default URL.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('api_url FAIL ArgumentCount');
    exitCode = 64;
    return;
  }
  try {
    final url = validateProductionApiUrl(args.single);
    final passed = await runProductionSmoke(
      Client(url, connectionTimeout: productionSmokeTimeout),
    );
    print('production_smoke ${passed ? 'PASS' : 'FAIL'}');
    if (!passed) exitCode = 1;
  } catch (error) {
    // Do not print a URL, exception message, stack trace, or response body.
    final type = error.runtimeType.toString().replaceAll(
      RegExp(r'[^A-Za-z0-9_]'),
      '',
    );
    stderr.writeln('production_smoke FAIL $type');
    exitCode = 1;
  }
}
