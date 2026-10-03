# Serverpod foundation setup

## Versions and local tools

- Flutter 3.47.6 / bundled Dart 3.13.5 (minimum: Flutter 3.44.4 / Dart 3.12.2).
- Serverpod server, client, authentication and CLI: 4.0.3.
- Existing isolated Flutter: `.tooling/flutter`; FVM version pin: `.fvmrc`.
- Embedded PostgreSQL starts automatically in development/test, with data under
  ignored `closecall_server/.serverpod/`. Production uses external PostgreSQL.

Commands below run from the repository root unless stated otherwise. If using
FVM or your own compatible SDK, substitute its `flutter` and `dart` executables.

## Local secrets and server

```sh
.tooling/flutter/bin/dart run scripts/bootstrap_serverpod.dart
cd closecall_server
../.tooling/flutter/bin/dart pub get
../.tooling/flutter/bin/dart run bin/main.dart --apply-migrations
```

The bootstrap creates cryptographically random development/test values in the
ignored `config/passwords.yaml`, does not print secrets, and never replaces an
existing secret value. Missing local keys (including the email pepper) are added
under a file lock. Keep that file private. Do not copy development values into a
production deployment. API listens on port 8080, Insights on 8081, and embedded
development PostgreSQL on 8090. Do not expose Insights or database ports publicly.

## Client addresses

Set `--dart-define=SERVERPOD_URL=<api-url>` when launching Flutter.

| Client | Local API URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:8080/` |
| iOS simulator / local desktop | `http://localhost:8080/` |
| Physical device | `http://<computer-LAN-IP>:8080/` |
| Deployed app | Your real `https://` API origin |

Physical devices must reach the computer on the same network; check firewall
access to port 8080. Android debug permits local cleartext HTTP; this permission
is not added to release builds. iOS local HTTP may need development-specific ATS
configuration or an HTTPS development endpoint; native iOS was not validated.
No URL deliberately selects demo mode. Invalid URLs and failed live requests
remain visible errors; they never silently substitute sample data.

## Pairing verification

1. Start the backend and two app instances with the correct API URL.
2. Register/sign in with an email account on each device. Development verification
   codes are visible in the local server terminal only; never paste them in chat
   or commit them. Alternatively, explicitly enable local guests with
   `--dart-define=ALLOW_DEV_GUEST=true`.
3. One device creates an invite; the other joins using that code.
4. Refresh pairing on the first device: both should show the same couple and
   exactly two members, with no remaining invite code.
5. Relaunch without signing out: secure auth storage should restore identity.

**Guest accounts are development-only and cannot be recovered after sign-out,
app deletion or device loss.** Anonymous creation fails closed in staging and
production. Email accounts are recoverable; they do not automatically acquire
an existing guest's couple/media data. Actual deployed email delivery still
requires Serverpod Cloud email access or a configured alternative provider.
Pairing and private photo sharing are live. Widget application is explicit and
local. Foreground streams and opt-in Android cache sync are live. Already
cached transitions can run without Flutter, subject to OS delay; receiving
new/changed/cancelled server schedules still requires reconnect.

## Android offline cache

- Per-account/couple opt-in, up to 12 private photos and 100 windows in a 24h
  horizon. If the complete horizon cannot fit, sync stays foreground-only.
- Photos and scope metadata live in app-private, backup-excluded storage. No
  credentials or URLs are sent to the native cache. App backup is disabled.
- Start-inclusive/end-exclusive windows share server resolver priority; creation
  microseconds are preserved to avoid false ties within one millisecond.
- Inexact alarms recompute current truth at actual wake; delayed alarms do not
  replay expired photos. Boot/time changes reload cached state; post-reboot time
  uses a bounded wall-clock approximation until reconnect.
- Missing/expired cache shows fallback or empty, not a stale scheduled photo.
  Cache expires after 24h. Auth/couple changes clear it; manual choices stop it.
- Relaunch starts with cleanup and requires fresh opt-in. Force-stop suppresses
  Android alarms. Physical Doze/reboot behaviour still needs real-device testing.

## Code generation and migrations

### Local HTTP smoke

With the development server running on localhost:8080:

```sh
cd closecall_client
../.tooling/flutter/bin/dart run tool/smoke_pairing.dart
```

This creates three fresh local guest accounts and checks actual HTTP/JWT calls,
identity isolation, idempotent creation, joining, consumed-invite rejection,
private upload/list/download, stranger rejection, and upload retry idempotency.
No token or invite value is printed or stored by the smoke command.

### Regeneration

Generated code is checked in; do not edit it by hand. Install an isolated CLI
only when changing endpoint/model definitions:

```sh
export PATH="$PWD/.tooling/flutter/bin:$PATH"
export PUB_CACHE="$PWD/.tooling/pub-cache"
dart pub global activate serverpod_cli 4.0.3
cd closecall_server
dart run tool/generate.dart
dart run tool/generate.dart --check
```

Use the wrapper rather than bare generation: Serverpod 4.0.3's model DSL cannot
express the same-couple composite foreign keys, and its FK renderer/inspection
have ordering bugs. The wrapper adds a narrow, AST-validated server schema
extension reproducibly; CI checks the generation roundtrip. Do not patch
generated files by hand. The wrapper owns server outputs; endpoint changes also
require regenerating/reviewing the companion client with the pinned CLI.

After a schema change, run `create-migration` through the pinned CLI and inspect
JSON, SQL and definition snapshots. Preserve composite same-couple FK/check
invariants. `tool/schedule_migration_sql.dart` corrects composite quoting without
modifying the global CLI. Apply reviewed migrations using `--apply-migrations`.
The appended `20261004000100000` repair works for previous incremental installs
as well as fresh databases. Supabase SQL is not applied to Serverpod's database.

## Before production

- Verify actual email delivery; `scloudAuthEmailKey` is provisioned by Serverpod
  Cloud. Self-hosting requires a real email provider. Guest creation remains
  blocked outside development/test.
- Replace `.invalid` hosts in production/staging config with deployment values.
- Provision external PostgreSQL with TLS and apply reviewed migrations.
- Set independent database, Insights and JWT secrets through deployment secret
  management; never include them in app builds or repository files.
- Add pairing-attempt throttling/abuse protection and decide invite expiry and
  account unlink/deletion behaviour before public release.
- Configure closed-app authenticated push refresh if required. Database-backed
  private media works locally; choose appropriate object storage for scale.
- Schedules use durable Serverpod future-call wakeups plus foreground stream/DB
  reconciliation. Verify Serverpod Cloud plan supports future calls; Starter
  currently disables them.
- Verify physical-device/release networking, secure session restoration and the
  genuine two-device widget flow before claiming end-to-end readiness.

Legacy Supabase code/migrations remain for reference but are not selected at
startup. Existing private `.env` and Firebase files have not been removed.

## Validation recorded on 4 October 2026

- App, generated client and backend analysis: clean.
- Flutter tests: 155 passed; backend tests: 57 passed; shared resolver: 7 passed,
  including real PostgreSQL
  concurrency and authentication tests.
- Local HTTP/JWT smoke: passed.
- Preserved original development database upgraded successfully; HTTP pairing,
  private media and scheduling smoke passed afterward.
- Clean source copy without `.env` or inherited secrets: Flutter/backend tests
  passed after fresh local-secret bootstrap.
- Android debug APK build: passed (`build/app/outputs/flutter-apk/app-debug.apk`).
- Android JVM tests: 27 passed; native emulator instrumentation: 4 passed,
  including receiver-based fallback without launching Flutter.
- Physical devices, native iOS and deployed Cloud environments: not verified.
