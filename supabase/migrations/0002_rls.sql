-- CloseCall — Row Level Security + pairing RPC
-- Run after 0001_init.sql.

-- ──────────────────────────────────────────────────────────────────────────
-- Membership helper (SECURITY DEFINER so child-table policies can check the
-- couples table without needing their own read access to it).
-- ──────────────────────────────────────────────────────────────────────────
create or replace function public.is_member(c uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.couples
    where id = c and auth.uid() = any(member_ids)
  );
$$;

-- ──────────────────────────────────────────────────────────────────────────
-- Pairing: join a pending couple by code. SECURITY DEFINER so the joiner can
-- mutate a row they're not yet a member of, with all validation server-side.
-- ──────────────────────────────────────────────────────────────────────────
create or replace function public.join_couple(p_code text)
returns public.couples
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.couples;
begin
  select * into c from public.couples where pairing_code = p_code;
  if not found then
    raise exception 'code_not_found';
  end if;
  if auth.uid() = any(c.member_ids) then
    raise exception 'cannot_pair_with_self';
  end if;
  if coalesce(array_length(c.member_ids, 1), 0) >= 2 then
    raise exception 'already_paired';
  end if;

  update public.couples
    set member_ids = array_append(member_ids, auth.uid()),
        pairing_code = null
    where id = c.id
    returning * into c;
  return c;
end;
$$;

-- ──────────────────────────────────────────────────────────────────────────
-- Enable RLS
-- ──────────────────────────────────────────────────────────────────────────
alter table public.couples          enable row level security;
alter table public.widget_assets    enable row level security;
alter table public.widget_schedule  enable row level security;
alter table public.mood_check_ins   enable row level security;
alter table public.reminders        enable row level security;
alter table public.moments          enable row level security;

-- couples: members only (joining happens through join_couple()).
create policy couples_select on public.couples
  for select using (auth.uid() = any(member_ids));
create policy couples_insert on public.couples
  for insert with check (auth.uid() = any(member_ids));
create policy couples_update on public.couples
  for update using (auth.uid() = any(member_ids))
  with check (auth.uid() = any(member_ids));
create policy couples_delete on public.couples
  for delete using (auth.uid() = any(member_ids));

-- Child tables: access gated on couple membership.
create policy widget_assets_rw on public.widget_assets
  for all using (public.is_member(couple_id))
  with check (public.is_member(couple_id));
create policy widget_schedule_rw on public.widget_schedule
  for all using (public.is_member(couple_id))
  with check (public.is_member(couple_id));
create policy mood_rw on public.mood_check_ins
  for all using (public.is_member(couple_id))
  with check (public.is_member(couple_id));
create policy reminders_rw on public.reminders
  for all using (public.is_member(couple_id))
  with check (public.is_member(couple_id));
create policy moments_rw on public.moments
  for all using (public.is_member(couple_id))
  with check (public.is_member(couple_id));
