BEGIN;

CREATE UNIQUE INDEX "closecall_widget_send_couple_id_unique" ON "closecall_widget_send" USING btree ("coupleId", "id");

-- Durable FCM invalidation event. Payload is never stored here.
--
-- Class PushOutbox as table closecall_push_outbox
--
CREATE TABLE "closecall_push_outbox" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "coupleId" uuid NOT NULL,
    "sendId" uuid NOT NULL,
    "recipientMemberId" bigint NOT NULL,
    "version" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "attempts" bigint NOT NULL DEFAULT 0,
    "availableAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "leasedUntil" timestamp without time zone,
    "leaseOwner" text,
    "completedAt" timestamp without time zone,
    "lastError" text
);

-- Indexes
CREATE UNIQUE INDEX "closecall_push_outbox_send_version_unique" ON "closecall_push_outbox" USING btree ("sendId", "version");
CREATE INDEX "closecall_push_outbox_ready_idx" ON "closecall_push_outbox" USING btree ("completedAt", "availableAt");

ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_fk_0"
    FOREIGN KEY("coupleId") REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_fk_1"
    FOREIGN KEY("sendId") REFERENCES "closecall_widget_send"("id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_fk_2"
    FOREIGN KEY("recipientMemberId") REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_same_couple_send"
    FOREIGN KEY("coupleId", "sendId")
    REFERENCES "closecall_widget_send"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_push_outbox"
    ADD CONSTRAINT "closecall_push_outbox_same_couple_recipient"
    FOREIGN KEY("coupleId", "recipientMemberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE "closecall_push_outbox"
  ADD CONSTRAINT "closecall_push_outbox_valid"
  CHECK ("version" > 0 AND "attempts" >= 0);

INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('closecall', '20261006120000000-fcm-outbox', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261006120000000-fcm-outbox', "timestamp" = now();
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module") DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260924105232991', now())
    ON CONFLICT ("module") DO UPDATE SET "version" = '20260924105232991', "timestamp" = now();
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260924105404509', now())
    ON CONFLICT ("module") DO UPDATE SET "version" = '20260924105404509', "timestamp" = now();

COMMIT;
