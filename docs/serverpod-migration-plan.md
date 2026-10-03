# CloseCall — Serverpod migration plan

## Goal

Keep the existing Flutter application and widget editor. Make Serverpod the
authoritative backend for identity, couple membership, private media, and widget
schedules. Firebase may remain a delivery transport for push notifications.
Supabase is a legacy implementation during migration, not the target backend.

## Milestones

1. **Foundation (implemented, locally verified):** pin a compatible repo-local Flutter SDK and Serverpod
   4; create server and generated client packages; remove the mandatory client
   `.env` asset; make clean-checkout tests reproducible.
2. **Development authentication and pairing (implemented, locally verified):** Serverpod authentication, persisted
   couple membership, authenticated create/join/read endpoints, atomic invite
   consumption, generated client adapter, and a Flutter connection/pairing flow.
   Email registration/login/password recovery are locally verified. Actual Cloud
   email delivery and physical-device validation remain pending.
3. **Private media (implemented, locally verified):** pick a photo, export the editor image, upload through
   authorised Serverpod endpoints, and retrieve it only as a couple member.
4. **Schedules (implemented, locally verified):** store UTC windows and fallback
   assets; reuse shared resolver rules; publish transitions through Serverpod,
   durable future-call wakes, live foreground timelines, and opt-in local cache
   sync. Closed-app delivery remains pending.
5. **Two-device delivery:** recipient refresh and foreground Android widget
   application are implemented. Background expiry/revert, offline recovery,
   reboot testing and physical-device validation remain pending.
6. **Submission:** cloud deployment, reproducible test build, real two-device demo,
   English setup instructions, AI-use disclosure, and a public video under two
   minutes. Submit before 14 October 2026 23:59 CEST / 15 October 03:29 IST.

## This iteration's boundaries

- Preserve all pre-existing uncommitted Android widget work.
- Do not delete Supabase migrations or private local configuration yet.
- Do not claim mock dashboard data or a same-device widget update is partner sync.
- Ship real authenticated, persistent pairing before expanding other features.
- Local anonymous Serverpod sign-in may bootstrap development without external
  credentials; it is experimental and not a recoverable production account.
- Server secrets stay in ignored password files or environment variables, never
  in client assets, committed examples, or diagnostic output.

## Acceptance checks

Foundation/authenticated-pairing source and database migration are implemented.
Local validation includes frontend/backend tests; cloud deployment and physical
two-device acceptance remain outstanding. See `serverpod-setup.md` for commands.

- App, generated client, and server analyze successfully on the pinned SDK.
- Existing Flutter tests remain green without a local `.env` file.
- Unauthenticated callers cannot access pairing endpoints.
- Create is idempotent while an invite is pending.
- Join rejects malformed, unknown, consumed, self, and already-paired cases.
- Concurrent joins cannot add a third member or reuse an invite.
- State persists and each authenticated user belongs to at most one couple.
- Flutter offers explicit demo mode and configured backend mode, with visible
  connection failures rather than silently substituting mock data.

## References

- Serverpod 4 setup: https://docs.serverpod.dev/quickstart
- Authentication: https://docs.serverpod.dev/concepts/authentication/setup
- Anonymous auth: https://docs.serverpod.dev/concepts/authentication/providers/anonymous/setup
- Official event rules: https://tinyurl.com/SP-rules
- Cloud plans: https://serverpod.dev/cloud (confirm future-call support before
  deploying scheduling; Starter currently excludes future calls).
