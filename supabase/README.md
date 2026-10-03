# CloseCall — Supabase setup

> Legacy setup, retained for migration reference. The app now selects Serverpod
> through `SERVERPOD_URL` and never initializes Supabase at startup. `.env` is no
> longer loaded or bundled. See `../docs/serverpod-setup.md` for current setup.

## 1. Run the migrations

In the Supabase dashboard → **SQL Editor**, run these in order:

1. `migrations/0001_init.sql` — tables + indexes
2. `migrations/0002_rls.sql` — Row Level Security + the `join_couple` RPC

(Or, with the Supabase CLI linked to the project: `supabase db push`.)

## 2. Enable Google auth

Dashboard → **Authentication → Providers → Google**: enable it and paste your
Google OAuth client id/secret. We use **Supabase Auth** for identity (not
Firebase Auth) so that `auth.uid()` drives the RLS policies above. Firebase is
only used for Cloud Messaging.

## 3. Enable Realtime

Dashboard → **Database → Replication** (or Realtime): enable realtime on
`mood_check_ins` and `widget_schedule` so partner updates push live.

## 4. Create the storage bucket

Dashboard → **Storage**: create a bucket named `widget-photos` (private). Edited
widget photos and moment media upload here; `widget_assets.storage_path` points
into it.

## 5. Run the app with credentials

The anon/publishable key is injected at build time — it is never committed:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

> The publishable key is safe in the client **only because RLS is enabled** on
> every table. It is not the service-role key.
