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
- Relaunch starts with identity-safe cleanup and restores validated persisted
  partner consent on this same account/couple/device before fetching fresh truth.
  Force-stop suppresses
  Android alarms. Physical Doze/reboot behaviour still needs real-device testing.

## Cloud Starter deployment

Project: `closecall`. Starter trial expires 3 November 2026. Do not upgrade or
enable paid resources without separate approval. Starter disables future calls;
foreground DB reconciliation and cached Android transitions still work.

Cloud variables set for this project:

- `CLOSECALL_FUTURE_CALLS_ENABLED=false`: no dead future-call queue entries.
- `SERVERPOD_MAX_REQUEST_SIZE=4194304`: permits bounded 2 MiB PNG RPC payloads.

Cloud manages production config and database/auth/email secrets. No development
passwords are uploaded. Stage only reviewed runtime files:

```sh
python3 scripts/prepare_cloud_deploy.py --replace
cd .tooling/cloud-deploy
../../.tooling/flutter/bin/dart pub get --offline
```

Deploy with the existing isolated Cloud CLI, specifying
`--project-dir .tooling/cloud-deploy/closecall_server` (absolute path recommended)
and project `closecall`. Always review `deploy --wet-run --show-files --output
<ignored-zip-path>` first. Root/server `.scloudignore` intentionally deny direct
repository uploads; only the generated deployment workspace is allowlisted.
The stage bundles the shared resolver as a Dart workspace, strips dev
dependencies, preserves pinned runtime versions, and excludes all private
configs, inbox attachments, SDKs, logs and databases. No code-generation hooks
run during deployment; run the verified generation wrapper beforehand.

Packaging validation:

```sh
CLOSECALL_DEPLOY_INTEGRATION=1 python3 -m unittest discover \
  -s scripts -p 'test_prepare_cloud_deploy.py' -v
```

These optional integration tests use the isolated Cloud CLI package context at
`.tooling/cloud-inspect/.dart_tool/package_config.json`. They inspect ZIP contents
and compile staged Dart runtime sources without provisioning Cloud resources.

Current deployment status: project `closecall`, Starter trial through 3 November
2026, one ready podlet, migrations applied. API origin:
`https://closecall.api.serverpod.space/`. Read-only production smoke passes all
seven probes: six unauthenticated RPCs return 401 and anonymous login returns
generic 500. This proves transport/auth guards, not transactional email delivery.

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
- Flutter tests: 155 passed; backend tests: 73 passed; shared resolver: 7 passed,
  including real PostgreSQL
  concurrency and authentication tests.
- Local HTTP/JWT smoke: passed.
- Production HTTP smoke: passed against `https://closecall.api.serverpod.space/`.
- Cloud packaging: 25 Python tests plus staged compile/archive validation passed;
  verified SQLite Linux asset digest preserved.
- Preserved original development database upgraded successfully; HTTP pairing,
  private media and scheduling smoke passed afterward.
- Clean source copy without `.env` or inherited secrets: Flutter/backend tests
  passed after fresh local-secret bootstrap.
- Android debug APK build: passed (`build/app/outputs/flutter-apk/app-debug.apk`).
- Android JVM tests: 27 passed; native emulator instrumentation: 4 passed,
  including receiver-based fallback without launching Flutter.
- Physical devices, native iOS, transactional email, and closed-app network
  delivery: not verified. Cloud deployment itself is verified live.

## Acceptance progress — 5 October 2026

- User confirmed actual email delivery/sign-in (verification message initially
  arrived in Spam). Two cold launches on CPH2531 reached the authenticated shell
  after the session-restoration fix without Connection paused.
- User confirmed local gallery/editor flow updated the actual home-screen
  widget. This proves local widget application, **not partner delivery**.
- Backend suite rerun: **73 passed**, including PostgreSQL-backed pairing,
  private-media isolation/idempotency, schedule start/end/cancellation, and
  foreground reconciliation with future calls disabled for Starter.
- Production access probes rerun: **7 passed**. Six private calls returned 401;
  anonymous login returned generic 500 (not proof of the specific denial cause).
- Flutter suite from the installed build: **207 passed**; analysis clean.
- Only CPH2531 was attached at this check. A second physical Android phone is
  required for the next acceptance step; do not treat backend tests as a real
  two-device test or access credentials from either phone.

### Next physical two-device test

1. Install the same Cloud-connected APK on phone B without clearing app data.
   Register/sign in directly on B using a **different email account** from A;
   passwords and verification codes stay on the device.
2. In Profile, use A's current invite on B. Share/enter the invite directly on
   the phones, then refresh A. Both should report completed pairing.
3. On A, decorate and upload a harmless test photo. On B, refresh private
   photos, select/download it, and explicitly apply it to B's widget.
4. On B, choose a private fallback and enable auto-sync. On A, schedule an
   uploaded photo a few minutes ahead for a short window. Keep both apps open
   initially; verify B changes at the start and reverts to fallback at the end.
5. Verify cancellation while B is online. Then repeat with a fully cached
   window and B backgrounded/offline. Do not force-stop B: Android suppresses
   alarms after force-stop. Allow for OS-delayed transitions.
6. Mark reboot/battery-saving acceptance separately. New/changed/cancelled
   server windows require reconnect; there is no closed-app network-update or
  exact-time delivery guarantee. Relaunch validates persisted partner opt-in
  and fetches fresh truth before repopulating the cache.

The paired scheduling form still uses explicit-zone timestamp text and asset
identifiers. Friendly date/time and photo selection remain a usability gap.

## Live Send-to-partner release — 5 October 2026

See `partner-widget-delivery-plan.md` for implementation and evidence. Serverpod
Send now and persistent recipient consent are deployed on Starter, commit
`2e455ce`, attempt `399c172e-344d-4716-805e-7376d82a7001`. The paired Widget tab
now offers Send to partner and Allow partner updates; an opted-in foreground
recipient automatically downloads/applies the latest sent state. Save privately
alone still does not send. Closed-app network reception still needs FCM work.

Checks: 292 Flutter, 83 backend, 7 shared resolver, 25 packaging checks; local
HTTP/WebSocket delivery smoke and 7 production access probes passed. Android
debug APK built, but the phone disconnected before install. Both phones must
receive this APK before genuine automatic two-device acceptance is claimed.
