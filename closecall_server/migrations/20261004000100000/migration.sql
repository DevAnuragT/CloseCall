BEGIN;

-- Idempotent, versioned same-couple invariant repair.
ALTER TABLE "closecall_widget_schedule" DROP CONSTRAINT IF EXISTS "closecall_widget_schedule_same_couple_asset";
ALTER TABLE "closecall_widget_schedule" DROP CONSTRAINT IF EXISTS "closecall_widget_schedule_same_couple_sender";
ALTER TABLE "closecall_widget_schedule" DROP CONSTRAINT IF EXISTS "closecall_widget_schedule_same_couple_recipient";
ALTER TABLE "closecall_widget_schedule" ADD CONSTRAINT "closecall_widget_schedule_same_couple_asset" FOREIGN KEY ("coupleId", "assetId") REFERENCES "closecall_media" ("coupleId", "id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "closecall_widget_schedule" ADD CONSTRAINT "closecall_widget_schedule_same_couple_sender" FOREIGN KEY ("coupleId", "senderMemberId") REFERENCES "closecall_couple_member" ("coupleId", "id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "closecall_widget_schedule" ADD CONSTRAINT "closecall_widget_schedule_same_couple_recipient" FOREIGN KEY ("coupleId", "recipientMemberId") REFERENCES "closecall_couple_member" ("coupleId", "id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "closecall_widget_fallback" DROP CONSTRAINT IF EXISTS "closecall_widget_fallback_same_couple_asset";
ALTER TABLE "closecall_widget_fallback" DROP CONSTRAINT IF EXISTS "closecall_widget_fallback_same_couple_recipient";
ALTER TABLE "closecall_widget_fallback" ADD CONSTRAINT "closecall_widget_fallback_same_couple_asset" FOREIGN KEY ("coupleId", "assetId") REFERENCES "closecall_media" ("coupleId", "id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "closecall_widget_fallback" ADD CONSTRAINT "closecall_widget_fallback_same_couple_recipient" FOREIGN KEY ("coupleId", "recipientMemberId") REFERENCES "closecall_couple_member" ("coupleId", "id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "closecall_widget_schedule" DROP CONSTRAINT IF EXISTS "closecall_widget_schedule_distinct_members";
ALTER TABLE "closecall_widget_schedule" DROP CONSTRAINT IF EXISTS "closecall_widget_schedule_valid_window";
ALTER TABLE "closecall_widget_schedule"
  ADD CONSTRAINT "closecall_widget_schedule_distinct_members" CHECK ("senderMemberId" <> "recipientMemberId"),
  ADD CONSTRAINT "closecall_widget_schedule_valid_window" CHECK ("activeUntil" > "activeFrom" AND "activeUntil" - "activeFrom" <= INTERVAL '7 days');
INSERT INTO serverpod_migrations (module, version, timestamp) VALUES ('closecall', '20261004000100000', now()) ON CONFLICT (module) DO UPDATE SET version = '20261004000100000', timestamp = now();
COMMIT;
