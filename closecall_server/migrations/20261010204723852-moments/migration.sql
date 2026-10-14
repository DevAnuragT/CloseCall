BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "closecall_moment" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "coupleId" uuid NOT NULL,
    "authorMemberId" bigint NOT NULL,
    "authorId" text NOT NULL,
    "text" text NOT NULL,
    "kind" text NOT NULL,
    "durationMs" bigint,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "requestId" text NOT NULL,
    "contentHash" text NOT NULL,
    "storagePath" text,
    "deletedAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "closecall_moment_request_unique" ON "closecall_moment" USING btree ("coupleId", "requestId");
CREATE INDEX "closecall_moment_timeline" ON "closecall_moment" USING btree ("coupleId", "createdAt", "id");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "closecall_moment"
    ADD CONSTRAINT "closecall_moment_fk_0"
    FOREIGN KEY("coupleId")
    REFERENCES "closecall_couple"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "closecall_moment"
    ADD CONSTRAINT "closecall_moment_same_couple_author"
    FOREIGN KEY("coupleId", "authorMemberId")
    REFERENCES "closecall_couple_member"("coupleId", "id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

ALTER TABLE "closecall_moment"
  ADD CONSTRAINT "closecall_moment_valid"
  CHECK (length("text") <= 1000
    AND length("authorId") > 0
    AND "requestId" ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    AND "contentHash" ~ '^[0-9a-f]{64}$'
    AND (("deletedAt" IS NOT NULL AND "text" = '' AND "storagePath" IS NULL)
      OR ("deletedAt" IS NULL AND
        (("kind" = 'text' AND length(btrim("text")) > 0 AND "durationMs" IS NULL AND "storagePath" IS NULL)
         OR ("kind" = 'voice' AND "durationMs" IS NOT NULL AND "durationMs" BETWEEN 1 AND 30000 AND "storagePath" IS NOT NULL))))
    AND "kind" IN ('text', 'voice'));

-- MIGRATION VERSION FOR closecall
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('closecall', '20261010204723852-moments', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261010204723852-moments', "timestamp" = now();

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
