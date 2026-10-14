# Private Moments and voice snippets

## Implemented flow

- A signed-in, fully paired member opens **Moments** and sees a newest-first
  private feed, with 20-entry pages and an explicit **Load older moments** action.
- **Add a moment** accepts a text note, a voice clip, or both. Nothing publishes
  while typing, recording, previewing or cancelling.
- Voice flow: **Record voice** → microphone permission if needed → **Stop
  recording** → **Preview voice** → **Publish moment**. Clips stop at 30 seconds.
- Tap **Play voice** to download and play a published clip. Feed reads never
  pre-download audio, auto-play it, send a widget photo or change a schedule.
- Returning to the Moments tab refreshes the feed, and the feed supports
  pull-to-refresh. Partner notifications are a bounded delivery hint: they
  contain only a generic notification plus the opaque Moment id, never Moment
  text, audio, identities or private URLs.
- When a valid `moment_created` notification arrives in the foreground, from a
  notification tap, or as the initial message after a cold start, the app waits
  for the current authenticated complete-couple scope, opens Moments and
  refreshes the private feed. The server remains authoritative for access.
- The author can delete their own moment after confirmation. The partner cannot
  delete another member's moment. Deletion retains a content hash/request-id
  tombstone so a delayed publish retry cannot resurrect deleted content.

## Privacy and limits

- Serverpod derives identity and the current complete couple from the session.
  All four RPCs require login and turn off endpoint session logging. Public DTOs
  contain no storage paths or public URLs.
- Text: up to 1,000 Unicode characters, nonblank for text-only posts.
- Voice: real PCM WAV, 16-bit mono at 16,000 Hz, maximum 30 seconds and 1 MiB.
  The backend validates RIFF/frame metadata and derives the actual duration;
  neither the client filename nor a claimed duration is trusted.
- Maximum 100 active moments and 50 active voice clips per couple. Storage is
  private. Quota checks and private reads/writes use PostgreSQL locks.
- Publication retries retain the original UUID and exact text/audio bytes.
  Ambiguous responses require explicit Retry; they never silently publish again.
- Flutter clears private feed/draft/audio state on account, auth-revision, couple
  or partner changes and rejects late results from old scopes.
- Recording uses bounded in-memory PCM. Playback uses a temporary app-private
  file, deleted on stop/completion/scope cleanup. Leftovers from an interrupted
  process are removed on the next playback/cleanup.
- Leaving Moments or backgrounding the app stops native recording/playback and
  invalidates pending downloads. An unfinished recording is discarded; the
  written draft remains. A completed draft recording remains in memory until
  publish/cancel/scope cleanup.

## Nickname card

Profile now shows separate You/Your partner identity rows, initials or fallback
icons, a modern Edit action and an explicit personal-only privacy note. Editing
still uses the existing validation, scoped save, cancel and late-result guards.
Nicknames are personal labels and are not shown to the partner.

## Backend integration

- `moments.listMoments({beforeId, limit = 20})`
- `moments.createMoment({requestId, text, voiceBytes})`
- `moments.downloadVoice({momentId})`
- `moments.deleteMoment({momentId})`
- Migration: `20261010204723852-moments`. Its extension preserves prior
  SQL-only same-couple foreign keys/checks and adds the same-couple author FK.
- Partner notification delivery uses the independent server-only
  `MomentEventOutbox`, `MomentEventOutboxDispatcher` and FCM HTTP v1 sender.
  The runner is a bounded reconciliation wake-up; the durable outbox row is
  authoritative and expires after one day.
- Shared reminders use `reminders.listReminders`, `createReminder`,
  `completeReminder` and `deleteReminder`. Local notifications are generic so
  private reminder titles do not appear on lock screens. Sign-out and unpair
  cancel the local schedule. Creating a reminder also writes a durable,
  couple-scoped partner event and sends a generic FCM notification when the
  partner has an active registered device. The push contains only the opaque
  reminder UUID and `reminder_created`; the reminder title, time and creator
  identity stay out of the payload. Foreground delivery is presented locally;
  background and terminated Android delivery use the FCM notification payload.
- Migration: `20261012083947841-reminders`. Its extension preserves every prior
  SQL-only invariant and adds validated same-couple FKs for the reminder and
  Moment event outbox tables.
- Reminder notification outbox migration:
  `20261014053004876-reminder-fcm`.
- Regeneration: run `../.tooling/flutter/bin/dart run tool/generate.dart --check`
  from `closecall_server`. The reviewed generator extension preserves the
  optional page-size default in generated clients and test callers.

## Verification and remaining acceptance

Combined local verification in this implementation:

- `./.tooling/flutter/bin/flutter analyze` — passed with no issues.
- `./.tooling/flutter/bin/flutter test` — 489 passed.
- `../.tooling/flutter/bin/dart analyze` — passed with no issues.
- `../.tooling/flutter/bin/dart test` from `closecall_server` — 133 passed.
- `../.tooling/flutter/bin/dart run tool/generate.dart --check` and
  `../.tooling/flutter/bin/dart run tool/extend_reminders_migration.dart
  --check` — passed.
- Final Android debug APK build with
  `--dart-define=SERVERPOD_URL=https://closecall.api.serverpod.space/` — passed.
  APK: `build/app/outputs/flutter-apk/app-debug.apk` (built after the current
  reminder and notification changes).
- `CLOSECALL_DEPLOY_INTEGRATION=1 python3 -m unittest discover -s scripts -p
  'test_prepare_cloud_deploy.py' -v` — 26 passed, including offline runtime
  compilation and Cloud archive inspection.
- Existing two widget-preview tests assumed a fixed 100 ms asynchronous PNG
  processing time. They now wait for the expected route with a bounded deadline;
  assertions and production widget behaviour are unchanged.

## Cloud deployment receipt

- Project: `closecall`; API: `https://closecall.api.serverpod.space/`.
- Deployment: `f0fdc5b0-f41e-4d61-b81d-eb665efa93a5`.
- Upload, Cloud build and rollout all succeeded. The initial CLI command timed
  out during rollout; status inspection confirmed success without redeploying.
- Deployed the allowlisted server/shared runtime and migrations, including
  `20261010204723852-moments`. No plan, Cloud secret or provisioning changes.
- Deployment-packaging checks rerun before upload: 26 passed, with offline
  runtime compilation and archive allowlist verification.
- Reviewed dry-run archive: `.tooling/review/closecall-moments-deploy.zip`,
  128 entries; SHA-256:
  `0a88cfd060eef039fb6b536847e41375ff4c24eb6568284eae04e8b70fe59cf4`.
- Live probes: API root HTTP 200; unauthenticated POST to each Moments RPC and
  `mood/current` HTTP 401. These prove route availability/auth gating, not
  authenticated feed, database or voice acceptance.
- Profile now offers a confirmed **Unpair from partner** action. The deployed
  `pairing.unpair` RPC removes only the current membership, cascades that
  member's private delivery/credential state, preserves shared Moments history
  when a partner remains, and issues a fresh invite for the remaining member.
- Unpair deployment: `3a8ef5ef-cd11-4ce0-b65b-00bb35de36c7`; unauthenticated
  route probe returned HTTP 401.
- Follow-up deployment `5c082237-9150-4e76-9fb5-e7146432bbf0` fixed the
  creator-slot uniqueness ordering in unpair. Profile now presents sign-out as
  a compact header icon, suppresses ordinary pairing retry buttons and raw
  server exception text, while pull-down refresh and automatic recovery remain.
 - Reminder partner FCM code and migration were deployed in the latest Cloud
  rollout. Production FCM service-account configuration and authenticated
  two-device delivery remain unverified, so delivery still needs a physical
  acceptance test.
- Source remains uncommitted. Cloud associates the deployment with the last
  commit even though the uploaded package includes the current Moments changes.

Before calling this physically accepted:

1. Install the Cloud-URL APK on both phones, preserving their app data. No device
   was connected at the post-deployment ADB check.
2. Publish a harmless test note; refresh the partner feed and restart both apps
    to verify persistence.
3. On explicit Record, test microphone grant/denial, Stop, preview, cancel,
    publication and partner playback. Confirm no recording continues when
    leaving Moments, backgrounding or signing out.
 4. Test the 30-second boundary and author-only deletion. Verify new nicknames
    appear in that member's feed labels but do not change the partner's labels.

5. Verify a generic Moment notification while the app is foregrounded,
   backgrounded and closed; tap it and confirm the authenticated partner opens
   the refreshed Moments feed. Confirm the notification carries no private
   content and that an unpaired/sign-out scope never opens the feed.
6. Create, reschedule through refresh, complete and delete reminders; confirm
   generic local notification text, sign-out/unpair cancellation and no
   cross-couple access.

Native microphone/speaker, local-notification delivery, interruption/permission
behaviour and FCM service-account delivery remain untested on physical devices
for this slice. iOS build/acceptance is not yet run. Photo attachments,
reactions and voice transcription remain outside the implemented scope.
