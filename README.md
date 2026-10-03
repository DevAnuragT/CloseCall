# CloseCall

A private couples app: decorate a photo and, eventually, schedule it on your
partner's home-screen widget. Flutter frontend; Serverpod authoritative backend.

## Current status

- Implemented: Flutter navigation/theme, sample dashboard, image editor/export,
  shape previews, local Android widget bridge, tested widget schedule resolver.
- Implemented backend: recoverable email accounts plus optional development guests, PostgreSQL
  couple membership, authenticated create/join/read pairing APIs, database
  constraints and concurrent-invite redemption tests, generated Dart client,
  validated private PNG storage with membership checks and idempotent uploads.
- Implemented frontend integration: explicit demo/live modes, persisted secure
  session, email registration/login/reset, Profile pairing, photo picking,
  private upload/list/download, loading/error/retry and manual refresh.
- Implemented scheduling: private recipient timelines, overlap priority,
  own fallback, cancellation, live foreground streams, and opt-in Android
  cached transitions/revert with a 24-hour expiry.
- Not implemented: production email delivery verification,
  network delivery of new schedules while the app is closed,
  live mood/reminders, Moments, cloud deployment, or iOS widgets.

Local editing updates the **same device**. Private sharing and schedules target
the partner's timeline; the recipient must opt in to sync and cache it.
Live Home intentionally shows no sample mood/reminder/widget state as real data.

## Packages

```text
lib/                  Existing Flutter app
closecall_client/     Generated Serverpod client
closecall_shared/     Shared schedule model/resolver used by server and app
closecall_server/     Auth, pairing, database config and migrations
supabase/             Legacy migrations retained during transition
docs/                 Migration plan and setup guide
```

## Requirements

Flutter **3.47.6** is pinned in `.fvmrc`; Serverpod packages are pinned to **4.0.3**.
Serverpod 4's minimum is Flutter 3.44.4 / Dart 3.12.2. Use Flutter's bundled Dart.
Development/test use Serverpod's embedded PostgreSQL; Docker is not required.

This workspace has an ignored SDK at `.tooling/flutter`. It does not change
machine-wide Flutter. On a fresh clone, install the pinned version independently
using [Flutter's official archive](https://docs.flutter.dev/install/archive), or
use FVM if you already have it. Never commit SDK binaries.

## Quick start (existing isolated SDK)

From the repository root:

```sh
export PATH="$PWD/.tooling/flutter/bin:$PATH"
flutter pub get
(cd closecall_client && dart pub get)
(cd closecall_server && dart pub get)
dart run scripts/bootstrap_serverpod.dart
```

Terminal 1, repository root:

```sh
cd closecall_server
../.tooling/flutter/bin/dart run bin/main.dart --apply-migrations
```

Terminal 2, repository root (Android emulator):

```sh
.tooling/flutter/bin/flutter run \
  --dart-define=SERVERPOD_URL=http://10.0.2.2:8080/
```

Register/sign in with email, then open **Profile** and create an invite on one
device and join by code on the other. Use **Refresh pairing** on the creator
device; automatic partner subscriptions are a later milestone.

Development email codes appear only in the local server terminal. Use them in
the app, not in chat or repository files. Guest sign-in is hidden by default;
enable it explicitly with `--dart-define=ALLOW_DEV_GUEST=true` for local tests.
Cloud deployments require actual transactional email access.

The Widget tab now picks/decorates a photo and uploads it privately. Your partner
can refresh, download, and explicitly apply it to their own Android widget.
Photos are limited to 2 MiB / 2048 pixels per dimension; 50 assets per couple.

When paired, Widget also supports private-photo fallback selection, partner
schedules (UTC windows, overlap resolution, cancel), live foreground timeline
updates, and explicit auto-sync. Android can apply already cached windows while
the app is closed, but alarms may be delayed by the OS. New/changed/cancelled
schedules require reconnect; force-stop blocks background work. Cache expires
after 24 hours. Manual local choices pause auto-sync; relaunch requires opt-in
again. No exact-time or closed-app network delivery guarantee is made.

Omit `SERVERPOD_URL` for explicitly labelled offline demo mode. A configured but
unreachable/invalid server never silently selects demo data. `.env` is not
required and is no longer bundled or loaded.

## Tests

```sh
.tooling/flutter/bin/flutter analyze --no-pub
.tooling/flutter/bin/flutter test --no-pub
(cd closecall_client && ../.tooling/flutter/bin/dart analyze)
(cd closecall_server && ../.tooling/flutter/bin/dart analyze)
(cd closecall_server && ../.tooling/flutter/bin/dart test)
```

CI pins Flutter, resolves all three packages, generates fresh ignored local
secrets, and runs frontend/client/server analysis plus Flutter and backend tests.

## Continue

- [Serverpod setup, network addresses, secrets and code generation](docs/serverpod-setup.md)
- [Migration milestones and acceptance criteria](docs/serverpod-migration-plan.md)
- `get started.pdf`: hackathon resource sheet; linked official rules require a
  working full-stack Serverpod backend, run instructions and a demo video under
  two minutes. AI-assisted development must be disclosed.
