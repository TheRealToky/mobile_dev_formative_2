# Manual test matrix

Run on an Android phone or emulator against the real Firebase project, after
the [setup checklist](README.md#setup-checklist). You need:

- **S1:** verified student account (`@alustudent.com`).
- **S2:** a second verified student account.
- **ST:** verified `@alueducation.com` account (gets `role: "staff"`
  automatically on first login).
- A non-ALU address you can receive mail on (for example a Gmail address).

Fill in **Pass/Fail** and **Notes** as you go. "Automated" names the tests
that already cover the same behaviour with fakes; this matrix checks it on
the real backend and device.

| # | Scenario | Steps | Expected result | Automated | Pass/Fail | Notes |
|---|---|---|---|---|---|---|
| 1 | Only ALU emails can register | Register with a Gmail address. Then register with an `@alustudent.com` address. | Gmail: "Use your ALU email (ending in @alustudent.com or @alueducation.com)." and no account is created (check Console -> Authentication). ALU address: account created, Verify Email screen shown. | `auth_screens_test`, `validators_test`, rules tests | | |
| 2 | Email must be verified | After registering, try to reach the feed without clicking the link; tap "I have verified my email". Then click the link in the email and return to the app. | Before: stays on Verify Email, "Not verified yet. Open the link in the email." After: app moves to the feed on its own within a few seconds; `users/{uid}` exists with `role: "student"`. | `router_redirect_test`, `auth_providers_test` | | |
| 3 | Login errors and password reset | Log in as S1 with a wrong password. Then tap "Forgot password?". | "Email or password is incorrect." Reset email arrives. | `auth_screens_test` | | |
| 4 | Submit a report with a photo | As S1: Report tab, choose Water, title, description, building Library, add 1 photo from the camera, submit. | Progress shown; lands on the detail screen with the photo; "Report submitted". In Storage the file has no GPS EXIF (download it and check its properties). | `report_controller_test`, `report_form_screen_test`, integration test | | |
| 5 | Validation and offline submit | Submit an empty form. Then turn on airplane mode, fill a valid report without photos, submit; turn airplane mode off. | Empty: every field flagged, "Check the highlighted fields." Offline: "You are offline. The report is saved on this phone..." and it appears in the feed; after reconnecting it is on the server (Console). | `report_form_screen_test`, `report_controller_test` | | |
| 6 | Feed search, filters, real-time | As S2 with the feed open, have S1 submit a new report on another phone. Search for a word in its location; filter by its category, then also by status; clear filters. | New report appears without refresh. Search and filters narrow the list; "No reports match these filters." with "Clear filters" when empty. | `feed_screen_test`, `incident_providers_test` | | |
| 7 | Anonymous report | As S1 submit a report with "Hide my name from other students" on. Open it as S2, then as ST. | S2: "Reported anonymously". ST: "Reported anonymously by <S1 name> (visible to staff only)". S1: "Reported anonymously by you". | `incident_detail_screen_test` | | |
| 8 | Edit and delete own report | As S1 edit a "Submitted" report (change title, remove a photo), save. Then delete it. As S2 open another S1 report. | Edit saves and the detail updates. Delete asks first, then "Report deleted" and it disappears for everyone. S2 sees no Edit or Delete buttons. | `incident_detail_screen_test`, `report_controller_test`, rules tests | | |
| 9 | Staff status update | As ST: (the app opens on the Dashboard) open the oldest report -> Update status -> Under review with a note. Then In progress, then Resolved. Try Rejected on another report without a reason. Keep S1's detail screen open on another phone. | Only allowed next statuses are offered. Note shows in the timeline; S1 sees each change live. Counts on the dashboard move. Rejecting without a reason: "Say why the report is rejected." Once Resolved, S1 can no longer edit it and the Update status button is gone. | `status_controller_test`, `staff_screens_test`, integration test, rules tests | | |
| 10 | Students cannot act as staff; dark mode | In the console set S1's `role` to `staff`: S1's app jumps to the Dashboard; set it back to `student`: back to the Feed. As S1: confirm there is no Dashboard tab (the app has no deep links, so the `/staff` redirect itself is checked by `router_redirect_test`). Profile -> Appearance -> Dark, browse every screen; turn on TalkBack and read a report card. | No Dashboard tab. In dark mode every screen is readable with no clipped text; TalkBack reads status as "Status: In progress" and the rail as "Progress: Step 3 of 4, In progress". | `router_redirect_test`, `role_routing_test`, `staff_screens_test`, `dark_mode_smoke_test`, `theme_contrast_test`, rules tests | | |

Tester: ____________________ Date: ____________ Device / Android version: ____________________
