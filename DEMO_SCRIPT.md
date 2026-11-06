# Demo video script (7-10 minutes)

Record the phone screen (Android emulator or `scrcpy` for a real phone) with
your voice. Have two devices or two emulators ready: one signed in as the
**student**, one as **staff**. Keep the Firebase console open in a browser
tab for scenes 6 and 8.

## Before recording

- [ ] Rules and indexes deployed (README steps 2-3).
- [ ] Student account (`@alustudent.com`) and staff account
      (`@alueducation.com`) both verified; the staff one gets
      `role: "staff"` automatically.
- [ ] Seed these reports as the student (they make the dashboard
      interesting):

  | Title | Category | Building | Then, as staff |
  |---|---|---|---|
  | Leaking tap on the 2nd floor | Water | Library | leave Submitted |
  | Power cut in room B2 | Electricity | Residence hall A | Under review |
  | Broken chair near the window | Furniture | Cafeteria | In progress |
  | Bin overflowing at the entrance | Sanitation | Main building | Resolved |
  | Duplicate: chair in cafeteria | Furniture | Cafeteria | Rejected ("Duplicate of an earlier report") |

- [ ] One fresh, unverified ALU address ready for scene 1, and a Gmail
      address.
- [ ] Phone in light mode, notifications silenced.

## Scenes

| # | Time | Show | Say (key points) |
|---|---|---|---|
| 1 | 0:00-0:45 | Title screen, then the Register screen. Try a Gmail address: show the error. Register with the ALU address. | The problem: campus issues get lost. The app's goal. Only ALU emails can sign up; this is also checked by Firebase on the server. |
| 2 | 0:45-1:30 | Verify Email screen; open the email, click the link; the app moves on by itself. | Email verification is mandatory; the app polls and checks when you come back. The profile is created on first verified login, always as a student. |
| 3 | 1:30-3:00 | Report tab: submit an empty form (errors), then a real report with a camera photo. Show the progress bar and the detail screen. | Validation on every field. Photos are compressed to fit a Firestore document (free Spark plan, no Storage bucket) and their location data removed. If saving fails, uploaded photos are cleaned up. |
| 4 | 3:00-4:00 | Feed: search "cafeteria", filter Furniture + In progress, clear. Pull to refresh. | Real-time feed. Category and status filters run on the server (indexed queries), search runs on the device. Loading, empty and error states. |
| 5 | 4:00-5:00 | Open a report: status chip, lifecycle rail, photos full screen with zoom, status history. Edit your own Submitted report; show Delete asks for confirmation. | Detail is live. Reporters can edit or delete only while Submitted. |
| 6 | 5:00-6:30 | Staff device: Dashboard counts and the oldest-first queue, tap a count to filter. Open the new report, Update status -> Under review with a note. Student device: the change and note appear live. Try Rejected without a reason. | Staff accounts open straight on the Dashboard. Only allowed next statuses are offered. Status and history are saved in one batch. In the console, show the new `statusHistory` document. |
| 7 | 6:30-7:30 | Anonymous report: student view ("Reported anonymously"), staff view (name, "visible to staff only"). Student has no Dashboard tab. | Anonymity is enforced by data: the name is never stored on the report, and students cannot read other users' profiles. |
| 8 | 7:30-8:30 | Show `firestore.rules` briefly (staff check, transition check, history check). Run the rules tests or show their passing output; show `flutter test` passing. | Access control is enforced by the backend, not only the UI. 38 rules tests, 165 Flutter tests, an end-to-end integration test. |
| 9 | 8:30-9:15 | Profile: role badge, My reports, switch to Dark mode and flip through two screens. Log out (confirmation). | Accessibility: status is never colour alone, contrast checked by tests, large-text layouts tested. |
| 10 | 9:15-9:45 | Back to the title. | Limitations (client-side search, role changes by hand in the console, photo size cap) and what you would do next. |

## Tips

- Rehearse scene 6 once: the live update on the second device is the most
  convincing moment.
- Keep each scene short; cut long waits (index builds, emails) in editing.
