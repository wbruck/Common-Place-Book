# Play Store Release Plan — Commonplace

Plan for releasing the app on the Google Play Store, based on the current state of the
repo (as of 2026-07-31).

Two things in this repo block a Play Store release as-is; the plan is built around
fixing them first:

1. **The application ID is still `com.example.common_place_book`**
   (`android/app/build.gradle.kts`). Google Play rejects any `com.example.*` package,
   and the ID is **permanent once you upload your first build** — this must be changed
   before anything else.
2. **The release build is signed with debug keys** (`android/app/build.gradle.kts`) —
   a real upload keystore is needed.

Already in place: adaptive launcher icons, notification permissions, and the
share-target manifest.

---

## Phase 1: One-time account setup

1. Create a **Google Play Developer account** at https://play.google.com/console
   ($25 one-time fee, tied to a Google account — decide whether to use a personal or
   dedicated account).
2. Complete identity verification (required before publishing; can take a few days,
   so start early).
3. Note: **personal developer accounts created after Nov 2023 must run a closed test
   with at least 12 testers for 14 days** before they're allowed to publish to
   production. Factor this into the timeline.

## Phase 2: Fix the application ID (before first upload — it's permanent)

Pick a domain-based ID you control, e.g. `com.wbruck.commonplacebook`. Then:

1. In `android/app/build.gradle.kts`: change both `namespace` and `applicationId`.
2. Move `MainActivity.kt` from
   `android/app/src/main/kotlin/com/example/common_place_book/` to the matching new
   package path, and update its `package` declaration.
3. Check `android/app/src/main/AndroidManifest.xml` — the activity uses a relative
   name (`.MainActivity`) so it resolves against the namespace automatically, but
   verify the share-target `MainActivity` code doesn't hardcode the old package
   anywhere.
4. Rebuild and re-run the app + tests to confirm nothing references the old package.

## Phase 3: Release signing

1. Generate an upload keystore (keep it out of git, back it up somewhere safe —
   losing it is recoverable via Play App Signing, but painful):

   ```bash
   keytool -genkey -v -keystore ~/keystores/commonplace-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (add it and `*.jks` to `.gitignore`):

   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=/Users/<you>/keystores/commonplace-upload.jks
   ```

3. In `android/app/build.gradle.kts`, load `key.properties` and replace the debug
   signing config with a real `release` signing config (standard Flutter pattern:
   https://docs.flutter.dev/deployment/android#sign-the-app).
4. When creating the app in Play Console, enroll in **Play App Signing** (default) —
   Google holds the real signing key; the local keystore is just the upload key.

## Phase 4: Pre-release app hygiene

1. **Verify ProGuard/R8 doesn't break Drift or notifications**: `proguard-rules.pro`
   already exists; build a release APK and smoke-test on a device — specifically
   database reads/writes, scheduled reminder notifications, and sharing text into
   the app:

   ```bash
   flutter build apk --release
   flutter install
   ```

2. **Version**: `pubspec.yaml` is at `1.0.0+1`, fine for a first upload. Every
   subsequent upload must bump the `+N` build number (this becomes `versionCode`).
3. Confirm `flutter analyze` and `flutter test` pass.

## Phase 5: Store assets and listing content (prepare offline)

- **App icon**: 512×512 PNG (launcher icons exist; export a hi-res version).
- **Feature graphic**: 1024×500 PNG (required).
- **Screenshots**: at least 2 phone screenshots (PNG/JPEG, 16:9 or 9:16); tablet
  screenshots optional but recommended.
- **Short description** (≤80 chars) and **full description** (≤4000 chars).
- **Privacy policy URL** — required for every app. Since the app is local-only
  (Drift/SQLite, no data leaves the device), a simple "we collect nothing" policy
  hosted anywhere public works; the Cloudflare Pages site is a natural home.
  Note: if/when Supabase + PowerSync sync ships, this policy and the data-safety
  form both need updating.

## Phase 6: Create the app in Play Console

1. **Create app** → name "Commonplace", default language, App (not game), Free.
2. Work through the **dashboard checklist**:
   - **Privacy policy** — paste the URL.
   - **App access** — "all functionality available without login" (true today).
   - **Ads** — no.
   - **Content rating questionnaire** — user-generated-content questions: answer
     based on the fact that content is private/local, not shared publicly.
   - **Target audience** — 18+ or 13+ as preferred; avoid "appeals to children" to
     skip Families policy requirements.
   - **Data safety form** — declare no data collected/shared (accurate while
     everything is on-device).
   - **App category** — Productivity or Books & Reference.

## Phase 7: Build, upload, test, promote

1. Build the app bundle (Play requires `.aab`, not APK):

   ```bash
   flutter build appbundle --release
   ```

   Output: `build/app/outputs/bundle/release/app-release.aab`.
2. **Internal testing track** first: upload the AAB, add your own email as a tester,
   install via the opt-in link, and verify the ProGuard'd, Play-signed build works
   end-to-end.
3. **Closed testing**: promote the build, recruit 12+ testers (friends/family via an
   email list works), run for the required 14 days.
4. **Apply for production access** in the console once the closed-test requirement is
   met, then **promote to Production**. First review typically takes a few days;
   subsequent updates are faster.

## Phase 8: Repeatable release process (per update)

1. Bump version in `pubspec.yaml` (e.g. `1.0.1+2`).
2. `flutter test && flutter analyze`.
3. `flutter build appbundle --release`.
4. Upload to a testing track, verify, promote to production with staged rollout
   (e.g. 20% → 100%).
5. Later, automate in CI (e.g. GitHub Actions + `fastlane supply` or the Gradle Play
   Publisher plugin) with the keystore and a Play service-account JSON stored as
   secrets — worth doing once the manual flow works.

---

**Critical path**: change the application ID → set up signing → create the developer
account now. Identity verification and the 14-day closed test are the long poles;
everything else is quick.
