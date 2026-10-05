# CloseCall — launch recovery and unpaired Widget redesign

## Scope

Planning/design only in this iteration. Fix repeated session-validation failure
and simplify the third navigation tab for a signed-in user without a partner.
Do not change backend authority, clear accounts, or pretend device delivery has
been verified. Existing paired/photo/editor functionality must be preserved.

## Evidence

- `ServerpodAuthSession.initialize()` calls `client.auth.initialize()` without a
  timeout override. Pinned Serverpod 4.0.3 defaults to two seconds, restores
  credentials, then forces JWT refresh and checks sign-in status.
- CloseCall maps a false result to a generic StateError; AuthGate blocks the
  entire shell and presents Connection paused. The UI cannot distinguish a
  transient transport failure from invalid credentials.
- A read-only Cloud log summary found `RefreshTokenInvalidSecretException`
  during refresh. No credentials, verification codes or payloads were copied.
  The origin of that invalid secret is not yet proven. Slow refresh, repeated
  restore, token-rotation persistence and overlapping requests need reproduction.
- WidgetTabScreen renders sharing/upload, private library, and SchedulePanel
  even when pairing is incomplete. Wrapping labels and repeated actions add noise.

## 1. Repair session restoration first

Expected: a valid persisted email session survives app close/reopen without
requiring another login. Pairing absence must never be an auth failure.

1. Reproduce cold launch with fake secure storage/transport and a real-device
   restart. Never read or log stored credentials.
2. Give validation a bounded realistic timeout and serialize restore/validation
   attempts. Examine late refresh completion before retrying; do not reload stale
   credentials while rotation is still running.
3. Distinguish valid, definitively expired/revoked, transiently unavailable and
   storage failure outcomes. Invalid sessions lead to normal sign-in with a
   brief explanation. Network errors preserve credentials and offer retry.
4. Separate pairing fetch failure from session restoration. A failed couple
   request should yield an inline Retry state, not a whole-app login blocker.
5. Do not bypass server authorization, silently create guests, or automatically
   sign out on a timeout. Explicit account reset must preserve guest-loss warnings.

Regression cases: fresh signed-out launch; valid persisted session; network
slower than two seconds; expired access token with valid refresh; invalid refresh;
offline launch; double retry; late refresh completion; account switch; restored
user with no couple; paired and pending-invite users.

## 2. Design the unpaired Widget screen as a distinct state

Visual direction: warm ivory, restrained rose/plum accents, one generous rounded
preview, readable typography, clear primary action, minimal copy. Avoid technical
labels such as private server, fallback, UTC, cache or timeline in onboarding.

Visible order:

1. **Your widget** — short, friendly heading.
2. **Preview** — illustrative until a real local photo is chosen. Never label it
   as the installed widget without checking native state.
3. **Choose a photo** — primary action. Gallery → editor → preview → explicitly
   **Set on my widget**. The local-only meaning is one short caption.
4. **Start with a blank canvas** — quiet secondary link, same editing flow.
5. **Better together** — compact partner card, **Connect partner** opens focused
   pairing. If an invite already exists, use Waiting for your partner / View invite.
6. **How to add the widget** — collapsed help. Show helpful next-step guidance
   after first successful photo save rather than another permanent paragraph.

Hide completely before complete pairing:

- Upload/share buttons and duplicate upload actions.
- Private photo-library empty states and refresh buttons.
- Auto-sync switch, schedules, fallback selection and recipient timelines.
- Server clock, raw IDs, pending request IDs, disabled controls and warning walls.
- The current app-shell banner explaining local/private server separation.

## State boundaries

- Pairing unknown/loading: compact loading state, no claim of being unpaired.
- Pairing fetch failed: compact Retry message, no fabricated empty library.
- Unpaired: local preview/editor plus Connect partner.
- Invite pending: same local tools plus waiting card and View invite.
- Paired: switch to a separate sharing experience; do not cram it into onboarding.
- Auth/couple change: discard stale UI/private results; preserve existing cleanup
  and native write serialization. Use actual controller changes reactively.

## Acceptance checks

- No upload/schedule/library controls or raw identifiers on unpaired screens.
- Choose a photo is visible without scrolling on a typical phone.
- Pairing and local editing remain independent, usable actions.
- Cancel gallery/editor is safe; save failure remains visible and retryable.
- Friendly dates/pickers instead of ISO text inputs in the later paired redesign.
- Test 320/360/390 logical-pixel widths, keyboard, large text and screen-reader
  labels. No overflow; meaningful buttons at least 48 logical pixels high.
- Regression tests verify state changes and no unauthorized private calls.
- Run pinned Flutter analysis/tests, build Cloud-connected APK, install without
  deleting app data, then verify cold launch and each tab on the connected phone.

## Implementation order

1. Reproduce and fix session restore with regression tests.
2. Implement the unpaired/pending-invite layout and navigation callbacks.
3. Verify small-screen/loading/error/accessibility states.
4. Build/install and visually verify, then make short commits without co-authors.

No application code changed as part of the initial design proposal.

## Implementation verification — 5 October 2026

- Implemented single-flight session restoration with a 30-second UI bound. Late
  operations remain joined on retry; SDK JWT rotation/persistence remains in use.
  Definitively invalid credentials clear locally and return to email sign-in;
  transport failures preserve credentials. Pairing failures retry separately.
- Implemented distinct unpaired/pending-invite Widget UI: local preview, gallery
  and blank canvas, pairing navigation, collapsed launcher help, and no private
  library/schedule controls. Added loading/error and identity-change guards.
- Fixed Home's privacy-note wrapping so full-shell navigation tests run at
  360 × 780 instead of hiding an overflow behind a desktop-sized viewport.
- Full Flutter analysis: no issues. Full Flutter suite: **207 passed**.
- Cloud-connected debug APK built with isolated Flutter 3.47.6 and installed
  using `adb install -r` on CPH2531, preserving existing app data.
- Two actual process-stop/cold-launch checks reached the signed-in shell without
  Connection paused. Fresh UI observation confirmed selected Widget tab, local
  Choose a photo action, preview, and waiting-for-partner state on this device.
  No phone credentials or screen payloads were copied into this report.
- Historical invalid-refresh-secret origin is still unproven. Existing-token
  restore is now observed working; this does not prove every network/revocation
  scenario on a physical device. Those boundaries have automated regression tests.
- Physical gallery/export/widget save and two-device pairing remain manual
  acceptance checks; no partner invite or device photo was sent during this work.
