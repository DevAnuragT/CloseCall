BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "closecall_couple_member" ADD COLUMN IF NOT EXISTS "ownNickname" text;
ALTER TABLE "closecall_couple_member" ADD COLUMN IF NOT EXISTS "partnerNickname" text;
ALTER TABLE "closecall_couple_member" ADD COLUMN IF NOT EXISTS "nicknamesUpdatedAt" timestamp without time zone;
--
-- ACTION ALTER TABLE
--
ALTER TABLE "closecall_push_device_registration" DROP CONSTRAINT IF EXISTS "closecall_push_registration_same_couple_member";
ALTER TABLE ONLY "closecall_push_device_registration"
    ADD CONSTRAINT "closecall_push_registration_same_couple_member"
    FOREIGN KEY("coupleId", "memberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
--
-- ACTION ALTER TABLE
--
ALTER TABLE "closecall_widget_delivery" DROP CONSTRAINT IF EXISTS "closecall_widget_delivery_same_couple_asset";
ALTER TABLE "closecall_widget_delivery" DROP CONSTRAINT IF EXISTS "closecall_widget_delivery_same_couple_sender";
ALTER TABLE "closecall_widget_delivery" DROP CONSTRAINT IF EXISTS "closecall_widget_delivery_same_couple_recipient";
ALTER TABLE ONLY "closecall_widget_delivery"
    ADD CONSTRAINT "closecall_widget_delivery_same_couple_asset"
    FOREIGN KEY("coupleId", "assetId") REFERENCES "closecall_media"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_delivery"
    ADD CONSTRAINT "closecall_widget_delivery_same_couple_sender"
    FOREIGN KEY("coupleId", "senderMemberId") REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_delivery"
    ADD CONSTRAINT "closecall_widget_delivery_same_couple_recipient"
    FOREIGN KEY("coupleId", "recipientMemberId") REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
--
-- ACTION ALTER TABLE
--
ALTER TABLE "closecall_widget_fallback" DROP CONSTRAINT IF EXISTS "closecall_widget_fallback_same_couple_asset";
ALTER TABLE "closecall_widget_fallback" DROP CONSTRAINT IF EXISTS "closecall_widget_fallback_same_couple_recipient";
ALTER TABLE ONLY "closecall_widget_fallback"
    ADD CONSTRAINT "closecall_widget_fallback_same_couple_asset"
    FOREIGN KEY("coupleId", "assetId") REFERENCES "closecall_media"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_fallback"
    ADD CONSTRAINT "closecall_widget_fallback_same_couple_recipient"
    FOREIGN KEY("coupleId", "recipientMemberId") REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
--
-- ACTION ALTER TABLE
--
ALTER TABLE "closecall_widget_schedule" DROP CONSTRAINT IF EXISTS "closecall_widget_schedule_same_couple_asset";
ALTER TABLE "closecall_widget_schedule" DROP CONSTRAINT IF EXISTS "closecall_widget_schedule_same_couple_sender";
ALTER TABLE "closecall_widget_schedule" DROP CONSTRAINT IF EXISTS "closecall_widget_schedule_same_couple_recipient";
ALTER TABLE ONLY "closecall_widget_schedule"
    ADD CONSTRAINT "closecall_widget_schedule_same_couple_asset"
    FOREIGN KEY("coupleId", "assetId") REFERENCES "closecall_media"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_schedule"
    ADD CONSTRAINT "closecall_widget_schedule_same_couple_sender"
    FOREIGN KEY("coupleId", "senderMemberId") REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_schedule"
    ADD CONSTRAINT "closecall_widget_schedule_same_couple_recipient"
    FOREIGN KEY("coupleId", "recipientMemberId") REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
--
-- ACTION ALTER TABLE
--
ALTER TABLE "closecall_widget_send" DROP CONSTRAINT IF EXISTS "closecall_widget_send_same_couple_asset";
ALTER TABLE "closecall_widget_send" DROP CONSTRAINT IF EXISTS "closecall_widget_send_same_couple_sender";
ALTER TABLE "closecall_widget_send" DROP CONSTRAINT IF EXISTS "closecall_widget_send_same_couple_recipient";
ALTER TABLE ONLY "closecall_widget_send"
    ADD CONSTRAINT "closecall_widget_send_same_couple_asset"
    FOREIGN KEY("coupleId", "assetId") REFERENCES "closecall_media"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_send"
    ADD CONSTRAINT "closecall_widget_send_same_couple_sender"
    FOREIGN KEY("coupleId", "senderMemberId") REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_send"
    ADD CONSTRAINT "closecall_widget_send_same_couple_recipient"
    FOREIGN KEY("coupleId", "recipientMemberId") REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;

--
-- MIGRATION VERSION FOR closecall
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('closecall', '20261006081030595-nicknames', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261006081030595-nicknames', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260924105232991', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105232991', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260924105404509', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105404509', "timestamp" = now();


COMMIT;
