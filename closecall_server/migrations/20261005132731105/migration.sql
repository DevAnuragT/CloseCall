BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "closecall_widget_delivery" (
    "id" bigserial PRIMARY KEY,
    "coupleId" uuid NOT NULL,
    "recipientMemberId" bigint NOT NULL,
    "autoUpdateEnabled" boolean NOT NULL DEFAULT false,
    "version" bigint NOT NULL DEFAULT 0,
    "assetId" uuid,
    "senderMemberId" bigint,
    "sentAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "closecall_widget_delivery_recipient_unique" ON "closecall_widget_delivery" USING btree ("recipientMemberId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "closecall_widget_send" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "coupleId" uuid NOT NULL,
    "senderMemberId" bigint NOT NULL,
    "recipientMemberId" bigint NOT NULL,
    "assetId" uuid NOT NULL,
    "requestId" text NOT NULL,
    "version" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "recipientAutoUpdateEnabled" boolean NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "closecall_widget_send_request_unique" ON "closecall_widget_send" USING btree ("coupleId", "requestId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "closecall_widget_delivery"
    ADD CONSTRAINT "closecall_widget_delivery_fk_0"
    FOREIGN KEY("coupleId")
    REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_delivery"
    ADD CONSTRAINT "closecall_widget_delivery_fk_1"
    FOREIGN KEY("recipientMemberId")
    REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_delivery"
    ADD CONSTRAINT "closecall_widget_delivery_fk_2"
    FOREIGN KEY("assetId")
    REFERENCES "closecall_media"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_delivery"
    ADD CONSTRAINT "closecall_widget_delivery_fk_3"
    FOREIGN KEY("senderMemberId")
    REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_delivery"
    ADD CONSTRAINT "closecall_widget_delivery_same_couple_asset"
    FOREIGN KEY("coupleId", "assetId")
    REFERENCES "closecall_media"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_delivery"
    ADD CONSTRAINT "closecall_widget_delivery_same_couple_sender"
    FOREIGN KEY("coupleId", "senderMemberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_delivery"
    ADD CONSTRAINT "closecall_widget_delivery_same_couple_recipient"
    FOREIGN KEY("coupleId", "recipientMemberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "closecall_widget_send"
    ADD CONSTRAINT "closecall_widget_send_fk_0"
    FOREIGN KEY("coupleId")
    REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_send"
    ADD CONSTRAINT "closecall_widget_send_fk_1"
    FOREIGN KEY("senderMemberId")
    REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_send"
    ADD CONSTRAINT "closecall_widget_send_fk_2"
    FOREIGN KEY("recipientMemberId")
    REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_send"
    ADD CONSTRAINT "closecall_widget_send_fk_3"
    FOREIGN KEY("assetId")
    REFERENCES "closecall_media"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_send"
    ADD CONSTRAINT "closecall_widget_send_same_couple_asset"
    FOREIGN KEY("coupleId", "assetId")
    REFERENCES "closecall_media"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_send"
    ADD CONSTRAINT "closecall_widget_send_same_couple_sender"
    FOREIGN KEY("coupleId", "senderMemberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_send"
    ADD CONSTRAINT "closecall_widget_send_same_couple_recipient"
    FOREIGN KEY("coupleId", "recipientMemberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR closecall
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('closecall', '20261005132731105', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261005132731105', "timestamp" = now();

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


ALTER TABLE "closecall_widget_delivery"
  ADD CONSTRAINT "closecall_widget_delivery_valid" CHECK ("version" >= 0 AND (("version" = 0 AND "assetId" IS NULL AND "senderMemberId" IS NULL AND "sentAt" IS NULL) OR ("version" > 0 AND "assetId" IS NOT NULL AND "senderMemberId" IS NOT NULL AND "sentAt" IS NOT NULL AND "senderMemberId" <> "recipientMemberId")));
ALTER TABLE "closecall_widget_send"
  ADD CONSTRAINT "closecall_widget_send_valid" CHECK ("version" > 0 AND "senderMemberId" <> "recipientMemberId" AND "requestId" ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
COMMIT;
