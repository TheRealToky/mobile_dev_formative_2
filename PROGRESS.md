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
| 0 | Architecture review + `DESIGN_NOTES.md` | Done, awaiting commit |
| 1 | Scaffold, dependencies, theme, router skeleton, Firebase init | Not started |
| 2 | Models, validators, constants + unit tests | Not started |
| 3 | Auth repository, providers, auth screens, router guards | Not started |
| 4 | Rules, users collection, `isStaffProvider` | Not started |
| 5 | Incident repository, streams, feed, reusable widgets | Not started |
| 6 | Report form, photo upload, cleanup on failure | Not started |
| 7 | Detail, edit/delete, status timeline | Not started |
| 8 | Staff status update (batch), dashboard | Not started |
| 9 | Profile, polish, states, dark mode | Not started |
| 10 | Tests, rules tests, docs, README, demo script, report assets | Not started |

Last checkpoint confirmed committed: none yet.

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
- Fonts load via `google_fonts` at runtime; first launch offline falls back
  to the system font.
