-- CloseCall — initial schema (Supabase / PostgreSQL)
-- Run in the Supabase SQL editor, or via `supabase db push`.
--
-- Identity: assumes **Supabase Auth** (auth.uid()). Firebase is used only for
-- Cloud Messaging, not auth — this is what makes the RLS below work.

-- ──────────────────────────────────────────────────────────────────────────
-- Tables
-- ──────────────────────────────────────────────────────────────────────────

create table if not exists public.couples (
  id                uuid primary key default gen_random_uuid(),
  member_ids        uuid[] not null default '{}',
  partner_nickname  text,
  anniversary       timestamptz,
  theme_key         text not null default 'blush',
  fallback_asset_id uuid,
  pairing_code      text unique,
  created_at        timestamptz not null default now()
);

create table if not exists public.widget_assets (
  id           uuid primary key default gen_random_uuid(),
  couple_id    uuid not null references public.couples(id) on delete cascade,
  uploader_id  uuid not null,
  storage_path text not null,
  created_at   timestamptz not null default now()
);

create table if not exists public.widget_schedule (
  id           uuid primary key default gen_random_uuid(),
  couple_id    uuid not null references public.couples(id) on delete cascade,
  asset_id     uuid not null references public.widget_assets(id) on delete cascade,
  active_from  timestamptz not null,
  active_until timestamptz not null,
  created_at   timestamptz not null default now(),
  constraint widget_schedule_window check (active_until > active_from)
);

create table if not exists public.mood_check_ins (
  id         uuid primary key default gen_random_uuid(),
  couple_id  uuid not null references public.couples(id) on delete cascade,
  user_id    uuid not null,
  mood       text not null,
  note       text,
  created_at timestamptz not null default now()
);

create table if not exists public.reminders (
  id         uuid primary key default gen_random_uuid(),
  couple_id  uuid not null references public.couples(id) on delete cascade,
  title      text not null,
  kind       text not null,
  remind_at  timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.moments (
  id           uuid primary key default gen_random_uuid(),
  couple_id    uuid not null references public.couples(id) on delete cascade,
  author_id    uuid not null,
  type         text not null,          -- photo | note | doodle | voice | update
  body         text,
  storage_path text,
  is_favorite  boolean not null default false,
  created_at   timestamptz not null default now()
);

-- Add the deferred FK now that widget_assets exists.
alter table public.couples
  drop constraint if exists couples_fallback_asset_fk;
alter table public.couples
  add constraint couples_fallback_asset_fk
  foreign key (fallback_asset_id) references public.widget_assets(id)
  on delete set null;

create index if not exists idx_schedule_couple on public.widget_schedule(couple_id);
create index if not exists idx_mood_couple on public.mood_check_ins(couple_id, created_at desc);
create index if not exists idx_reminders_couple on public.reminders(couple_id, remind_at);
create index if not exists idx_moments_couple on public.moments(couple_id, created_at desc);
