# Progress

Running log so work can resume in a new session. Claude never commits; the
student commits at each checkpoint.

## Decisions confirmed with the student (2026-11-04)

- Allowed email domains: `alustudent.com` and `alueducation.com`. The domain
  only gates access; the role always comes from `users/{uid}.role`.
- Firebase project: `mobile-dev-formative-2-1349f`, currently on the **Spark**
  plan (see Open issues: Storage).
- `lib/firebase_options.dart` and `android/app/google-services.json` (Firebase
  client config, not secrets) **will be committed** so graders can build.
- Target platform: Android (emulator or device). Web is not a target.

## Status by step (section 8 of the build prompt)

| Step | Description | Status |
|---|---|---|
| 0 | Architecture review + `DESIGN_NOTES.md` | Done, committed |
| 1 | Scaffold, dependencies, theme, router skeleton, Firebase init | Done, committed |
| 2 | Models, validators, constants + unit tests | Done, committed |
| 3 | Auth repository, providers, auth screens, router guards | Done, committed |
| 4 | Rules, users collection, `isStaffProvider` | Done, committed |
| 5 | Incident repository, streams, feed, reusable widgets | Done, committed |
| 6 | Report form, photo upload, cleanup on failure | Done, awaiting commit |
| 7 | Detail, edit/delete, status timeline | Not started |
| 8 | Staff status update (batch), dashboard | Not started |
| 9 | Profile, polish, states, dark mode | Not started |
| 10 | Tests, rules tests, docs, README, demo script, report assets | Not started |

Last checkpoint confirmed committed: step 5.

## Step 6 details

- `StorageRepository` / `FirebaseStorageRepository`: upload JPEG bytes to
  `incident_photos/{incidentId}/{timestamp}.jpg` with `ownerUid` metadata and
  progress; delete by URL (missing = fine). Missing bucket (Spark plan) ->
  "Photo uploads are not available right now. Remove the photos...".
  Storage retry time cut to 30 s so offline uploads fail promptly.
- `lib/data/services/photo_services.dart`: `PhotoSource` (image_picker,
  camera or gallery) and `ImageCompressor` (flutter_image_compress, JPEG,
  1600 px / q80, falls back to 1280 px / q65 if > 5 MB, `keepExif: false` so
  GPS/device EXIF is removed).
- `ReportDraft` + `DraftPhoto` (sealed: `RemotePhoto` / `LocalPhoto`).
- `reportControllerProvider` (AsyncNotifier): `submit`, `saveEdit`,
  `delete`. Progress via `AsyncLoading(progress:)` (uploads 0-90 %, write
  90-100 %). Upload first, write second; on any failure delete the photos
  uploaded so far. Edit deletes removed photos only after the save succeeds.
  Delete removes the document, then photos (best effort).
- **Offline handling (matrix #10):** if the Firestore write is not confirmed
  within 15 s, the report is treated as queued offline (Firestore keeps the
  write and sends it on reconnect; fixed document id, so no duplicate), the
  user is told so, and photos are NOT deleted.
- Report form: category chips, title, description, building dropdown,
  optional detail, up to 3 photos (thumbnails + remove), anonymous switch,
  validation on submit and on blur, inputs locked + progress while saving,
  snackbar + open the new report on success. Form state lives in
  `FormField`s, so the screen uses no `setState`.
- `PhotoPicker` has no widget preview: it uses `dart:io` (`Image.file`),
  which the web-based previewer cannot run.
- 85 tests passing.

### Needs the student

- Photo upload against the real backend needs a Storage bucket, which on a
  new project needs the **Blaze** plan. Without it, reports without photos
  work, and reports with photos fail with the message above.

## Step 5 details

- `IncidentRepository` / `FirestoreIncidentRepository`: `watchIncidents`
  (server-side category/status `where` + `orderBy createdAt desc`, limit 200),
  `watchIncident`, `watchHistory`, `newIncidentId`, `createIncident`,
  `updateIncident` (reporter-editable fields only), `deleteIncident` (incident
  + history in one batch), `updateStatus` (status + history entry in one
  batch). Firebase errors -> `UserFacingException` via `firestore_errors.dart`.
- Providers: `incidentRepositoryProvider`, `incidentsStreamProvider` (tied to
  the signed-in uid so it resets on logout), `filteredIncidentsProvider`,
  `searchQueryProvider`, `categoryFilterProvider`, `statusFilterProvider`
  (Riverpod 3 `Notifier`s, not legacy `StateProvider`),
  `hasActiveFiltersProvider`.
- Automatic Riverpod retry disabled app-wide (`retry_policy.dart`): it hid
  errors behind spinners; screens offer "Try again" instead.
- Widgets: `IncidentCard` + `IncidentCardSkeleton`, `StatusChip`,
  `LifecycleRail` (signature element), `CategoryIcon`, `CategoryPicker`,
  `EmptyState`, `ErrorView`; status/category icons and colours in
  `incident_visuals.dart` (exhaustive switches).
- Feed: search bar, scrollable category and status chips (single choice
  each, tap again to clear, combinable), result count, pull-to-refresh,
  skeletons, empty states (no reports / no matches + "Clear filters"), error
  view with retry, thin progress bar on filter changes, max width 640.
- Widget previews in `lib/widgets/previews.dart` (light + dark), run with
  `flutter widget-preview start`. Not opened in this session.
- Detail route `/incidents/:id` is a placeholder until step 7.
- 74 tests passing.

### Report notes from step 5

- Filters are single-choice per dimension (one category, one status), which
  matches the indexed equality queries. "Combinable" = category AND status.
- Feed is capped at the 200 newest matching reports; free-text search runs
  over that window (already listed under Limitations: client-side search).

## Step 4 details

- `firestore.rules`: every rule requires a verified ALU email (`verified()`);
  role from `users/{uid}.role` (`isStaff()` via `get()`).
  - users: read own (or staff); create own with role `student` only; update
    own `displayName` only; no delete.
  - incidents: read for verified users; create validated (lengths, enums,
    <= 3 photos, `status == 'submitted'`, own `reporterId`, server
    timestamps, anonymous => no `reporterName`); reporter edit/delete only
    while `submitted` and never `status`/`reporterId`/`createdAt`; staff may
    change only `status` + `updatedAt`, only along the lifecycle; staff delete.
  - statusHistory: read for verified users; create by staff with
    `changedBy == uid`, and `from`/`to` must match the incident status before
    (`get`) and after (`getAfter`) the batch; never updated; deletable by staff
    only once the parent incident is gone (cleanup).
- `storage.rules`: verified users, images only, < 5 MB, `ownerUid` custom
  metadata must equal the uploader; uploading into an existing incident only
  for its reporter (while `submitted`) or staff (`firestore.get`); delete by
  uploader (while editable / after deletion) or staff; no overwrite.
- `firestore.indexes.json`: category+status+createdAt, category+createdAt,
  status+createdAt (all createdAt desc).
- `firebase.json`: firestore/storage/emulator sections added (kept the
  FlutterFire section).
- Rules tests: `firebase/test/rules.test.js` (mocha +
  `@firebase/rules-unit-testing`). Run from the project root:
  `firebase emulators:exec --only firestore,storage "npm --prefix firebase test"`.
- `isStaffProvider` + Dashboard tab shown only for staff.

### Limitations to mention in the report

- **Anonymous reports:** the name is never stored on the incident and
  students cannot read other users' profiles, but the opaque `reporterId` is
  still readable, so two anonymous reports by the same person can be linked.
- **Storage ownership at upload time:** photos are uploaded before the
  incident document exists, so for a *new* incident id the rules can only
  check that the file is tagged with the uploader's uid, not that the uploader
  will own the incident. Mitigation: no overwrites, files only deletable by
  their uploader or staff, and unreferenced files never appear in the app.
- **Status change without history:** rules guarantee a history entry always
  matches a real status change, but they do not force every status change to
  carry one (that would need an extra field or a Cloud Function). The app
  always writes both in one batch.
- Field lengths in rules count raw characters; the app trims before saving.
- Staff promotion is manual (Console / Admin SDK).

## Step 3 details

- `AuthRepository` / `FirebaseAuthRepository`: register (domain check, display
  name, verification email), sign in, sign out, resend, password reset,
  reload + token refresh. `FirebaseAuthException` codes -> messages in
  `authErrorMessage()`; wrong password and unknown user share one message.
- `UserRepository.watchOrCreateProfile`: creates `users/{uid}` (role
  `student`) on the **first verified login**, matching the report's Figure 3
  (rules require a verified email, so the doc cannot be created at
  registration time).
- Providers (`lib/providers/`): `firebaseAuthProvider`, `firestoreProvider`,
  `storageProvider`, `authRepositoryProvider`, `userRepositoryProvider`,
  `authStateProvider`, `currentUserProfileProvider`, `sessionProvider` (sealed
  `SessionState`: loading / signed out / unverified / ready / error),
  `authControllerProvider` (AsyncNotifier for auth actions).
- Router: `redirectFor(session, location)` is a pure, unit-tested function;
  `routerProvider` re-runs it via `refreshListenable` when the session changes.
  Splash until auth + profile resolve.
- Screens: Login (password toggle, forgot password), Register, Verify Email
  (5 s polling, check on app resume, 60 s resend cooldown, "use a different
  account"), Splash (with retry/log out on profile error), minimal Profile with
  logout (polished in step 9).
- Shared widgets: `LoadingButton`, `PasswordField`, `AuthLayout`.
- `lib/core/errors.dart`: `UserFacingException` + `friendlyError()`; all
  repositories throw user-facing messages.
- 49 tests passing.

### Report differences from step 3

- `authStateProvider` listens to `userChanges()`, a superset of
  `authStateChanges()` that also fires after `reload()`/token refresh, which
  is how the app notices verification. Section 5 of the report names
  `authStateChanges()`; say "userChanges() (a superset of authStateChanges)".
- Extra providers not in the report's inventory: `sessionProvider`,
  `authControllerProvider`, `userRepositoryProvider`.
- Extra feature: "Forgot password?" reset email on the login screen.

## Step 2 details

- `lib/core/constants.dart`: `allowedEmailDomains`, `campusBuildings`
  (placeholder ALU Kigali names, edit freely), `Limits`, `Paths`.
- Models in `lib/data/models/`: `Incident` + `IncidentLocation`,
  `IncidentCategory`, `IncidentStatus`, `AppUser` + `UserRole`, `StatusEvent`.
  `toMap()` never includes timestamps; repositories add server timestamps.
  `fromMap()` tolerates pending server timestamps (`null`) and bad data.
- Status lifecycle lives in one place: `IncidentStatus.allowedNext` /
  `canMoveTo()` (unit tested).
- Validators in `lib/core/validators.dart`; client-side search in
  `lib/core/utils/incident_search.dart` (all words must match).
- 29 tests passing.

### Differences from the report to fix later (also goes in REPORT_ASSETS.md)

- **Added `reporterName` to `incidents/{id}`.** It is copied at submission so
  the feed can show names without reading other users' profiles, and it is
  written as `null` for anonymous reports. This lets the rules restrict
  `users/{uid}` reads to the owner and staff, so anonymity is enforced by data,
  not only hidden in the UI (the opaque `reporterId` is still readable).
- Timeline: the first "Submitted" entry is drawn from `createdAt`; history
  documents exist only for staff changes (rules only let staff create them).

## Step 1 details

- Dependencies (resolved with `flutter pub add`): flutter_riverpod 3.4,
  go_router 18.1, firebase_core 5.1, firebase_auth 7.0, cloud_firestore 7.1,
  firebase_storage 14.0, image_picker 1.2, flutter_image_compress 2.5,
  timeago 3.7, google_fonts 8.0, intl 0.20. Dev: mocktail, fake_cloud_firestore
  4.5, firebase_auth_mocks 0.16.
- `firebase_storage_mocks` has no release for firebase_storage 14, so Storage is
  faked behind the `StorageRepository` interface with mocktail instead.
- `google_fonts` pinned to 8.x: 9.0 is built on the separate `material_ui`
  package and its `TextTheme` type does not match Flutter 3.47's Material.
- Riverpod 3 notes: `StateProvider` is legacy, so filter state will use
  `Notifier`s; `AsyncValue.value` is nullable (no `valueOrNull`).
- Router: `routerProvider` with a `StatefulShellRoute` (Feed, Report,
  Dashboard, Profile branches) and placeholder screens; guards come in step 3.
- Android: `INTERNET` permission, `minSdk = max(flutter default, 23)`, app label
  "Campus Reports". No camera/storage permissions needed: image_picker uses the
  system camera intent and Android photo picker. iOS usage strings added.
- applicationId left as `com.example.mobile_dev_formative_2` because it must
  match the Android app registered in Firebase (`google-services.json`).

## Notes on skills and tools

- `flutter-apply-architecture-best-practices` loaded. It describes
  ChangeNotifier ViewModels and a `ui/` + `domain/` folder layout. This project
  keeps the report's structure instead: Riverpod `Notifier`/`AsyncNotifier`
  classes play the ViewModel role, and repositories wrap the Firebase SDKs
  directly (no separate `services/` layer, because the SDKs already are the
  service clients). No optional domain/use-case layer: the only shared business
  rule (allowed status transitions) is a pure function in `core/`.
- `frontend-design` loaded; translated to Flutter in `DESIGN_NOTES.md`.
- Dart/Flutter MCP server failed to connect this session; falling back to the
  CLI (`flutter analyze`, `flutter test`, `flutter pub`).

## Open issues and limitations (for the report's Limitations section)

- **Storage on the Spark plan:** since late 2024, new Firebase projects can
  only create a Cloud Storage bucket after upgrading to Blaze. Blaze keeps a
  no-cost quota (5 GB stored, 1 GB/day download for `*.firebasestorage.app`
  buckets); set a budget alert (for example 1 USD) to stay safe. Until then
  photo upload code is built and tested with fakes but cannot run against the
  real backend. Decision needed before step 6.
- Hiding the reporter name on anonymous reports is a **UI-level** control:
  `reporterId` stays readable to signed-in users so staff can follow up.
  (Will be flagged again when the rules are written.)
- **Java on this machine (resolved, step 4):** Gradle and the Firestore
  emulator failed with `Unable to establish loopback connection` /
  `failed to open a new selector`. Cause: on Windows the JDK's NIO selector
  creates an AF_UNIX socket in the temp folder, which fails under
  `C:\Users\PC DISAINE\...`. Fix: point it at a folder without spaces via
  `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\Temp` (user environment
  variable, not committed). Second issue: Kotlin incremental compilation fails
  because the pub cache (C:) and the project (D:) are on different drives;
  fixed with `kotlin.incremental=false` in `android/gradle.properties`.
  `flutter build apk --debug` now succeeds.
- Fonts load via `google_fonts` at runtime; first launch offline falls back
  to the system font.
