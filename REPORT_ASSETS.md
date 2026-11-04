# Report assets

Material for the technical report (`TokiniainaDisaine_Assignment2.pdf`),
organised by its section numbers. The first table lists **where the code
differs from what the report currently says**; update those passages before
submitting. Everything else is extra evidence to quote or screenshot.

Numbers below were measured on 2026-11-04: 150 Flutter tests, 35 Security
Rules tests, 2 end-to-end flows, 77.9 % line coverage of `lib/`.

## A. Changes to make in the report

| Report section | Report says | The code does | Suggested wording |
|---|---|---|---|
| 3 (Figure 1), 6 | `currentUserProvider`, `filterProvider` | Named `currentUserProfileProvider`; filters are three providers: `searchQueryProvider`, `categoryFilterProvider`, `statusFilterProvider` | Rename in Figure 1 and the provider table. |
| 3, 6 | Provider list | Extra providers: `sessionProvider` (one state for auth + profile), `authControllerProvider`, `userRepositoryProvider`, `incidentByIdProvider`, `statusHistoryProvider`, `reporterProfileProvider`, `myIncidentsProvider`, `allIncidentsStreamProvider`, `dashboardStatsProvider`, `themeModeProvider` | "The inventory grew during implementation; Table X lists the final set." |
| 3.2 | Project structure | Also `app/routes.dart`, `app/app_shell.dart`, `app/router_redirect.dart`, `core/errors.dart`, `data/models/report_draft.dart`, `data/services/photo_services.dart`, `features/incidents/edit_incident_screen.dart`, `widgets/lifecycle_rail.dart`, `widgets/status_timeline.dart`, `integration_test/`, `firebase/test/` | Copy the tree from README "Project structure". |
| 3.1 | "image_picker + image compression" | `image_picker` + `flutter_image_compress` (1600 px / q80, then 1280 px / q65 if still over 5 MB; EXIF removed) | Name the package and mention EXIF/GPS stripping. |
| 4.1 | `incidents/{id}` fields | Extra field `reporterName` (string, `null` when anonymous), copied at submission | "So the feed can show names without reading other users' profiles; anonymous reports never store it." |
| 4.1, 7 | `users/{uid}` readability (if the report implies everyone can read it) | Readable only by the owner and staff | "Anonymity is enforced by data, not only hidden in the UI." |
| 5 | `authStateChanges()` | `userChanges()` | "`userChanges()`, a superset of `authStateChanges()` that also fires after `reload()`, which is how the app notices verification." |
| 5 | Profile creation | `users/{uid}` is created on the **first verified login** (always `role: student`), after forcing an ID-token refresh | Rules require a verified email to write it, so it cannot be created at registration. |
| 5 | (not mentioned) | "Forgot password?" reset email on the login screen | Add to F1 or as an extra. |
| 8 | Filtering | One category and one status at a time (combinable: category AND status); free-text search on the device over the newest 200 | State it, and list it under Limitations. |
| 8 | Status history | The timeline starts with a "Submitted" entry drawn from `createdAt`; `statusHistory` documents exist only for staff changes, oldest first | |
| 8 | Staff actions | Staff can delete any report (moderation) but never edit its content; rejecting requires a reason | |
| 9 | (not mentioned) | Light / dark / system theme switch on Profile | |
| 10 | Testing tools | Also `firebase_auth_mocks`, `integration_test`, and `@firebase/rules-unit-testing` + mocha against the emulators. Mocks are written with **mocktail** (no code generation), not mockito | |

## B. Section-by-section evidence

### 3 System architecture

- Layer rule: widgets read providers; providers call repositories;
  repositories are the only Firebase callers (`lib/data/repositories/`),
  each behind an abstract interface so tests swap in fakes.
- Router: `GoRouter` with `refreshListenable` driven by `sessionProvider`
  and a pure `redirectFor(session, location)` (`lib/app/router_redirect.dart`,
  8 unit tests). `StatefulShellRoute.indexedStack` keeps each tab's state.

### 4 Firebase data structure

- Indexes (`firestore.indexes.json`): category+status+createdAt,
  category+createdAt, status+createdAt, reporterId+createdAt.
- Storage path: `incident_photos/{incidentId}/{file}.jpg`, with
  `ownerUid` custom metadata checked by `storage.rules`.

### 5 Authentication and session handling

- Allowed domains: `alustudent.com`, `alueducation.com`
  (`lib/core/constants.dart`), checked in the app and in the rules
  (`verified()` = `email_verified` + domain regex).
- Verify Email screen: polls every 5 s, checks again when the app resumes,
  60 s cooldown on "Resend".
- `SessionState` is a sealed class: `SessionLoading`, `SessionSignedOut`,
  `SessionUnverified`, `SessionReady(profile)`, `SessionError`.

### 6 State management with Riverpod

- Riverpod 3: `Notifier` / `AsyncNotifier`, `ref.mounted` checks after
  awaits, `AsyncLoading(progress:)` for upload progress,
  `ProviderScope(retry: noAutomaticRetry)` so errors show immediately with a
  retry button instead of silent automatic retries.
- `ReportController`: uploads take 90 % of the progress bar; on failure,
  photos already uploaded are deleted; a write not confirmed within 15 s is
  reported as "queued offline" (Firestore keeps it and syncs later).
- `StatusController`: checks staff role and `IncidentStatus.canMoveTo`
  before writing; auto-disposed with the sheet.

### 7 User roles and access control

- Rules highlights (`firestore.rules`): reporters may edit only while
  `submitted` and only the content fields; staff may change only
  `status`/`updatedAt` and only along the lifecycle; a history entry must
  match the before/after status (`get` / `getAfter`) and is immutable.
- 35 rules tests (`firebase/test/rules.test.js`), including: unverified and
  non-ALU users denied; students cannot set `role: staff`; students cannot
  change status; invalid transitions denied; history cannot be forged.
- Defence in depth: the Dashboard tab is hidden and `/staff` is redirected
  for students, but the rules are the real check.

### 8 Core workflows

Screenshots to take (light mode, then one or two in dark):

1. Register with a Gmail address (error message).
2. Verify Email screen.
3. Feed with filters and a search active.
4. Report form with validation errors.
5. Report form uploading (progress bar).
6. Detail screen: rail, photos, timeline with a staff note.
7. Status update sheet (allowed options only).
8. Staff dashboard with counts and the queue.
9. Anonymous report: student view and staff view side by side.
10. Profile in dark mode.

### 9 UI/UX design decisions

- Design direction "work order slip": seed colour `#0E5E6F`, Atkinson
  Hyperlegible font (designed for low-vision readers), the four-step
  **lifecycle rail** as the signature element; a rejected report shows the
  rail broken (dashed) after "Under review". Details in `DESIGN_NOTES.md`.
- Status is never colour alone: chip = colour + icon + text, and the rail
  has a spoken label ("Progress: Step 3 of 4, In progress").
- Contrast measured by `test/app/theme_contrast_test.dart`: every status
  chip meets WCAG AA 4.5:1 in light and dark; icons and rail meet 3:1.
- Every screen has loading (skeletons or spinner), empty (with a next
  action) and error (with retry) states.

### 10 Testing strategy

| Level | Tool | Count | What it covers |
|---|---|---|---|
| Unit | flutter_test | 35 | models (13), validators and search (14), router redirect and theme contrast (8) |
| Repository | fake_cloud_firestore, firebase_auth_mocks | 17 | queries, filters, batch writes, error mapping |
| Provider | ProviderContainer.test + mocktail | 31 | session, feed filtering, report and status controllers, offline queue, photo cleanup |
| Widget | WidgetTester | 45 | every screen's states, permissions per role, form validation, dark mode at 320 px with 1.3x text |
| End-to-end | integration_test | 2 flows | student files a report and finds it; staff update status and history appears |
| Security Rules | @firebase/rules-unit-testing + emulators | 35 | allow and deny cases per role |
| Manual | `TEST_MATRIX.md` | 10 scenarios | real backend and device |

Counts are test declarations (128); some run once per status or theme, so
`flutter test` reports 150.

Coverage: 77.9 % of `lib/` lines (`flutter test --coverage`). Lowest:
`storage_repository.dart` and `photo_services.dart` (thin wrappers over
plugins that need a device) and `verify_email_screen.dart`.

Bugs the tests caught (good material for section 11):

- The end-to-end test found that the report form, a lazy `ListView`,
  disposed the category picker when scrolled off a small screen, so Submit
  crashed. Fixed by keeping all fields mounted; a regression widget test now
  submits on a 360 x 640 screen.
- The dark-mode test at 320 px with large text found status chips
  overflowing; labels now shrink with an ellipsis.
- Riverpod 3's automatic retry kept failed streams in "loading", so error
  screens never appeared; disabled with `noAutomaticRetry`.

### 11 Challenges encountered

- Windows + a space in the user folder broke Gradle and the Firestore
  emulator ("Unable to establish loopback connection"): fixed with
  `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\Temp`.
- Kotlin incremental compilation failed because the pub cache (C:) and the
  project (D:) are on different drives: `kotlin.incremental=false`.
- Storage needs the Blaze plan on new projects.
- Version conflicts: `google_fonts` 9 required a newer Flutter API, pinned
  to 8; `firebase_storage_mocks` was incompatible, so Storage is mocked
  behind the repository interface instead.
- Profile creation had to wait for verification because the rules require
  a verified email; the ID token is refreshed first so the rules see
  `email_verified: true`.

### 12 Limitations and future work

- Search is client-side over the newest 200 reports; future: a search
  service (Algolia / Typesense extension) or keyword arrays.
- Dashboard counts use the same 200-document window; future: Firestore
  `count()` aggregation queries.
- Staff promotion is manual; future: an admin screen backed by a Cloud
  Function and custom claims.
- The opaque `reporterId` on anonymous reports lets two of them be linked;
  future: store reporter identity in a staff-only sub-document.
- Rules check that a history entry matches a real status change, but cannot
  force every status change to have one without a Cloud Function.
- Photos are uploaded before the report exists, so for a new id the rules
  can only check the uploader tag; unreferenced files are never shown.
- No push notifications; future: Cloud Messaging when a status changes.
- Theme choice is not persisted.

### 14 Product thinking: privacy and misuse

- Location data (EXIF/GPS) removed from every photo before upload.
- Anonymous reports: the name is never written; students cannot read other
  users' profiles; staff can still follow up.
- Misuse: only verified ALU accounts can post; staff can delete spam and
  must give a reason when rejecting, which the reporter sees.
- Wrong-password and unknown-user errors share one message, so the app does
  not reveal which emails have accounts.

## C. Deliverable placeholders on the report's cover

- GitHub repository URL.
- Demonstration video URL (script in `DEMO_SCRIPT.md`).
- Staff demo account email (create it with README step 5; give the password
  to the grader separately, never in the repository).
