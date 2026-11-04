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
| 1 | Scaffold, dependencies, theme, router skeleton, Firebase init | Done, awaiting commit |
| 2 | Models, validators, constants + unit tests | Not started |
| 3 | Auth repository, providers, auth screens, router guards | Not started |
| 4 | Rules, users collection, `isStaffProvider` | Not started |
| 5 | Incident repository, streams, feed, reusable widgets | Not started |
| 6 | Report form, photo upload, cleanup on failure | Not started |
| 7 | Detail, edit/delete, status timeline | Not started |
| 8 | Staff status update (batch), dashboard | Not started |
| 9 | Profile, polish, states, dark mode | Not started |
| 10 | Tests, rules tests, docs, README, demo script, report assets | Not started |

Last checkpoint confirmed committed: step 0 (`60e7060`).

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
- **Android build not verified yet in this environment:** `flutter build apk
  --debug` fails before compiling with Gradle's `java.io.IOException: Unable to
  establish loopback connection` (inside and outside the sandbox). This is a
  machine-level Java/Windows issue (the JDK's socket selector uses AF_UNIX
  sockets in the temp folder, and `C:\Users\PC DISAINE\...` has a space), not
  a project error. Fix to try: add
  `org.gradle.jvmargs=... -Djdk.net.unixdomain.tmpdir=C:/Temp` (create
  `C:\Temp`) or check firewall/antivirus blocking `java.exe` on localhost.
- Fonts load via `google_fonts` at runtime; first launch offline falls back
  to the system font.
