# Partner widget delivery — implementation plan

## Outcome and observed gap

After pairing and one explicit recipient opt-in, **Send to partner** should
automatically update their installed Android widget without opening the app or
tapping Download. Aim for seconds on healthy online devices; Android/network
conditions prevent a universal instantaneous-delivery guarantee.

User acceptance so far: pairing succeeded on two phones; private upload now
succeeds; local widget application succeeds. Partner delivery did not happen
automatically, and the partner downloaded manually after opening the app.

## Why the current implementation does not meet this outcome

- `MediaEndpoint.uploadPhoto` stores private bytes and metadata. It creates no
  recipient display state or widget delivery event. Upload is not Send.
- `MediaController` refreshes on a pairing scope change or manual action, not
  every new partner upload. Download alone intentionally does not apply a widget.
- The foreground timeline contains schedules and recipient fallback, not a
  latest-sent-photo baseline. Unscheduled uploads never enter that timeline.
- Timeline auto-sync is off by default, reset at scope startup, and requires
  foreground Flutter for network downloads. Cached native alarms only resolve
  previously downloaded windows; they cannot receive a new network photo.
- Firebase core/config presence is not a push pipeline: there is no messaging
  registration, Serverpod push dispatch, background fetch or applied receipt.

This needs a missing delivery feature, not just a longer timeout or auto-download
inside the existing library. Do not silently apply every historical upload.

## Product flow

1. Pairing complete: ask once **Allow your partner to update your widget?**
   Explain that local photo selection pauses automatic updates. Consent persists
   across app restarts for this account, couple and device. Sign-out/re-pair clears
   it; do not reuse it for another account/couple.
2. Sender: choose photo → editor → preview → **Send to partner**. Save privately
   remains a separate secondary action; scheduling uses **Send later**.
3. Send privately uploads and commits recipient display state. If upload succeeds
   but sending fails, retry the send with the same operation ID, not a new upload.
4. Recipient: automatically fetch authorized current display state, download,
   validate, and update widget through the existing serialized native writer.
   No Download or Apply tap in the opted-in automatic path.
5. Sender sees truthful progress: **Sending**, **Sent**, then **Widget updated**
   only after recipient application acknowledgement. Push acceptance is not an
   application receipt. Paused/offline/unsupported states remain distinct.

## State and priority rules

- Serverpod remains authoritative for membership, private assets, display state,
  recipient/device consent and delivery records. Firebase transports wake hints.
- Add an idempotent send record and versioned recipient latest-photo pointer;
  derive sender/partner from the authenticated session, not client-supplied IDs.
- Never alter the recipient's personal fallback as a side effect of a send.
- One resolver on server, Flutter and native: active schedule overrides latest
  directly sent photo, which overrides personal fallback, which overrides empty.
  On schedule expiry, show the latest sent photo (or fallback if absent).
- If an active schedule masks Send now, tell the sender it is queued behind that
  scheduled window; do not falsely acknowledge that the new photo is visible.
- Fetch current truth rather than replaying payloads. Duplicate/delayed/reordered
  push events cannot overwrite a newer photo. Multiple recipient devices have
  independent consent, installation state and applied receipts.
- Manual local selection pauses updates; explicit **Resume partner updates**
  reconciles newest state. No incoming event may bypass that local override.

## Implementation slices

### 1. Serverpod send state and foreground automatic application

- Add schema/migration, authenticated Send RPC, display snapshot/version, stream
  notice and reconciliation. Preserve same-couple foreign keys, quotas and upload
  idempotency. Use the existing verified generation wrapper.
- Keep upload and send retry stages explicit; reject sending another person's
  asset unless a separate product requirement authorizes it.
- Wire one opt-in display coordinator to download/apply/ack from committed state.
  It shares primary auth refresh and the longer media transport, never creates
  another session owner. Reconnect the stream with bounded backoff.
- Persist scope-bound consent and pause state safely. Remove current
  unconditional restart opt-out only once identity-safe startup is implemented.
- Verify both apps open: send → automatic widget update without manual download.
  This is a foreground milestone, not closed-app delivery completion.

### 2. Durable push dispatch, compatible with Cloud Starter

- Register/rotate/revoke FCM installation tokens through authenticated Serverpod
  endpoints. Tokens are private server data, excluded from DTOs and logs.
- Commit send state and an outbox event atomically. Dispatch after commit, retry
  with leases/backoff, expire obsolete jobs, and remove invalid device tokens.
  FCM failures must not undo a committed send or require duplicate uploads.
- Implement a bounded server-run outbox reconciler with PostgreSQL leases for
  multi-pod safety; verify Starter lifecycle/resource limits before deployment.
  Do not depend on unavailable future calls, upgrade plans, or substitute desktop
  scheduling. Persisted outbox survives restarts; recovery cannot rely solely on
  an in-memory timer or fire-and-forget send.
- Push contains only an opaque invalidation/version hint, no photo bytes,
  credentials, download URLs or trusted authorization claims. Sensitive content
  is downloaded only after fresh recipient authorization.
- Evaluate Android FCM delivery priority against platform policy. Silent widget
  updates must not depend on unlimited high-priority data pushes: they may be
  throttled/deprioritized, particularly without user-visible notifications.

### 3. Android closed-app receiver and authorized background fetch

- Add messaging/background execution using supported Firebase/Android APIs.
  A receiver queues unique bounded work; it does not perform a long HTTP download
  directly in its callback. Foreground and background paths converge on the same
  state resolver and serialized, identity-safe native writer.
- Design background authentication before implementation: either prove safe
  shared SDK session access with cross-isolate refresh serialization, or introduce
  revocable device-scoped widget-read credentials with narrow endpoint authority,
  secure storage, expiry and explicit revoke. Never copy rotating user refresh
  tokens into an independent native client that can race Flutter.
- Check account/couple/device consent and state revision before download and
  again before applying. Sign-out/re-pair cancels jobs and prevents stale photos
  from returning. Validate bytes and preserve app-private storage/no backup.
- Confirm widget presence; publish an idempotent per-device applied receipt only
  after successful state write/update request. Describe it as device application,
  not proof of rendered pixels or that the person saw the image.
- Offline/Doze/OEM restrictions queue reconciliation. Android force-stop blocks
  automatic delivery until reopening; disclose it, do not claim a workaround.
  Flutter/native/background timeouts remain bounded and retries fetch latest
  truth rather than repeatedly sending an uncertain command.

### 4. Scheduled delivery integration

- Include latest-sent baseline in downloaded native timeline snapshots and update
  shared resolver/native tests together. Push schedule creation/change/cancellation
  to refresh caches; cache known start/end transitions locally.
- Starter lacks durable future calls. Preloaded device alarms remain inexact;
  a device without the new cache cannot promise exact scheduled delivery. Verify
  reconciler support for due events without a paid plan change.
- Keep safety TTLs explicit; persistent opt-in does not mean expired private
  photo authorization/cache can be retained indefinitely.

## Required external setup

Use the existing Firebase project if appropriate; inspect only non-secret project
settings when authorized. Existing client config does **not** grant server FCM
send authority. Enable FCM HTTP v1 and provision least-privilege server service
credentials through Cloud secret management, never chat, app assets or git.
Check that both Android package IDs and signing configurations match. No paid
Serverpod upgrade or Firebase resource change is authorized by this plan.

### FCM server secret shape

The server reads the deployed secret named `FCM_SERVICE_ACCOUNT_JSON`. Its
value must be one JSON object containing the exact fields below; `project_id`
must be the Firebase/Google Cloud project that owns the recipient app and is
never inferred from a package ID or client config:

```json
{
  "project_id": "the-authorized-google-project-id",
  "client_email": "service-account@the-authorized-google-project-id.iam.gserviceaccount.com",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
}
```

For secret managers that expose individual values instead, set all three
variables: `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, and `FCM_PRIVATE_KEY`.
Partial configuration is rejected. The backend creates OAuth2 JWT bearer
tokens and sends only to `https://fcm.googleapis.com/v1/projects/{project_id}/messages:send`.
It never logs the service account, OAuth token, FCM token, request bytes or
photo data. Missing credentials leave durable outbox rows pending, allowing a
later deployment/reconciliation after the secret is provisioned.

The backend dispatcher is now implemented, but production acceptance still
requires deploying after the secret is provisioned and testing the client path.
Firebase config files or a successful FCM send alone do not prove a fresh private
photo was authorized, downloaded and applied while the app was closed.

## Acceptance matrix

- Two real signed-in paired devices with widgets and recipient consent: Send
  reaches recipient automatically while both apps open; no Download/Apply taps.
- Recipient backgrounded and normally terminated: receive/fetch/apply without
  opening it, subject to measured platform conditions. Record upload time,
  committed-send time and applied-ack time separately, excluding private values.
- Offline then reconnect: newest photo applies, no old-event replay.
- Opt-out, manual pause, no installed widget: honest status; no unwanted overwrite.
- Duplicate send retries/push, reordered events, uncertain commit, restart during
  dispatch: one effective current state and no duplicate photo records.
- Sign-out, account switch, re-pair, revoked device and stranger download/send:
  authorization holds; pending jobs cannot restore old private content.
- Active schedule/latest-send priority, cancellation, fallback, expired cache,
  reboot, Doze and battery saver are separate observable tests.
- Target normal-online receipt within a few seconds **after upload/send commit**;
  measure real latency instead of calling transport acceptance instant delivery.

## Implemented and checked — 5 October 2026

- Serverpod now exposes authenticated `sendAsset`, `getDeliveryState` and
  `setDeliveryConsent`. Send derives the partner from current membership and
  accepts only the sender's own couple asset. Same-couple composite constraints
  and exact-request idempotency preserve isolation and ordering.
- `watchTimeline` carries versioned latest-photo state after commit. Active
  schedule → latest sent photo → personal fallback → empty is resolved consistently
  in foreground and existing native snapshots, without changing personal fallback.
- Primary paired UI is **Send to partner**, with **Save privately** separate.
  Already uploaded own photos can be sent without uploading again. Uncertain
  send retries retain the asset and operation ID; no automatic command replay.
- Recipient uses **Allow partner updates**. Consent is account/couple-scoped on
  the server plus a persistent, scoped device opt-in locally. Restart restores
  only validated consent/current truth; account changes clear it. Manual local
  selection pauses this device; incoming versions cannot bypass that pause.
- Opted-in foreground recipient automatically downloads/applies through the
  existing serialized native writer. Stream reconnect uses bounded backoff.
  Sender **Sent** is a committed-server receipt, not a remote-rendered receipt.
- Full Flutter analysis clean; **292 Flutter tests passed**. Backend analysis and
  generation roundtrip clean; **83 backend tests passed**. Shared resolver
  **7 passed**. Client standalone production-smoke tests passed using
  `dart run test/smoke_production_test.dart` (not a package:test suite).
- Real local HTTP/WebSocket smoke passed: three isolated guest clients, pairing,
  private upload/download, consent, idempotent Send, live recipient state,
  schedule/cancellation, and stranger denial. This does not prove two physical
  widgets updated.
- Cloud packaging: **25 checks passed**, including offline staged compile and
  archive allowlist inspection. Existing SQLite verification remains enabled.
- Deployed on unchanged Cloud Starter: attempt
  `399c172e-344d-4716-805e-7376d82a7001`, serving commit `2e455ce`, one ready
  podlet. Migration `20261005132731105` is included. Production access smoke
  **7 passed**; anonymous 500 remains generic denial, not proof of its cause.
- Cloud-connected APK built at `build/app/outputs/flutter-apk/app-debug.apk`.
  Phone disconnected before installation; install attempt returned device not
  found, so the new delivery build is **not yet installed/verified on a phone**.
- Added installation-scoped Android notification permission readiness. On first
  app launch, CloseCall shows one explicit Allow/Not now prompt; denial is
  remembered and does not block sign-in, pairing, foreground Send, or live
  updates. No storage/camera/all-files permission is requested: Android's photo
  picker handles gallery access.
- After a complete pair is verified, Widget setup performs read-only checks for
  notification access and the actual `CloseCallWidgetProvider` installation.
  It offers Allow notifications, Settings, or Add widget as appropriate. This
  never grants partner-update consent automatically; that remains a separate
  explicit control. Returning from Settings refreshes the real OS state.
- Android notification/widget readiness is now covered by the new permission and
  widget UI tests; full Flutter suite after this change: **339 passed**.
- Added the FCM registration foundation: after complete pairing and granted
  notification access, the Android installation registers its current FCM token
  and scoped device ID through authenticated Serverpod RPCs. Token rotation is
  idempotent; sign-out/re-pair revokes the active registration best-effort. If
  Firebase, notifications, pairing or token access is unavailable, the app stays
  usable and foreground delivery is unaffected. Background messages currently
  record only an opaque pending-wake version marker; they do not download photos
  or update the widget.
- FCM registration schema/migration is generated and covered by backend tests.
  The app also reconciles registration when notification permission changes and
  on returning to the foreground, so granting the first-launch prompt does not
  require an app restart.
- Final verification for this slice: **339 Flutter tests**, **87 backend tests**,
  generation roundtrip clean, client production smoke passed, Cloud packaging
  checks passed, and Android debug APK build passed. The FCM registration
  migration/backend is deployed on Cloud Starter; no Firebase server credential
  or dispatch secret was added.

### Durable FCM dispatch — 6 October 2026

- `sendAsset` now creates `closecall_push_outbox` in the same transaction as
  the committed delivery pointer and `WidgetSendRecord`, only when the
  recipient's current consent is enabled. `sendId + version` is unique, so
  request retries cannot create duplicate events.
- A bounded PostgreSQL `FOR UPDATE SKIP LOCKED` lease reconciler dispatches
  version-only invalidation data (`type=invalidation`, `version`) through FCM
  HTTP v1. It retries transient failures with bounded backoff, revokes
  `UNREGISTERED` registrations, expires obsolete/withdrawn-consent events,
  and keeps committed sends independent of FCM success.
- Cloud Starter uses an in-process bounded runner plus a committed-send kick;
  rows and leases survive pod restarts and do not depend on Serverpod future
  calls. There is no public unauthenticated dispatch trigger.
- Backend tests cover consent-gated atomic creation, lease ownership,
  idempotent completion, transient retry, and invalid-token revocation. No real
  network or credential is used in tests.
- This slice does **not** complete fresh-photo closed-app delivery. Android now
  accepts bounded invalidation wakes and refreshes already-cached native timeline
  transitions without network or credentials. It still needs a revocable
  device-scoped authorization for background current-state fetch, fresh photo
  download/apply, and per-device acknowledgement.

### Widget hub redesign — 6 October 2026

The paired Widget tab now presents a compact preview, setup summary and action
cards instead of a permanently expanded feature stack. Send to partner opens the
existing editor/confirmation flow. My widget, Partner updates, Schedule a photo
and My photos open lazily built scrollable bottom sheets. Permission actions,
explicit consent, local editing, save-only upload, existing-photo sending,
download/apply and schedule retry remain available there. Pending operations and
errors remain visible on the hub. Unpaired onboarding is preserved.

Verification: full Flutter analysis clean; **350 tests passed**, including lazy
sheet navigation, real controller actions, stale identity guards and
320/360/390-pixel layouts with 2× text. Media route tests now wait for actual
editor/preview presentation instead of relying on a fixed decoding delay. The
Cloud-connected debug APK built successfully. No device was attached for install;
visual phone acceptance remains pending. Backend/push behaviour was not changed.

### Widget usability fixes — 6 October 2026

### Profile identity and default photo syncing — 6 October 2026

- Profile now includes private **Your nickname** and **Partner nickname** fields.
  Each member's labels are stored on that member's Serverpod row, so one person
  cannot overwrite the other person's preferences. Nicknames are normalized,
  limited to 40 Unicode characters, and can be cleared.
- After a complete pairing, CloseCall presents a one-time photo-sync setup with
  the switch preselected on. Completing setup explicitly enables the existing
  Serverpod account consent and device-local consent. Existing on/off choices
  are restored and are never silently changed.
- Profile → Settings now controls **Automatic photo syncing**, notification
  access, and adding the home-screen widget. The Widget tab links to the same
  settings instead of owning a second receiving-consent switch.
- Notification access is requested at most once per installation. The app does
  not request blanket photo-library access; photos use the system picker. The
  current implementation remains foreground-only: closed-app authenticated
  dispatch is still awaiting server push credentials/outbox and background
  authorization work.

- Exactly four paired actions: Send a photo, My widget, Photos from your partner,
  and Send later. The confusing standalone My photos destination is removed.
- Send a photo offers New photo and a private thumbnail grid of saved own
  photos. Selecting opens a large preview; Send to partner is explicit. Viewing
  never resends. No misleading Sent/Not sent badges: the existing metadata does
  not provide authoritative historical send status.
- My widget offers received/saved photos with large previews and Use on my
  widget, plus local editing and a collapsed Default photo setting. Private image
  reads are scoped, deduplicated and bounded to two concurrent downloads and
  twelve cached PNGs / 24 MiB. Errors have explicit loading retries.
- Send later is a focused full-screen form: image-based selection, Starts/Ends
  date then time pickers, local readable dates and a review summary. The server
  still receives UTC timestamps. End-after-start, seven-day duration and
  thirty-day start bounds are validated. Cancelling a picker changes nothing.
- Upcoming schedules use photo previews and For you / For your partner, readable
  times and Cancel. No recipient IDs, asset hashes, server clock or ISO input.
  Default photo and receiving-consent controls are absent from the sending form.
- Quiet startup no longer presents routine sync/status banners. Android records
  stable photo ownership in backup-excluded storage. Startup pauses transitions;
  only validated matching identity/couple and a fresh bounded owned image can be
  restored. Legacy unowned, mismatched, invalid or expired data clears rather
  than being reused. Restoration does not renew the original TTL. Authorization
  rejection clears private content; manual pause still prevents late writes.
- Verified: **389 Flutter tests passed**, full analysis clean, **27 Android app
  JVM tests passed**. Android instrumentation APK compiles; its new restoration
  tests were not executed on the personal phone. Scheduling's 15 scoped tests
  also passed with `TZ=America/New_York` to exercise non-UTC conversion.
- Debug APK builds at `build/app/outputs/flutter-apk/app-debug.apk`. The phone
  disconnected before installation; `adb install` returned device not found.
  These usability changes are **not yet installed or physically accepted**.

### Remaining acceptance and external blocker

Update **both** phones, preserving accounts. Recipient: Widget → Photos from your
partner → enable automatic photos. Sender: send a test photo. Keep recipient CloseCall foregrounded and
verify widget changes without Download/Apply. Verify restart persistence, local
pause, resume and schedule priority separately.

Backend FCM dispatch, cached-transition wake, device-scoped background-read
authorization and the bounded native closed-app fetch/apply path are now
implemented. Per-device applied acknowledgements are still pending. Deploy the
backend and updated APK before physical acceptance; do not describe foreground
delivery or cached transitions alone as closed-app fresh-photo delivery.

### Device-scoped read authorization — 7 October 2026

- Authenticated `widgetDevice.issueCredential` issues a 32-byte random capability
  bound to the current member, couple and installation. It rotates under a
  PostgreSQL lock, expires after 24 hours and stores only its SHA-256 digest in a
  server-only table. `revokeCredential` remains available after consent withdrawal.
  Issuance and background reads disable endpoint session logging.
- `widgetBackground.currentTimeline` and `downloadPhoto` use this capability,
  never an independently refreshed user session. Every read verifies expiry,
  complete current membership and recipient consent. Private reads are restricted
  to winning photos in the recipient's current/next-24-hour timeline, capped by
  credential expiry, 100 schedules and 12 photos. Arbitrary library, fully masked,
  cancelled, expired and foreign assets are denied. Storage retrieval rechecks
  authorization and the current allowlist before returning bytes.
- The Flutter coordinator acquires authority only for Android with validated
  pairing, restored device opt-in and matching server consent. One secure-storage
  record holds credential, scope and expiry; no preferences copy of the secret.
  Fresh same-scope records survive restart. Foreground reconciliation renews below
  one hour remaining. Sign-out, account/couple changes and local manual pause clear
  authority; generation guards and a serialized storage queue reject late results.
  Sign-out clears locally before bounded best-effort remote credential revocation.
- Notification transport revocation is deliberately separate from widget-read
  authority. A late FCM-token revoke cannot silently invalidate a newer widget
  credential; sign-out has its own explicit credential cleanup hook.
- Migration `20261006224415374-widget-device-credentials` preserves existing
  composite same-couple FKs and SQL-only checks. Deployment packaging allows only
  the exact reviewed public credential DTO/schema files and this migration;
  runtime-looking secret files remain denied before any read.
- Verified locally: **449 Flutter tests**, **111 backend tests**, clean full
  analysis, clean generation roundtrip, **26 packaging checks** including offline
  runtime compilation/archive inspection, and a Cloud-URL debug APK build at
  `build/app/outputs/flutter-apk/app-debug.apk`. No deployment or phone installation
  was performed for this slice.
- The manifest FCM receiver now coalesces the greatest invalidation version onto
  one native executor. It reads the existing secure credential record, checks
  the non-suspended native identity/cache boundary and expiry, fetches only the
  current authorized timeline plus its bounded winning photos, and publishes
  through the existing serialized native writer. Transport failures retry three
  times with a bounded delay; missing/expired/revoked authority and local pause
  fail closed without applying. The existing Flutter background marker remains
  an opaque fallback and never carries credentials or photo data.
- This slice still has no per-device applied acknowledgement. Physical
  acceptance must verify closed-app sends, offline coalescing, opt-out, manual
  pause, identity changes, expiry and no-installed-widget behavior on both
  phones.
- Remaining constraints: private retrieval holds authorization locks during storage
  I/O, delaying concurrent revocation while it completes. Uncertain foreground
  issue/revoke operations are fenced only within the running coordinator. Platform
  secure-storage deletion failures are fail-closed in this coordinator but not
  proof of physical deletion. An unopened app cannot renew expired credentials;
  background work stops when authority expires.

### Push registration foundation — 6 October 2026

- Added an Android-only, authenticated FCM installation registration endpoint.
  The server derives the current user, couple and member from the Serverpod
  session; registration accepts an opaque token plus device/platform metadata,
  is idempotent per token/device, and exposes no token in a response.
- Registration rows are scoped to a couple member and device, use unique token
  and member/device constraints, and have a same-couple foreign key. Token
  rotation replaces the installation's previous token; sign-out and re-pair
  best-effort revoke the current device registration.
- The Flutter coordinator reads notification status but never requests it.
  It starts only after a loaded complete pairing and granted notifications.

### Live mood MVP — 7 October 2026

- Each paired member can choose one bounded current mood: Happy, Tired, Busy,
  Stressed, Missing You or Excited. The server stores only the member's latest
  value and UTC update time on the couple-member row.
- Authenticated `mood.current` and `mood.setMood` derive identity and couple
  membership from the session. A member can read the current partner mood but
  cannot select another user or couple; unpaired, invalid and stranger calls
  fail closed.
- Home shows a real mood card with one-tap choices, partner state, loading,
  empty, offline/error and retry states. Foreground refresh polls every 15
  seconds and pauses when the app is backgrounded; it is not an OS background
  delivery promise.
- Verified locally with the mood endpoint integration tests, Flutter mood/UI
  tests, full Flutter analysis and Serverpod generation roundtrip. The mood
  migration still needs deployment before two real accounts can use it.
  Firebase initialization, token reads, refreshes, unavailable platforms and
  server failures remain non-blocking for auth, pairing, foreground Send and
  widget use. Late async token results are discarded after scope changes.
- The FCM background callback accepts only an opaque invalidation/version hint
  and records a bounded app-private wake marker. It does not download photos,
  create a second auth client, or claim closed-app widget updates. Foreground
  reconciliation and a future authenticated dispatcher remain required.
- FCM server credentials, durable outbox dispatch, background authorized fetch,
  and applied acknowledgements are intentionally not part of this foundation.
  Token data is sensitive server-only data and must not be placed in logs,
  client DTOs, app UI, or chat; no server encryption mechanism currently exists
  in this repository, so access to the registration table must remain limited
  to the backend runtime and database operators.
