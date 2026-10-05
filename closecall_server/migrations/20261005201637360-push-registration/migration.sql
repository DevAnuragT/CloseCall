BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "closecall_push_device_registration" (
    "id" bigserial PRIMARY KEY,
    "coupleId" uuid NOT NULL,
    "memberId" bigint NOT NULL,
    "deviceId" text NOT NULL,
    "token" text NOT NULL,
    "platform" text,
    "appVersion" text,
    "updatedAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "closecall_push_registration_token_unique" ON "closecall_push_device_registration" USING btree ("token");
CREATE UNIQUE INDEX "closecall_push_registration_member_device_unique" ON "closecall_push_device_registration" USING btree ("memberId", "deviceId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "closecall_push_device_registration"
    ADD CONSTRAINT "closecall_push_device_registration_fk_0"
    FOREIGN KEY("coupleId")
    REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_push_device_registration"
    ADD CONSTRAINT "closecall_push_device_registration_fk_1"
    FOREIGN KEY("memberId")
    REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_push_device_registration"
    ADD CONSTRAINT "closecall_push_registration_same_couple_member"
    FOREIGN KEY("coupleId", "memberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR closecall
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('closecall', '20261005201637360-push-registration', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261005201637360-push-registration', "timestamp" = now();

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
