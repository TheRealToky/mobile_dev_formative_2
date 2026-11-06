# Campus Reports

A Flutter app for reporting and tracking campus incidents (broken facilities,
water and power outages, damaged furniture, safety hazards) at African
Leadership University.

- **Students** sign up with their ALU email, verify it, and file reports with
  a category, title, description, location and up to 3 photos, optionally
  hiding their name from other students. They can browse, search and filter
  every report, follow each one's status live, and edit or delete their own
  while it is still "Submitted".
- **Staff** see a dashboard with counts per status and the open queue (oldest
  first), and move reports through the lifecycle with a note the reporter
  sees.

```
submitted -> under review -> in progress -> resolved
                  \-> rejected (a reason is required)
```

Built with Flutter, Riverpod 3, go_router and Firebase (Authentication,
Cloud Firestore). Runs entirely on the free **Spark** plan: photos are stored
in Firestore, not Cloud Storage. Access control is enforced by Firestore
Security Rules, not only by the UI. Target platform: **Android**.

## Contents

- [Architecture](#architecture)
- [Setup checklist](#setup-checklist)
- [Running the tests](#running-the-tests)
- [Project structure](#project-structure)
- [Files that contain Firebase config](#files-that-contain-firebase-config)
- [Known limitations](#known-limitations)
- [Other documents](#other-documents)

## Architecture

Three layers; dependencies only point downwards.

| Layer | Folder | What it holds |
|---|---|---|
| Presentation | `lib/features/`, `lib/widgets/`, `lib/app/` | Screens, reusable widgets, theme, router and guards |
| Application | `lib/providers/` | Riverpod providers and notifiers (`ReportController`, `StatusController`, session, filters, dashboard) |
| Data | `lib/data/` | Models and repositories behind abstract interfaces; the only code that calls Firebase |

Key points:

- `sessionProvider` combines the auth user and the `users/{uid}` profile into
  one state (`loading / signedOut / unverified / ready / error`). The router's
  pure `redirectFor()` uses it to guard every route, including `/staff`.
- Feeds, detail and dashboard are real-time Firestore streams, so a staff
  status change appears on the reporter's phone without a refresh.
- A status change and its `statusHistory` entry are written in **one batch**,
  and the rules check both halves (`get` / `getAfter`).
- Photos are compressed to a JPEG under 700 KB (stepping down size and
  quality until it fits a Firestore document) and stripped of EXIF
  (including GPS). Each one is saved as a document in
  `incidents/{id}/photos`, and deleted again if the report fails to save.

## Setup checklist

Everything below is done once, by you, on your own machine and Firebase
project. Steps marked **(done)** were completed for
`mobile-dev-formative-2-1349f` while building the app (the config files
exist); repeat them only for a new project. Tick the others yourself.

### 1. Tools

- [ ] Flutter 3.47+ (`flutter --version`), Android Studio with an emulator
      (API 23+) or a phone with USB debugging.
- [ ] Node.js 20+ and the Firebase CLI: `npm install -g firebase-tools`, then
      `firebase login`.
- [ ] FlutterFire CLI: `dart pub global activate flutterfire_cli`.
- [ ] Java 17+ (for Gradle and the emulators).

Windows only, if your user folder contains a space (for example
`C:\Users\PC DISAINE`): Gradle and the Firestore emulator fail with
"Unable to establish loopback connection". Fix once, then open a new
terminal:

```bash
setx JAVA_TOOL_OPTIONS "-Djdk.net.unixdomain.tmpdir=C:\Temp"
```

### 2. Firebase project

- [ ] **(done)** Create a project in the
      [Firebase console](https://console.firebase.google.com/).
- [ ] **(done)** Connect the app:
      ```bash
      flutterfire configure --project mobile-dev-formative-2-1349f --platforms android
      ```
      This writes `lib/firebase_options.dart` and
      `android/app/google-services.json`.
- [ ] Authentication -> Sign-in method -> enable **Email/Password**
      (check it is on).
- [ ] Firestore Database -> Create database if it does not exist yet
      (production mode; pick a region close to Kigali, for example
      `europe-west1`. The region cannot be changed later).
- Nothing else: photos live in Firestore, so no Cloud Storage bucket,
  Blaze plan or payment card is needed. The Spark quota (1 GiB stored,
  50k reads/day) holds a few thousand compressed photos.

### 3. Deploy rules and indexes

From the project root:

```bash
firebase deploy --only firestore:rules,firestore:indexes --project mobile-dev-formative-2-1349f
```

Index builds take a
few minutes; until they finish, filtered feeds and "My reports" show an
error with a retry button.

### 4. Run the app

```bash
flutter pub get
```

```bash
flutter run
```

### 5. Create the accounts

- [ ] **Student:** register in the app with an `@alustudent.com` (or
      `@alueducation.com`) address and click the link in the verification
      email. The profile document `users/{uid}` is created with
      `role: "student"` on first verified login.
- [ ] **Staff:** register a second account the same way and verify it, then
      in the console open Firestore -> `users` -> that user's document and
      change `role` from `student` to `staff`. Log out and back in. The
      client can never set this itself; the rules reject it.

### 6. Sample data

Log in as the student and file a few reports with different categories and
buildings (the list in `DEMO_SCRIPT.md` covers every status once staff move
them). One anonymous report and one with a photo make the demo complete.

## Running the tests

Flutter unit, widget and provider tests (no Firebase needed, they use fakes):

```bash
flutter test
```

With coverage (writes `coverage/lcov.info`, git-ignored):

```bash
flutter test --coverage
```

Security Rules tests against the local emulator (37 tests). Run once:
`npm --prefix firebase install`. Then:

```bash
firebase emulators:exec --project demo-campus-reports --only firestore "npm --prefix firebase test"
```

The `WARNING ... PERMISSION_DENIED` stack traces in that output are the
expected denials the tests check for.

End-to-end integration test (needs an Android emulator or phone; uses
in-memory Firebase fakes, so it never touches the real project):

```bash
flutter test integration_test/app_flow_test.dart
```

Static analysis (strict casts, inference and raw types are enabled):

```bash
flutter analyze
```

The manual test matrix for the real backend is in
[`TEST_MATRIX.md`](TEST_MATRIX.md).

## Project structure

```
lib/
  main.dart                 Firebase.initializeApp + ProviderScope
  firebase_options.dart     generated by flutterfire configure
  app/                      app, theme, routes, router + redirectFor, app shell
  core/                     constants, validators, errors, utils (search, snack)
  data/
    models/                 Incident, AppUser, StatusEvent, ReportDraft, enums
    repositories/           auth, user, incident, photo (+ Firestore errors)
    services/               photo picking and compression
  providers/                auth/session, incidents, filters, report and
                            status controllers, dashboard, theme
  features/
    auth/                   splash, login, register, verify email
    incidents/              feed, report form, detail, edit
    staff/                  dashboard, status update sheet
    profile/                profile
  widgets/                  incident card, status chip, lifecycle rail,
                            timeline, pickers, empty/error states, previews
test/                       unit, widget and provider tests
integration_test/           end-to-end flows
firebase/test/              Security Rules tests (mocha + rules-unit-testing)
firestore.rules, firestore.indexes.json, firebase.json
```

## Files that contain Firebase config

These hold the Firebase **client** configuration (project id, API key, app
id). It identifies the project but grants no access by itself; access is
controlled by Authentication and the Security Rules. They are committed by
choice:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `firebase.json` (project and app ids for FlutterFire, emulator ports)

No service-account keys, private keys or passwords are in the repository.

## Known limitations

- Free-text search runs on the device over the 200 newest matching reports.
- Filters are one category and one status at a time.
- Staff are promoted by hand in the console.
- An anonymous report hides the name, but its opaque `reporterId` is still
  readable, so two anonymous reports by one person can be linked.
- Rejection requires a reason in the app only; the rules accept an empty
  note.
- The theme choice (System / Light / Dark) resets on restart.
- Photos are capped at 700 KB each (Firestore's 1 MiB document limit), so
  they are smaller than the camera original. Every view of a photo is a
  Firestore read, which counts against the Spark plan's daily read quota.

The full list, with reasons, is in `REPORT_ASSETS.md`.

## Other documents

- [`TEST_MATRIX.md`](TEST_MATRIX.md): 10 manual scenarios to run on a phone.
- [`DEMO_SCRIPT.md`](DEMO_SCRIPT.md): the 7-10 minute demo video, scene by
  scene.
- [`REPORT_ASSETS.md`](REPORT_ASSETS.md): material for the technical report,
  mapped to its sections, including where the code differs from it.
- [`DESIGN_NOTES.md`](DESIGN_NOTES.md): design tokens, colours, typography.
- [`PROGRESS.md`](PROGRESS.md): build log, step by step.
