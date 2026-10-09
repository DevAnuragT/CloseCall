BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "closecall_widget_device_credential" (
    "id" bigserial PRIMARY KEY,
    "coupleId" uuid NOT NULL,
    "memberId" bigint NOT NULL,
    "userIdentifier" text NOT NULL,
    "deviceId" text NOT NULL,
    "credentialHash" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "expiresAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "closecall_widget_credential_hash_unique" ON "closecall_widget_device_credential" USING btree ("credentialHash");
CREATE UNIQUE INDEX "closecall_widget_credential_member_device_unique" ON "closecall_widget_device_credential" USING btree ("memberId", "deviceId");
CREATE UNIQUE INDEX "closecall_widget_credential_user_device_unique" ON "closecall_widget_device_credential" USING btree ("userIdentifier", "deviceId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "closecall_widget_device_credential"
    ADD CONSTRAINT "closecall_widget_device_credential_fk_0"
    FOREIGN KEY("coupleId")
    REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_device_credential"
    ADD CONSTRAINT "closecall_widget_device_credential_fk_1"
    FOREIGN KEY("memberId")
    REFERENCES "closecall_couple_member"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_widget_device_credential"
    ADD CONSTRAINT "closecall_widget_credential_same_couple_member"
    FOREIGN KEY("coupleId", "memberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

ALTER TABLE "closecall_widget_device_credential"
  ADD CONSTRAINT "closecall_widget_credential_valid"
  CHECK ("credentialHash" ~ '^[0-9a-f]{64}$'
    AND length("deviceId") BETWEEN 1 AND 128
    AND "deviceId" !~ '[[:space:][:cntrl:]]'
    AND length("userIdentifier") > 0
    AND "expiresAt" > "createdAt"
    AND "expiresAt" - "createdAt" <= INTERVAL '24 hours');

-- MIGRATION VERSION FOR closecall
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('closecall', '20261006224415374-widget-device-credentials', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261006224415374-widget-device-credentials', "timestamp" = now();

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
