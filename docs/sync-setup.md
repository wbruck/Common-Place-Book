# Sync Backend Setup — Supabase + PowerSync

One-time provisioning runbook for cross-device sync (PRD: `tasks/prd-user-accounts-sync.md`).
These are **dashboard/console steps** plus SQL you paste into the Supabase SQL editor. Do them
once; the app code (Phases 1–2) then connects using the three public values recorded in
[§5 What to hand to the app](#5-what-to-hand-to-the-app).

Backend: **Supabase** (Postgres + Auth + RLS) + **PowerSync Cloud** (offline sync engine).

> **Conventions used below**
> - `<PROJECT_REF>` — your Supabase project ref (the subdomain in your project URL).
> - Replace every `CHANGE_ME...` placeholder with your own value and **do not commit secrets**.
> - IDs are `text` and timestamps are `bigint` (epoch milliseconds) to exactly match the Flutter
>   Drift schema, so no type mapping is needed during sync.

---

## 1. Supabase — create the project

1. Sign up / log in at https://supabase.com → **New project**.
2. Pick the org, name it `common-place-book`, set a strong **database password** (save it), choose the
   region closest to you, and create. Wait for provisioning (~2 min).
3. From **Project Settings → API**, record:
   - **Project URL** → `https://<PROJECT_REF>.supabase.co`  → app needs as `SUPABASE_URL`
   - **anon public** key → app needs as `SUPABASE_ANON_KEY` (safe to ship in the client)
   - The **service_role** key and **JWT secret** are server-only — never put them in the app.

> **Free tier note:** Free Supabase projects pause after ~1 week of inactivity. Fine once you have any
> active use; just expect the dev project to sleep if untouched.

---

## 2. Supabase — schema, RLS, grants, replication role

Open **SQL Editor → New query**, paste the whole script below, and run it. It mirrors the four syncable
tables, locks them down per-user with Row-Level Security, grants Data-API access (required for writes —
see note), and creates the replication role + publication PowerSync needs.

```sql
-- ============================================================
-- 1) Tables (mirror the Drift schema; text ids, bigint epoch-ms)
-- ============================================================
create table public.entries (
  id             text primary key,
  content        text not null,
  source         text,
  category_id    text,
  created_at     bigint not null,
  updated_at     bigint not null,
  last_viewed_at bigint,
  view_count     integer not null default 0,
  is_favorite    boolean not null default false,
  user_id        text not null,
  deleted_at     bigint           -- null = live; non-null = soft-deleted tombstone
);

create table public.tags (
  id          text primary key,
  name        text not null,
  color       text,
  created_at  bigint not null,
  user_id     text not null,
  deleted_at  bigint
);

-- NOTE: synthetic `id` PK (NOT the composite (entry_id, tag_id)).
-- PowerSync requires every synced table to have a single text column named `id` as its
-- primary key. The client keeps a unique index on (entry_id, tag_id); see PRD US-001 note.
create table public.entry_tags (
  id          text primary key,
  entry_id    text not null,
  tag_id      text not null,
  user_id     text not null,
  deleted_at  bigint
);

create table public.categories (
  id          text primary key,
  name        text not null,
  parent_id   text,
  icon        text,
  created_at  bigint not null,
  user_id     text not null,
  deleted_at  bigint
);

-- Helpful indexes (sync filters on user_id)
create index entries_user_idx     on public.entries (user_id);
create index tags_user_idx        on public.tags (user_id);
create index entry_tags_user_idx  on public.entry_tags (user_id);
create index entry_tags_pair_idx  on public.entry_tags (entry_id, tag_id);
create index categories_user_idx  on public.categories (user_id);

-- ============================================================
-- 2) Row-Level Security: a user can only touch their own rows
--    (auth.uid() is a uuid; user_id is text, so cast)
-- ============================================================
alter table public.entries    enable row level security;
alter table public.tags       enable row level security;
alter table public.entry_tags enable row level security;
alter table public.categories enable row level security;

create policy "own rows" on public.entries
  for all using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);
create policy "own rows" on public.tags
  for all using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);
create policy "own rows" on public.entry_tags
  for all using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);
create policy "own rows" on public.categories
  for all using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);

-- ============================================================
-- 3) Data-API grants (writes go through supabase-js / PostgREST).
--    Required: new Supabase projects no longer auto-expose public tables,
--    and explicit grants are enforced platform-wide by Oct 2026. Without
--    these, the client gets "permission denied" BEFORE RLS is evaluated.
-- ============================================================
grant select, insert, update, delete on public.entries    to authenticated;
grant select, insert, update, delete on public.tags       to authenticated;
grant select, insert, update, delete on public.entry_tags to authenticated;
grant select, insert, update, delete on public.categories to authenticated;

-- ============================================================
-- 4) PowerSync replication role + publication
--    PowerSync READS via logical replication (bypasses RLS, read-only).
-- ============================================================
create role powersync_role with replication bypassrls login password 'CHANGE_ME_STRONG_RANDOM_PW';
grant select on all tables in schema public to powersync_role;
alter default privileges in schema public grant select on tables to powersync_role;

-- Publication MUST be named exactly "powersync".
create publication powersync for table
  public.entries, public.tags, public.entry_tags, public.categories;
```

> Save the `powersync_role` password you chose — you paste it into PowerSync in §4. It is server-only.

---

## 3. Supabase — auth providers

### Email + password
Enabled by default. (Optional) under **Authentication → Providers → Email** you can require email
confirmation; for a personal app you may turn confirmation off during development.

### Sign in with Google — ⏸️ DEFERRED (skip for now)

> **Not needed to start.** Email/password (above) works with zero setup, and sync does not depend on
> the auth method. Do this later when you want the Google button (PRD US-006) — it's an isolated
> ~15-minute task that needs no schema or sync changes. Steps are kept here for when you're ready:

First create a Google OAuth client, then register it in Supabase.

1. **Google Cloud Console** (https://console.cloud.google.com) → create/select a project.
2. **APIs & Services → OAuth consent screen** → External → fill app name, support email, developer
   email. Add scopes `.../auth/userinfo.email`, `.../auth/userinfo.profile`. While in "Testing",
   add your own Google account under **Test users**.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID → Web application**.
   - **Authorized redirect URI:** `https://<PROJECT_REF>.supabase.co/auth/v1/callback`
   - Create, then copy the **Client ID** and **Client secret**.
4. **Supabase → Authentication → Providers → Google** → enable, paste the Client ID + secret, save.
   (Client secret is server-only — stored in Supabase, never in the app.)

> Native mobile Google sign-in (the nicer in-app UX via an Android/iOS OAuth client + ID-token flow)
> can be added during implementation. The Web client above is enough to get sign-in working on web and
> via the external-browser redirect flow on mobile.

### Redirect / Site URLs
**Authentication → URL Configuration:**
- **Site URL:** `https://common-place-book.pages.dev`
- **Additional Redirect URLs** (add each):
  - `https://common-place-book.pages.dev/**`
  - `https://*.common-place-book.pages.dev/**`  (Cloudflare per-branch previews)
  - `http://localhost:*/**`  (local `flutter run -d chrome`)
  - A mobile deep-link callback, finalized in implementation, e.g. `io.commonplacebook.app://login-callback/`

---

## 4. PowerSync Cloud — instance, connection, auth, sync rules

1. Sign up at https://www.powersync.com → create an account → **Create instance** (start on the free
   tier). Name it `common-place-book`.
2. **Connect the database** → PowerSync Dashboard → **Edit Instance → Database Connections** → add a
   Postgres connection:
   - Paste the **Direct connection** string from Supabase (**Connect** button → *Direct connection*),
     which looks like
     `postgresql://postgres:[PW]@db.<PROJECT_REF>.supabase.co:5432/postgres`.
   - **Replace the username/password** with the replication role you made:
     `postgresql://powersync_role:CHANGE_ME_STRONG_RANDOM_PW@db.<PROJECT_REF>.supabase.co:5432/postgres`
   - SSL: leave as `verify-full` (PowerSync bundles Supabase's CA). Test the connection.
3. **Client auth** → Dashboard → **Client Auth** → check **Use Supabase Auth**.
   - If your project still uses **legacy JWT signing keys**, copy the **JWT Secret** from
     Supabase → Settings → API/JWT Keys into the "Supabase JWT Secret (Legacy)" field.
   - If your project uses the **new asymmetric (JWKS) keys**, leave that field empty — PowerSync
     auto-configures the JWKS endpoint.
4. **Sync rules** → open the instance's `sync-rules.yaml` and replace its contents with:

   ```yaml
   config:
     edition: 3
   streams:
     user_data:
       auto_subscribe: true
       queries:
         - SELECT * FROM entries     WHERE user_id = auth.user_id()
         - SELECT * FROM tags        WHERE user_id = auth.user_id()
         - SELECT * FROM entry_tags  WHERE user_id = auth.user_id()
         - SELECT * FROM categories  WHERE user_id = auth.user_id()
   ```

   This syncs each signed-in user only their own rows. **Tombstones sync too** — we do *not* filter
   `deleted_at` here, so soft-deletes propagate; the app hides `deleted_at IS NOT NULL` rows locally.
5. Click **Save and Deploy**. Record the instance endpoint URL (looks like
   `https://<INSTANCE_ID>.powersync.journeyapps.com`) → app needs it as `POWERSYNC_URL`.

---

## 5. What to hand to the app

Three **public** values (safe in the client, supplied at build time via `--dart-define`):

| Name | Where to find it |
|---|---|
| `SUPABASE_URL` | Supabase → Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Supabase → Settings → API → anon public key |
| `POWERSYNC_URL` | PowerSync instance endpoint (§4.5) |

Example run once the app code lands:
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<PROJECT_REF>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-public-key> \
  --dart-define=POWERSYNC_URL=https://<INSTANCE_ID>.powersync.journeyapps.com
```

**Keep server-only (never in the app or git):** `powersync_role` password, Supabase JWT secret,
Supabase `service_role` key, Google client secret.

---

## 6. Quick validation (before app work)

- In Supabase **Table Editor**, manually insert a row into `entries` with some `user_id` → confirm it
  appears (logical replication healthy) in PowerSync's **Logs/Diagnostics** without errors.
- PowerSync **Diagnostics** shows the connection as "Connected" and sync rules deployed with no
  validation errors.
- (After Phase 1 auth exists) sign in, then from the SQL editor confirm a second fake user's rows are
  invisible to the first user via the Data API (RLS working).

---

## 7. Notes that affect the app code (for Phases 1–2)

- **`entry_tags` needs a text `id` PK** in the Drift schema too (PRD US-001), matching §2 above.
- The app declares a **PowerSync client `Schema`** mirroring these tables (US-010); PowerSync downloads
  into its managed SQLite, and Drift attaches via `drift_sqlite_async`.
- **Writes** go up through a PowerSync *backend connector* that calls `supabase-js`/`supabase_flutter`
  to upsert into Postgres — which is why the §2 `GRANT`s + RLS matter.
- Conflict model: last-write-wins by `updated_at`; deletes are soft (`deleted_at`).
- **LWW needs `updated_at` on every syncable table.** The §2 SQL currently only has `updated_at` on `entries`. Before Phase 2, add `updated_at bigint` to `tags` and `categories` (client schema + an `ALTER TABLE ... ADD COLUMN` on the provisioned Postgres) so tag/category edits carry a propagation timestamp. (`entry_tags` is insert/tombstone-only, so `deleted_at` is enough.) Tracked under PRD "Phase 0 — Build Status & Carried-Forward Items".
