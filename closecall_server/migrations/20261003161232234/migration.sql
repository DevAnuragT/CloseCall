BEGIN;

--
-- ACTION ALTER TABLE
--
CREATE UNIQUE INDEX "closecall_member_couple_id_unique" ON "closecall_couple_member" USING btree ("coupleId", "id");
--
-- ACTION ALTER TABLE
--
CREATE UNIQUE INDEX "closecall_media_couple_asset_unique" ON "closecall_media" USING btree ("coupleId", "id");
--
-- ACTION CREATE TABLE
--
CREATE TABLE "closecall_widget_fallback" (
    "id" bigserial PRIMARY KEY,
    "coupleId" uuid NOT NULL,
    "recipientMemberId" bigint NOT NULL,
    "assetId" uuid NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "closecall_widget_fallback_recipient_unique" ON "closecall_widget_fallback" USING btree ("recipientMemberId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "closecall_widget_schedule" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "coupleId" uuid NOT NULL,
    "assetId" uuid NOT NULL,
    "senderMemberId" bigint NOT NULL,
    "recipientMemberId" bigint NOT NULL,
    "activeFrom" timestamp without time zone NOT NULL,
    "activeUntil" timestamp without time zone NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "requestId" text NOT NULL,
    "payloadHash" text NOT NULL,
    "cancelledAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "closecall_widget_request_unique" ON "closecall_widget_schedule" USING btree ("senderMemberId", "requestId");
CREATE INDEX "closecall_widget_recipient_idx" ON "closecall_widget_schedule" USING btree ("recipientMemberId", "activeUntil");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "closecall_widget_fallback"
    ADD CONSTRAINT "closecall_widget_fallback_fk_0"
    FOREIGN KEY("coupleId")
    REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_fallback"
    ADD CONSTRAINT "closecall_widget_fallback_fk_1"
    FOREIGN KEY("recipientMemberId")
    REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_fallback"
    ADD CONSTRAINT "closecall_widget_fallback_fk_2"
    FOREIGN KEY("assetId")
    REFERENCES "closecall_media"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "closecall_widget_schedule"
    ADD CONSTRAINT "closecall_widget_schedule_fk_0"
    FOREIGN KEY("coupleId")
    REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_schedule"
    ADD CONSTRAINT "closecall_widget_schedule_fk_1"
    FOREIGN KEY("assetId")
    REFERENCES "closecall_media"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_schedule"
    ADD CONSTRAINT "closecall_widget_schedule_fk_2"
    FOREIGN KEY("senderMemberId")
    REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_schedule"
    ADD CONSTRAINT "closecall_widget_schedule_fk_3"
    FOREIGN KEY("recipientMemberId")
    REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR closecall
--
-- Reviewed SQL-only invariants: the Serverpod model DSL cannot express
-- composite same-couple relations or CHECKs. Unique referenced indexes above
-- include the existing primary key, so they cannot reject pre-existing rows.
ALTER TABLE "closecall_widget_schedule"
    ADD CONSTRAINT "closecall_widget_schedule_same_couple_asset"
        FOREIGN KEY ("coupleId", "assetId")
        REFERENCES "closecall_media" ("coupleId", "id") ON DELETE CASCADE,
    ADD CONSTRAINT "closecall_widget_schedule_same_couple_sender"
        FOREIGN KEY ("coupleId", "senderMemberId")
        REFERENCES "closecall_couple_member" ("coupleId", "id") ON DELETE CASCADE,
    ADD CONSTRAINT "closecall_widget_schedule_same_couple_recipient"
        FOREIGN KEY ("coupleId", "recipientMemberId")
        REFERENCES "closecall_couple_member" ("coupleId", "id") ON DELETE CASCADE,
    ADD CONSTRAINT "closecall_widget_schedule_distinct_members"
        CHECK ("senderMemberId" <> "recipientMemberId"),
    ADD CONSTRAINT "closecall_widget_schedule_valid_window"
        CHECK ("activeUntil" > "activeFrom" AND
               "activeUntil" - "activeFrom" <= INTERVAL '7 days');
ALTER TABLE "closecall_widget_fallback"
    ADD CONSTRAINT "closecall_widget_fallback_same_couple_asset"
        FOREIGN KEY ("coupleId", "assetId")
        REFERENCES "closecall_media" ("coupleId", "id") ON DELETE CASCADE,
    ADD CONSTRAINT "closecall_widget_fallback_same_couple_recipient"
        FOREIGN KEY ("coupleId", "recipientMemberId")
        REFERENCES "closecall_couple_member" ("coupleId", "id") ON DELETE CASCADE;

INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('closecall', '20261003161232234', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261003161232234', "timestamp" = now();

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
