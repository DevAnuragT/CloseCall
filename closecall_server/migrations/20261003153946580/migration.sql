BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "closecall_media" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "coupleId" uuid NOT NULL,
    "uploaderId" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "width" bigint NOT NULL,
    "height" bigint NOT NULL,
    "requestId" text NOT NULL,
    "contentHash" text NOT NULL,
    "storagePath" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "closecall_media_request_unique" ON "closecall_media" USING btree ("coupleId", "requestId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "closecall_media"
    ADD CONSTRAINT "closecall_media_fk_0"
    FOREIGN KEY("coupleId")
    REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR closecall
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('closecall', '20261003153946580', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261003153946580', "timestamp" = now();

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
