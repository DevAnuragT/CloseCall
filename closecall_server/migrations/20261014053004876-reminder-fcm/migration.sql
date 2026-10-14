BEGIN;

--
-- ACTION ALTER TABLE
--
CREATE UNIQUE INDEX "closecall_reminder_couple_id_unique" ON "closecall_reminder" USING btree ("coupleId", "id");
--
-- ACTION CREATE TABLE
--
CREATE TABLE "closecall_reminder_event_outbox" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "coupleId" uuid NOT NULL,
    "reminderId" uuid NOT NULL,
    "recipientMemberId" bigint NOT NULL,
    "eventType" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "attempts" bigint NOT NULL DEFAULT 0,
    "availableAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "leasedUntil" timestamp without time zone,
    "leaseOwner" text,
    "expiresAt" timestamp without time zone NOT NULL,
    "completedAt" timestamp without time zone,
    "lastError" text
);

-- Indexes
CREATE UNIQUE INDEX "closecall_reminder_event_unique" ON "closecall_reminder_event_outbox" USING btree ("reminderId", "recipientMemberId", "eventType");
CREATE INDEX "closecall_reminder_event_ready_idx" ON "closecall_reminder_event_outbox" USING btree ("completedAt", "availableAt");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "closecall_reminder_event_outbox"
    ADD CONSTRAINT "closecall_reminder_event_outbox_fk_0"
    FOREIGN KEY("coupleId")
    REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_reminder_event_outbox"
    ADD CONSTRAINT "closecall_reminder_event_outbox_fk_1"
    FOREIGN KEY("reminderId")
    REFERENCES "closecall_reminder"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_reminder_event_outbox"
    ADD CONSTRAINT "closecall_reminder_event_outbox_fk_2"
    FOREIGN KEY("recipientMemberId")
    REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_reminder_event_outbox"
    ADD CONSTRAINT "closecall_reminder_event_same_couple_reminder"
    FOREIGN KEY("coupleId", "reminderId")
    REFERENCES "closecall_reminder"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_reminder_event_outbox"
    ADD CONSTRAINT "closecall_reminder_event_same_couple_recipient"
    FOREIGN KEY("coupleId", "recipientMemberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

ALTER TABLE "closecall_reminder_event_outbox"
  ADD CONSTRAINT "closecall_reminder_event_valid"
  CHECK ("eventType" = 'reminder_created'
    AND "attempts" >= 0
    AND "expiresAt" > "createdAt"
    AND (("leasedUntil" IS NULL AND "leaseOwner" IS NULL)
      OR ("leasedUntil" IS NOT NULL AND "leaseOwner" IS NOT NULL
        AND length(btrim("leaseOwner")) > 0)));

-- MIGRATION VERSION FOR closecall
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('closecall', '20261014053004876-reminder-fcm', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014053004876-reminder-fcm', "timestamp" = now();

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
