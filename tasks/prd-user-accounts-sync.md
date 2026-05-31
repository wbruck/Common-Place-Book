# PRD: User Accounts & Cross-Device Entry Sync

## Introduction

Common Place Book today stores every entry, tag, and category **only** on the device that created it — IndexedDB/OPFS in the browser, or SQLite on the Android/iOS device. There is no way to see the quotes you saved on your phone when you open the web app, and a lost device means lost data.

This feature adds an **optional user account**. The app stays fully usable with no account (local-first), exactly as it works today. When a user signs in, the app **non-destructively** merges their local-only entries up to the cloud and pulls down any entries already in the cloud, then keeps every signed-in device in sync going forward.

The core promise to the user is: **signing in never deletes or loses an entry.** The first sync is a union of "what's on this device" and "what's in the cloud."

This PRD also documents the backend research the owner requested (cost-per-user + development effort) and the resulting recommendation. See [Technical Considerations § Backend Selection](#71-backend-selection-research-summary).

## Goals

- Let a user create an account and sign in on any device (Web, Android, iOS).
- Keep the app **100% usable logged out** — accounts are opt-in; local storage remains the source of truth on each device.
- On first sign-in, **non-destructively merge**: push device/browser-only entries to the cloud *and* pull cloud entries to the device. No entry is dropped on either side.
- Keep all signed-in devices in two-way sync afterward (create / edit / delete propagate).
- Make deletes safe and consistent across devices via **soft deletes** (a delete on one device removes the entry on the others; nothing is hard-deleted out from under a sync).
- Stay at **$0 cost** for a personal-scale userbase, with a clear, cheap path as it grows.
- Minimize development effort by reusing the existing repository abstraction and Drift watch-streams instead of rewriting features.

## User Stories

> **Sequencing:** Stories are grouped into phases. Each phase leaves the app shippable. Phase 0 and most of Phase 1 are backend-agnostic; Phase 2 assumes the recommended **Supabase + PowerSync** backend (see Technical Considerations). Do the phases in order.

> **Conventions for every code story below:** acceptance criteria implicitly require that `flutter analyze` passes with zero new warnings, new logic has tests and `flutter test` passes, and the work is committed with a message starting with the story ID (e.g. `US-001: ...`). UI stories additionally require manual verification in a browser via `flutter run -d chrome` (use the `verify` skill).

---

### Phase 0 — Schema & soft-delete groundwork (no backend yet)

#### US-001: Add sync metadata columns and bump schema to v3
**Description:** As a developer, I need every syncable row to carry an owner and a soft-delete marker so rows can be attributed to a user and tombstoned instead of hard-deleted.

**Acceptance Criteria:**
- [ ] Add `userId TEXT NULL` and `deletedAt INTEGER NULL` (epoch ms) to `Entries`, `Tags`, `Categories`, and `EntryTags`.
- [ ] Give `EntryTags` a synthetic `id TEXT` primary key (PowerSync requires every synced table to have a single text `id` PK); replace the composite PK with a **unique index** on `(entryId, tagId)` to preserve the existing constraint. Backfill `id` with a UUID for existing rows in the migration. (Mirrors `docs/sync-setup.md` §2.)
- [ ] Bump `schemaVersion` to `3` in `lib/core/database/database.dart`.
- [ ] Write an `onUpgrade` migration (v2→v3) that adds the columns and leaves existing rows with `userId = NULL`, `deletedAt = NULL` (a NULL `userId` means "local-only, not yet synced").
- [ ] Migration is safe on an existing populated DB (verified by a migration test that opens a v2 DB, upgrades, and asserts existing rows survive with new columns null).
- [ ] `dart run build_runner build --delete-conflicting-outputs` regenerates `database.g.dart` cleanly.
- [ ] `flutter test` passes (including the new migration test); `flutter analyze` clean.
- [ ] Commit with message starting `US-001:`.

#### US-002: Convert hard deletes to soft deletes
**Description:** As a user, I want a deleted entry to be reliably removable across devices, so I need deletes to set `deletedAt` rather than physically removing the row (a physically-missing row is ambiguous to sync).

**Acceptance Criteria:**
- [ ] `LocalEntryRepository.deleteEntry` sets `deletedAt = now` and bumps `updatedAt` instead of issuing a `DELETE`.
- [ ] Same soft-delete treatment for tags and entry_tag links where the app exposes deletion.
- [ ] All read queries/streams (`getAllEntries`, `watchAllEntries`, search, random, favorites, by-tag, counts) filter out rows where `deletedAt IS NOT NULL`.
- [ ] A soft-deleted entry disappears from every list/screen exactly as a hard delete did before (no behavior change visible to the user).
- [ ] Tests cover: delete hides the entry from all read paths; a soft-deleted entry is not returned by `getEntryById`.
- [ ] `flutter test` + `flutter analyze` pass.
- [ ] Verify in browser (`flutter run -d chrome`) using the `verify` skill: create an entry, delete it, confirm it's gone from the list and search.
- [ ] Commit with message starting `US-002:`.

#### US-003: Periodic purge of old tombstones
**Description:** As a developer, I want soft-deleted rows cleaned up after they've had time to propagate, so the local DB doesn't grow forever.

**Acceptance Criteria:**
- [ ] A maintenance routine hard-deletes rows where `deletedAt` is older than a configurable threshold (default 30 days) **and** the row is confirmed synced (or `userId IS NULL`, i.e. never synced).
- [ ] Runs at most once per app session (e.g. on startup, off the UI thread).
- [ ] Test verifies rows newer than the threshold are kept and older confirmed-synced rows are purged.
- [ ] `flutter test` + `flutter analyze` pass.
- [ ] Commit with message starting `US-003:`.

---

### Phase 1 — Auth shell (accounts, no sync yet)

#### US-004: Initialize Supabase and add an AuthService
**Description:** As a developer, I need an authentication backend wired up and a clean interface for auth state so the rest of the app can react to sign-in/sign-out.

**Acceptance Criteria:**
- [ ] Add `supabase_flutter` to `pubspec.yaml`; commit the updated `pubspec.lock`.
- [ ] Initialize Supabase in `lib/main.dart` before `runApp` using config from `--dart-define` (no secrets committed).
- [ ] New `lib/core/auth/auth_service.dart` exposes: an auth-state stream (a coarse `AuthSessionState` signed-in/out enum — intentional, to avoid leaking the backend event model), `User? currentUser`, and methods `signUpWithEmail`, `signInWithEmail`, `signOut`, `sendPasswordResetEmail`, returning `Result<T>` (`lib/core/utils/result.dart`). (`signInWithGoogle` moves to the deferred US-006; not part of US-004.)
- [ ] All auth diagnostics go through `AppLogger` (no new logger).
- [ ] Unit test with a mocked Supabase client covers the state stream emitting signed-in/signed-out and error → `Result.failure` mapping.
- [ ] `flutter test` + `flutter analyze` pass.
- [ ] Commit with message starting `US-004:`.

#### US-005: Email + password sign-up / sign-in screen
**Description:** As a user, I want to create an account or sign in with email and password so I can enable sync.

**Acceptance Criteria:**
- [ ] New `lib/features/auth/presentation/screens/login_screen.dart` with email + password fields, a sign-in/sign-up toggle, and a "forgot password" link that triggers Supabase password reset.
- [ ] Client-side validation: valid email format, password min length; inline error messages.
- [ ] Backend errors (wrong password, email already registered) surface as readable messages, not stack traces.
- [ ] Route added to `lib/app/router.dart` (named route, e.g. `/login`).
- [ ] Loading state shown during the auth request; button disabled while in flight.
- [ ] Widget test covers validation and the success/error branches with a mocked `AuthService`.
- [ ] `flutter test` + `flutter analyze` pass.
- [ ] Verify in browser (`flutter run -d chrome`) using the `verify` skill: sign up, sign out, sign back in; confirm a wrong password shows a friendly error.
- [ ] Commit with message starting `US-005:`.

#### US-006: Sign in with Google — ⏸️ DEFERRED
> **Deferred (2026-05-30):** Not required for the initial sync release. Ship email/password (US-005) first; add this when convenient — it's additive and needs no backend schema or sync changes. The matching Google OAuth provisioning is likewise deferred in `docs/sync-setup.md` §3.

**Description:** As a user, I want to sign in with my Google account so I don't have to manage another password.

**Acceptance Criteria:**
- [ ] "Continue with Google" button on the login screen calls `AuthService.signInWithGoogle`.
- [ ] OAuth works on Web (redirect) and Android (native/app-link callback); document the per-platform OAuth client setup in `docs/` or the PR description.
- [ ] After Google sign-in the app reaches the same signed-in state as email/password (single `User`).
- [ ] iOS is configured but may be deferred to US-014 if App Store "Sign in with Apple" is required alongside; note the dependency.
- [ ] `flutter analyze` passes; widget test covers the button invoking the service.
- [ ] Verify in browser (`flutter run -d chrome`) using the `verify` skill: complete a Google sign-in round-trip and land signed-in.
- [ ] Commit with message starting `US-006:`.

#### US-007: Optional-login UX and session persistence
**Description:** As a user, I want to keep using the app without an account, and choose to sign in from Settings, with my session remembered across restarts.

**Acceptance Criteria:**
- [ ] The app is fully functional with **no** account — logged-out is the default and no screen is gated behind auth.
- [ ] Settings shows account state: signed-out → "Sign in to sync across devices" (routes to `/login`); signed-in → account email + "Sign out".
- [ ] Session persists across app restarts on Web and mobile (verified by relaunch).
- [ ] Signing out returns to the local-first state and **keeps** the local copy of all entries (sign-out is non-destructive; see US-013 for the exact rule).
- [ ] Widget test covers the signed-in vs signed-out Settings rendering.
- [ ] `flutter test` + `flutter analyze` pass.
- [ ] Verify in browser (`flutter run -d chrome`) using the `verify` skill: use the app logged out, sign in from Settings, reload the page, confirm still signed in.
- [ ] Commit with message starting `US-007:`.

---

### Phase 2 — Sync (recommended backend: Supabase + PowerSync)

> **Backend decision (confirmed 2026-05-30): Supabase + PowerSync.** Supabase provides Postgres, Auth (email/password + Google), and Row-Level Security; PowerSync provides the offline-first sync engine and connects to Drift via `drift_sqlite_async`. Default to **PowerSync Cloud** (managed, free dev tier) to start; the open-source self-hosted PowerSync Service remains an option later. (PocketBase was evaluated as the cheapest-at-scale alternative and set aside — see §7.1.)

#### US-008: Provision Supabase Postgres schema + Row-Level Security
**Description:** As a developer, I need the cloud database to mirror the app's tables and to be locked down per-user so one account can never read another's data.

**Acceptance Criteria:**
- [ ] Postgres tables for `entries`, `tags`, `entry_tags`, `categories` mirroring the Drift schema, including `user_id`, `created_at`, `updated_at`, `deleted_at`.
- [ ] **RLS enabled on every table** with policy `auth.uid() = user_id` for select/insert/update/delete.
- [ ] A test (or documented manual check) proving User B cannot read User A's rows.
- [ ] Schema captured as a committed SQL migration file under `supabase/` (not applied by the app at runtime).
- [ ] `settings` is **not** mirrored (device-local).
- [ ] Commit with message starting `US-008:`.

#### US-009: Stand up PowerSync and define sync rules
**Description:** As a developer, I need the PowerSync service connected to Supabase Postgres with sync rules that scope each client's data to its user.

**Acceptance Criteria:**
- [ ] PowerSync instance connected to the Supabase Postgres source.
- [ ] Sync rules publish only the current user's non-internal tables (a per-user bucket keyed by `user_id`).
- [ ] PowerSync auth is wired to Supabase JWTs so the client authenticates as the signed-in user.
- [ ] Setup steps documented in `docs/sync-setup.md` (or PR body) so the instance is reproducible.
- [ ] Commit with message starting `US-009:`.

#### US-010: Integrate PowerSync with Drift, activated only when signed in
**Description:** As a developer, I want the local SQLite DB driven by PowerSync when signed in, while keeping the existing Drift DAOs and watch-streams, so features don't get rewritten.

**Acceptance Criteria:**
- [ ] Add `powersync` + `drift_sqlite_async` (and `connectivity_plus`); connect Drift via `SqliteAsyncDriftConnection` so existing DAOs and `watch*` streams keep working.
- [ ] Sync only runs while authenticated; logged-out continues on the existing local connection unchanged.
- [ ] Reactive UI still updates from Drift watch streams when PowerSync writes pulled rows (change notifications propagate to Drift).
- [ ] No feature/cubit code changes required beyond the connection wiring (repositories stay on the abstract interface).
- [ ] `flutter test` + `flutter analyze` pass.
- [ ] Verify in browser (`flutter run -d chrome`) using the `verify` skill: sign in, confirm the entry list still renders and updates live.
- [ ] Commit with message starting `US-010:`.

#### US-011: Non-destructive first-login merge
**Description:** As a user signing in for the first time on a device that already has local entries, I want my local entries pushed to the cloud **and** the cloud's entries pulled down, with nothing lost on either side.

**Acceptance Criteria:**
- [ ] On first successful sign-in, every local row with `userId IS NULL` is claimed: `userId` set to the signed-in user and the row uploaded.
- [ ] All of the user's existing cloud rows are pulled into the local DB.
- [ ] The result is the **union** of local + cloud; **no deletes** happen during the merge (a row absent on one side is treated as "not yet seen", never as "delete").
- [ ] If the same logical entry exists on both sides (same `id`), last-write-wins by `updatedAt` for field values — but the row is never removed.
- [ ] Idempotent: signing out and back in does not duplicate rows.
- [ ] Tests cover: local-only rows upload; cloud-only rows download; overlapping ids resolve by `updatedAt`; re-login is idempotent.
- [ ] `flutter test` + `flutter analyze` pass.
- [ ] Verify across two clients using the `verify` skill: create entry A on Web (logged out), create entry B in the cloud via another signed-in client, then sign in on Web → confirm BOTH A and B are present.
- [ ] Commit with message starting `US-011:`.

#### US-012: Ongoing two-way sync with soft-delete propagation
**Description:** As a signed-in user with multiple devices, I want creates, edits, and deletes on one device to appear on my others.

**Acceptance Criteria:**
- [ ] Creating/editing an entry on Device A appears on Device B (within realtime latency when online; on next connect when offline).
- [ ] Deleting (soft-delete) on Device A removes it from Device B.
- [ ] Conflicting edits resolve last-write-wins by `updatedAt`.
- [ ] Changes made offline queue locally and upload automatically on reconnect (no lost writes if the app is killed before sync).
- [ ] Entries, tags, entry_tags, and categories all sync; `settings` does not.
- [ ] Tests cover create/edit/delete propagation and offline-queue-then-flush against a faked sync surface.
- [ ] `flutter test` + `flutter analyze` pass.
- [ ] Verify with two clients using the `verify` skill: run the create / edit / delete / offline-then-reconnect matrix from the Verification section.
- [ ] Commit with message starting `US-012:`.

---

### Phase 3 — Polish & web deploy

#### US-013: Sign-out data rule + sync status indicator
**Description:** As a user, I want to understand sync state and to sign out without losing data on the current device.

**Acceptance Criteria:**
- [ ] A status affordance shows: Offline / Syncing / Synced (and last-synced time when signed in).
- [ ] Signing out stops syncing and **keeps** the local copy of the user's entries on the device (does not wipe local data); a subsequent sign-in re-runs the non-destructive merge (US-011).
- [ ] The sign-out behavior is covered by a test asserting local rows survive sign-out.
- [ ] `flutter test` + `flutter analyze` pass.
- [ ] Verify in browser (`flutter run -d chrome`) using the `verify` skill: sign out, confirm entries still visible locally; the status indicator reflects offline/synced correctly.
- [ ] Commit with message starting `US-013:`.

#### US-014: Web + mobile auth callbacks and deploy
**Description:** As a user, I want sign-in (including Google, and the password-reset/magic links) to work on the deployed web app and on mobile deep links.

**Acceptance Criteria:**
- [ ] Supabase auth redirect URLs configured for `https://common-place-book.pages.dev` and preview URLs; OAuth/redirect round-trips complete on the deployed build.
- [ ] Mobile deep-link/app-link callback handled (add `app_links` if needed) so OAuth and reset links return into the app.
- [ ] Confirm the existing Cloudflare Pages `_headers` / COOP-COEP situation doesn't break the OAuth redirect (document any header change required).
- [ ] Deployed web app: sign in, see entries created on mobile.
- [ ] `flutter analyze` passes.
- [ ] Verify on the deployed preview URL using the `verify` skill.
- [ ] Commit with message starting `US-014:`.

## Functional Requirements

- **FR-1:** The app MUST remain fully usable with no account; logged-out is the default and no feature is gated behind sign-in.
- **FR-2:** The system MUST support account creation and sign-in via (a) email + password and (b) Google OAuth.
- **FR-3:** The system MUST persist the auth session across app restarts on Web, Android, and iOS.
- **FR-4:** On first sign-in on a device, the system MUST upload all local rows that have no `userId` and download all of the user's cloud rows, producing the **union** with no deletions (non-destructive merge).
- **FR-5:** After the initial merge, the system MUST two-way sync entries, tags, entry_tags, and categories across all of the user's signed-in devices.
- **FR-6:** Deletions MUST be soft deletes (`deletedAt`) that propagate across devices; the system MUST NOT hard-delete a row out from under sync.
- **FR-7:** Conflicting edits to the same row MUST resolve last-write-wins by `updatedAt`.
- **FR-8:** Offline edits MUST queue locally and upload automatically on reconnect, with no lost writes if the app is killed before sync.
- **FR-9:** A user MUST NOT be able to read or write another user's data (enforced server-side by Row-Level Security).
- **FR-10:** The `settings` table MUST NOT sync (device-local).
- **FR-11:** Signing out MUST stop syncing and retain the local copy of the user's entries on the device.
- **FR-12:** Read queries and streams MUST exclude soft-deleted rows everywhere they're surfaced today.
- **FR-13:** No backend secrets or service keys may be committed to the repo; client config is supplied via `--dart-define`.

## Non-Goals (Out of Scope)

- **No CRDTs / field-level merge.** Last-write-wins per row is sufficient for a quotes app (explicit prior decision).
- **No real-time collaborative editing** of a single entry by multiple users (no sharing between accounts at all in this version).
- **No account-to-account sharing, public entries, or social features.**
- **No "Sign in with Apple"** unless required by App Store review when shipping iOS with Google sign-in (then it's added in a follow-up, not this PRD).
- **No magic-link** auth (the chosen methods are email/password + Google).
- **No migration of legacy/anonymous data into named accounts beyond the first-login merge** — there are no pre-existing multi-user datasets (greenfield).
- **No mobile store builds / signing pipeline** (separate workstream).
- **No syncing of `settings` or device-local view/usage counters as shared data** (`viewCount`/`lastViewedAt` sync as ordinary columns but are not specially reconciled).

## Design Considerations

- **Reuse, don't rewrite.** UI and cubits depend on the abstract `EntryRepository`/`TagRepository`; sync is additive beneath them. Keep `EntriesListCubit`/`TagsCubit` untouched.
- **Extend existing mappers** (`EntryMapper.fromDatabase` at `lib/features/entries/data/mappers/entry_mapper.dart`) with `toRemoteJson`/`fromRemoteJson` rather than introducing a parallel mapper.
- **Login screen** is a new screen reachable from Settings; logged-out users never see a wall. Match existing screen styling and GoRouter named-route conventions in `lib/app/router.dart`.
- **Sync status** should be unobtrusive (e.g. an icon in the app bar or a Settings row), not a blocking modal.
- **Errors** use the existing `Result<T>` type and `AppLogger`.

## Technical Considerations

### 7.1 Backend Selection (research summary)

The owner asked for the cheapest and easiest sync backend, weighing **cost-per-user** and **development effort**. Key fact framing the whole analysis: **this app's per-user data is tiny** (text quotes/tags/categories, low write frequency — likely well under a few MB per user), so *every* candidate's free tier covers a personal-scale userbase at **$0**. The real differentiator is **how much sync engine you must build yourself** and **cost behavior as it grows**.

| Backend | Free tier (2026) | Cost as it grows | Flutter SDK | Auth incl.? | Offline-sync effort | Self-host? |
|---|---|---|---|---|---|---|
| **Supabase + PowerSync** ⭐ | Supabase: 500MB DB, **50k MAU**, 2 projects (pauses after 1 wk idle); PowerSync free dev tier | Supabase Pro **$25/mo flat** (100k MAU); PowerSync ~**$51/mo @ 5k DAU**, ~$399/mo @ 100k DAU | Official `powersync` + **official Drift integration** (`drift_sqlite_async`) | Yes (Supabase: email/pw + Google native) | **Low** — PowerSync owns the upload queue, conflict, realtime; you keep Drift | Both self-hostable |
| **PocketBase** (self-host) | Free software (MIT); pay only for a VPS | **~$5/mo flat** VPS, ~unlimited low-write users on one box | Official Dart SDK | Yes (email/pw + Google/Apple OAuth) | **Medium** — hand-roll outbox + pull; a Drift↔PocketBase UTC-timestamp LWW reference exists | Yes (you run it) |
| **Supabase alone** (the original Plan B) | Same as above | Same Supabase prices, no PowerSync fee | Official `supabase_flutter` | Yes | **High** — you hand-build the entire SyncEngine (outbox, pull-since, realtime, retry) | Yes |
| **Firebase / Firestore** | 1GB, 50k reads/day | Per-operation; realtime listeners + offline reconnects can spike reads unpredictably | Official FlutterFire | Yes | Medium (offline built-in) but **non-SQL**; cost is unpredictable | No |
| **InstantDB** | Free forever, **no pausing, no MAU cap, commercial OK** | Usage-based above free | `instantdb_flutter` (community port) | Yes | Low (offline-first built in) but **non-SQL data model → abandon Drift**; SDK maturity risk | Yes (OSS) |
| **Turso (libSQL)** | 5GB, 500M row-reads/mo | $0.75/GB etc., very cheap | SQLite-compatible | **No auth** | **High** — DB only; build auth + sync yourself | Yes |
| **Cloudflare D1 + Workers** | 5GB, 5M reads/day (synergy w/ existing CF Pages) | Workers Paid $5/mo min | **No official Flutter SDK** | **No app-user auth** (Access ≠ end-user accounts) | **High** — build the API, auth, and sync by hand | Edge-only |

**Cost-per-user verdict:** at personal scale (≤ a few thousand users) all options are effectively **$0**. As it grows, **PocketBase is cheapest** (flat ~$5/mo box, cost-per-user → ~$0). Supabase+PowerSync is the next cheapest in *effort-adjusted* terms and stays $0 well into the thousands of users (Supabase auth free to 50k MAU; PowerSync's fee only kicks in at real DAU).

**Development-effort verdict:** **Supabase + PowerSync is the easiest** path to working, non-destructive two-way offline sync, because PowerSync replaces the hand-rolled SyncEngine (the riskiest, most data-loss-prone code in the original Plan B — Phases 2–4) with a maintained engine, and its **official Drift integration means the existing DAOs, mappers, and `watch*` streams are preserved**.

**Recommendation (⭐): Supabase + PowerSync.** It keeps the already-chosen Supabase auth (email/password + Google are both native — exactly the methods selected), is the **least code to a correct sync** (directly serving the "never lose an entry" goal by offloading conflict/queue handling to a battle-tested engine), and costs **$0 until real traction**.

**Cheapest-at-scale alternative: PocketBase** — choose this only if minimizing per-user cost outranks operational simplicity and you're willing to run/patch/back-up a server and hand-write the sync client (a Drift reference exists). Because the repository layer is abstracted and the schema work (Phase 0) and auth UX (Phase 1) are backend-agnostic, switching to PocketBase later only rewrites Phase 2.

**Rejected:** Firebase (unpredictable per-op cost, non-SQL, previously declined), Turso & Cloudflare D1 (database-only — most code to build, no auth/sync/Flutter SDK), InstantDB (great free tier but non-SQL model forces abandoning the existing Drift/SQLite investment, and the Flutter SDK is a community port).

### 7.2 Codebase fit

The app is **already architected for sync** (confirmed in `lib/`): UUID primary keys, `createdAt`/`updatedAt` on every row, abstract repository interfaces the cubits depend on, and Drift `watch*` streams feeding reactive UI. Sync slots in beneath the repositories with no feature rewrites.

### 7.3 Files likely to change / be created

- **Change:** `lib/core/database/database.dart` (schema v3, soft-delete columns), `lib/features/entries/data/repositories/local_entry_repository.dart` and `lib/features/tags/data/repositories/local_tag_repository.dart` (soft delete, read filters), `lib/main.dart` (Supabase init, connection wiring), `lib/app/app.dart` (auth-aware providers), `lib/app/router.dart` (`/login`), `entry_mapper.dart` (remote JSON).
- **New:** `lib/core/auth/auth_service.dart`, `lib/core/sync/` (PowerSync connection + sync activation), `lib/features/auth/presentation/screens/login_screen.dart`, `supabase/` migration SQL, `docs/sync-setup.md`.

### 7.4 Dependencies to add

`supabase_flutter`, `powersync`, `drift_sqlite_async`, `connectivity_plus`, and `app_links` (mobile auth callbacks). `pubspec.lock` is committed — commit the updated lock.

### 7.5 Constraints / gotchas

- **Web headers:** OAuth redirect and the existing WASM/IndexedDB drift setup must coexist with Cloudflare Pages `_headers`; verify COOP/COEP changes (currently commented out) don't break the auth round-trip.
- **Supabase free-tier idle pause:** free projects pause after ~1 week of inactivity — fine once there's any active user; note it for the dev/test instance.
- **Don't commit secrets:** Supabase URL/anon key and PowerSync endpoint via `--dart-define`.

## Success Metrics

- Signing in on a device with N local entries and a cloud account with M entries results in exactly the de-duplicated union (no entry lost on either side) — verified by the two-client test in US-011.
- An entry created on one signed-in device appears on a second signed-in device within ~1s online, or on next reconnect offline.
- Logged-out usage is byte-for-byte the same experience as today (no regressions in local-only flows).
- Backend cost stays **$0** through at least the first 1,000 users.
- No reported data-loss incidents attributable to sync.

## Resolved Decisions & Follow-ups

All initial open questions are resolved (confirmed 2026-05-30):

1. **Backend** — ✅ **Supabase + PowerSync**, starting on **PowerSync Cloud** (free dev tier; self-host remains an option later).
2. **`viewCount` / `lastViewedAt`** — ✅ **Sync globally**: treated as ordinary LWW columns, shared across devices. No special-casing in sync rules.
3. **Shared-device first-login merge** — ✅ **Auto-claim**: local logged-out rows (`userId IS NULL`) are absorbed into the account that signs in (US-011), with no merge prompt. Acceptable for a personal single-user device.
4. **Password reset** — ✅ Supabase **email-link** reset for v1.
5. **Dev/test backend** — ✅ Provision a real **Supabase + PowerSync Cloud dev project early**; Phase 2 stories are verified against it in addition to unit tests that use a faked sync surface.

**Deferred to a pre-iOS-release follow-up** (App Store release-blockers; not needed for Web/Android to function — schedule when the iOS release is planned):

- **Sign in with Apple** alongside Google — App Store requires it when other social logins are offered on iOS.
- **Account deletion + data export** ("delete my account + erase cloud data") — App Store requires an in-app account-deletion path for apps that create accounts.

## Phase 0 — Build Status & Carried-Forward Items

**Phase 0 is built and committed** on branch `feat/user-accounts-sync` (2026-05-31): US-001 (schema v3 + sync columns + `EntryTags` synthetic `id` PK + migration), US-002 (soft deletes + read filtering), US-003 (tombstone purge). `flutter analyze` clean; full suite green.

An adversarial review ran post-build; defects fixed in follow-up commit `5a83fc7`:
- **Categories brought into the soft-delete model** — `CategoriesDao.deleteCategory` now soft-deletes and all category reads filter `deletedAt` (US-002 had skipped categories; they DO sync per FR-5). Tests added.
- **Tag entry-counts fixed** — `_getEntryCountForTag` now excludes links to soft-deleted entries; dead/broken `getAllTagsWithCounts` removed.
- Added partial-tag-removal, category soft-delete, count-regression, and v1→v3 migration tests.

**Carried forward to Phase 2 (sync)** — not bugs today, but prerequisites for last-write-wins:
1. **`updatedAt` on `Tags` and `Categories`.** LWW (FR-7) resolves by `updatedAt`, but only `Entries` has it. Add `updatedAt` to `Tags` and `Categories` (set on create/update/delete), with matching `updated_at` columns on the Supabase tables — a small `ALTER TABLE` on the already-provisioned instance, and `docs/sync-setup.md` §2 should gain those columns for fresh provisioning. (`entry_tags` is insert/tombstone-only, so `deletedAt` suffices.)
2. **Deterministic `entry_tags.id`.** The synthetic id is a random UUID; two devices creating the same `(entryId, tagId)` link get different ids but collide on the `UNIQUE(entryId, tagId)` index at merge. Derive the id deterministically from the pair (e.g. a v5 UUID of `entryId+tagId`) when sync lands.
3. **Migration test hardening.** v1→v3 coverage was added; consider also exercising the background-isolate (`createInBackground`) and WASM executors, since the FK-off `entry_tags` rebuild relies on drift not wrapping `onUpgrade` in a transaction.

## Phase 1 — Build Status & Carried-Forward Items

**Phase 1 (auth shell) is built and committed** on branch `feat/user-accounts-auth` (stacked on Phase 0). US-004 (Supabase init + injectable `AuthService`, `supabase_flutter` 2.12.4), US-005 (email/password login screen + `/login` route), US-007 (optional-login UX in Settings + non-destructive sign-out). Google (US-006) deferred. `flutter analyze` clean; full suite green. Email/password only; no auth gate; **no server-only secret referenced in client code** (grep-verified by review).

Adversarial review fixes (follow-up commit):
- **Sign-up email-confirmation flow** — when Supabase email confirmation is on, `signUp` returns a user but no session; the screen now stays with a "check your email to confirm, then sign in" state instead of bouncing back to a signed-out-looking Settings.
- **Settings reactivity** — `_AccountTile` now renders from the stream snapshot (with `currentUser` as the initial seed); added the missing sign-IN flip, end-to-end round-trip, and LocalOnly failure-mapping tests.

**Open verification item (cannot be automated in a headless env):**
- **Live auth + session persistence** must be checked in a real browser against the Supabase project: app logged-out → sign in from Settings → reload → still signed in; and sign up → confirm email → sign in. Run locally with `flutter run -d chrome --dart-define-from-file=.env`.
- **CI/preview caveat:** the Cloudflare Pages preview build will **not** exercise auth unless CI passes `SUPABASE_URL` + `SUPABASE_ANON_KEY` as `--dart-define` build args (add them as build env from GitHub secrets). Without them the web build falls back to local-only (auth unavailable) — by design.
