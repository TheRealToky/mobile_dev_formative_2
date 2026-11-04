# Design notes

Design decisions for the Campus Incident Reporting App. Cite this file in
section 9 (UI/UX design decisions) of the report. All values here are
implemented in `lib/app/theme.dart` and the reusable widgets in `lib/widgets/`.

## 1. Subject, audience, job

- **Subject:** maintenance and safety reporting on the ALU Kigali campus
  (water, electricity, facilities, furniture, sanitation, safety).
- **Audience:** students on their phones, often standing in front of the
  problem (a dark corridor, a leaking tap), sometimes in a hurry; and a small
  number of staff who triage many reports.
- **Primary job:** get a usable report in under a minute, then answer the
  question students actually care about: *is anyone handling this?*

## 2. Aesthetic direction: "work order slip"

The vernacular of the subject is the maintenance work order: a ticket with a
category, a location, a stamp that says where it is in the process. The app
borrows that, not the generic social-feed look.

- Incidents read as **tickets**: flat, outlined surfaces with a clear
  category icon, title, location line and status. No drop shadows, no
  gradient washes.
- **The one bold element is the lifecycle rail.** Every incident card and
  the detail header show a small four-step rail
  (Submitted → Under review → In progress → Resolved) with the current step
  filled in the status colour. A rejected report shows the rail broken after
  "Under review". This makes "where is my report?" answerable at a glance,
  which is the product's main promise. Everything else stays quiet.
- Status is always **colour + icon + text**, never colour alone
  (colour-blind users, outdoor glare).

### What I changed after reviewing the first plan against the brief

| First instinct (generic default) | Revised choice | Why |
|---|---|---|
| Roboto (Material default) | **Atkinson Hyperlegible** | Designed by the Braille Institute for low-vision legibility; distinct letterforms (I/l/1, O/0) help with room codes like "B1-02". Fits the accessibility claims in the report. |
| Indigo/purple seed | **Deep lake teal `#0E5E6F`** | Calm, institutional, not the default Material purple; keeps warm hues free for the status colours that must stand out. |
| Elevated cards with shadow on every item | **Outlined, flat tickets** (1 dp outline, no elevation) | Avoids the "SaaS card kit"; shadows add noise in long lists. |
| Same radius everywhere | **Radius encodes hierarchy** (see 5) | Sheets > cards > chips; rounder = more temporary. |
| Status as a pill only | **Pill + lifecycle rail** | The rail is the memorable, subject-specific element. |

## 3. Colour

One seed, `ColorScheme.fromSeed(seedColor: kSeed, brightness: ...)`, gives
the light and dark schemes. Status colours are a fixed semantic set (not
derived from the seed) so they mean the same thing in both themes.

| Token | Hex | Role |
|---|---|---|
| `kSeed` (lake teal) | `#0E5E6F` | Seed for the whole M3 scheme; primary actions, selected nav item |
| Surface (light) | generated (`surface`) | Backgrounds; kept neutral, no cream tint |
| Outline | generated (`outlineVariant`) | Ticket borders, dividers |
| Error | generated (`error`) | Form errors, destructive actions |

### Status colours

Each status has a foreground (icon + text) and a container (chip
background). Light / dark pairs were chosen so foreground-on-container meets
WCAG AA (4.5:1) for 12-14 sp labels.

| Status | Text | Icon | Light fg / container | Dark fg / container |
|---|---|---|---|---|
| `submitted` | Submitted | `outbox` | `#3D4F66` / `#E3E9F1` | `#C4D2E3` / `#2A3646` |
| `under_review` | Under review | `visibility` | `#7A4E00` / `#FCEBC7` | `#F5CD7A` / `#4A3300` |
| `in_progress` | In progress | `construction` | `#9A3412` / `#FDE3D3` | `#FDBA94` / `#5A2410` |
| `resolved` | Resolved | `check_circle` | `#1E6B3C` / `#D7F0DF` | `#9FDCB4` / `#163F27` |
| `rejected` | Rejected | `block` | `#9F1D1D` / `#FADBDB` | `#F3A6A6` / `#5C1616` |

"In progress" uses a hi-vis work orange on purpose: it is the colour of
someone actually on site.

### Category icons

| Category | Label | Icon |
|---|---|---|
| `water` | Water | `water_drop` |
| `electricity` | Electricity | `bolt` |
| `facilities` | Facilities | `apartment` |
| `furniture` | Furniture | `chair` |
| `sanitation` | Sanitation | `cleaning_services` |
| `safety` | Safety | `health_and_safety` |
| `other` | Other | `more_horiz` |

Category icons use `onSurfaceVariant` inside a `surfaceContainerHigh` square,
so category never competes with status for colour.

## 4. Typography

One family: **Atkinson Hyperlegible** (via `google_fonts`; see note below),
applied to the whole M3 `TextTheme`. Hierarchy comes from size and weight,
not from a second typeface, all caps or coloured words.

| M3 role | Size / line height (sp) | Weight | Used for |
|---|---|---|---|
| `headlineSmall` | 24 / 32 | 700 | Screen titles on auth screens, detail title |
| `titleLarge` | 20 / 28 | 700 | App bar titles, dashboard counts |
| `titleMedium` | 16 / 24 | 700 | Card titles, section headings |
| `bodyLarge` | 16 / 24 | 400 | Form input, description text |
| `bodyMedium` | 14 / 20 | 400 | Card location line, timeline notes |
| `labelLarge` | 14 / 20 | 700 | Buttons |
| `labelMedium` | 12 / 16 | 700 | Status chip, filter chip text |
| `bodySmall` | 12 / 16 | 400 | Relative time, helper text |

Rules: sentence case everywhere; no all-caps labels; no eyebrows above
headings; description text capped at ~70 characters per line on large
screens (`ConstrainedBox(maxWidth: 640)`).

**Font loading note:** `google_fonts` fetches the font on first run and
caches it. Offline first launch falls back to the platform sans-serif, which
is acceptable. In tests runtime fetching is disabled so tests never hit the
network.

## 5. Spacing, shape, touch

| Token | Value | Use |
|---|---|---|
| `Gap.xs` | 4 | Icon-to-text inside chips |
| `Gap.sm` | 8 | Between chips, inside cards |
| `Gap.md` | 12 | Card internal padding (vertical) |
| `Gap.lg` | 16 | Screen side gutter, card padding (horizontal) |
| `Gap.xl` | 24 | Between form sections |
| `Gap.xxl` | 32 | Top of auth screens |

| Shape | Radius |
|---|---|
| Bottom sheets, dialogs | 28 (M3 default) |
| Incident tickets, photo thumbnails | 12 |
| Inputs, buttons | 12 |
| Status and filter chips | 8 |

- Minimum touch target **48 × 48 dp** (`MaterialTapTargetSize.padded`,
  `minimumSize: Size(48, 48)` on buttons, icon buttons left at the M3 48 dp).
- Primary buttons are full width on forms, 52 dp tall.

## 6. Layout

Single column, left aligned, 16 dp gutters, max content width 640 dp centred
on wide screens and landscape (`flutter-build-responsive-layout`).

```
Feed
┌──────────────────────────────┐
│ Reports                 (🔍) │  app bar
│ [ Search title, building… ]  │  search field
│ (Water)(Power)(Safety)(…) →  │  category chips, horizontal scroll
│ (Submitted)(In progress)(…) →│  status chips
│ ┌──────────────────────────┐ │
│ │ [💧] Leaking tap in B2   │ │  ticket: icon, title
│ │      Block B · 2nd floor │ │  location
│ │ ●──●──○──○  In progress  │ │  lifecycle rail + status chip
│ │                   2h ago │ │  relative time
│ └──────────────────────────┘ │
└──────────────────────────────┘
  Feed   Report   Dashboard*  Profile      (*staff only)

Report form
  What kind of issue?      (chip grid)
  Title                    [            ]
  What happened?           [            ]
  Building                 [ dropdown ▾ ]
  Where exactly?           [            ]
  Photos (optional, max 3) [+][img][img]
  [ ] Hide my name from other students
  [        Submit report        ]   ← disabled + progress while saving

Detail
  [photo gallery, swipe]
  Title / category / location
  ●──●──●──○  In progress
  Description
  Timeline (statusHistory, oldest first)
  [Update status] (staff)   [Edit] [Delete] (reporter, while Submitted)
```

## 7. Feedback and motion

- Loading: skeleton tickets in the feed (static shapes in
  `surfaceContainerHighest`, no shimmer animation); spinners inside buttons
  while saving; linear progress for photo uploads.
- Empty: `EmptyState` with an icon, one sentence and an action
  ("No reports match these filters." → "Clear filters").
- Error: `ErrorView` says what failed and offers "Try again". No apologies.
- Success: snackbar named after the action ("Report submitted",
  "Status updated to In progress").
- Motion: only in response to actions (sheet open, chip select, rail step
  animating to the new status). Respects `MediaQuery.disableAnimations`.

## 8. Copy rules

- Buttons say what happens: "Submit report", "Update status", "Delete
  report", "Resend email", "Log out".
- The same name follows the action through the flow (button "Submit report"
  → snackbar "Report submitted").
- Errors explain what to do: "Use your ALU email (ending in
  @alustudent.com or @alueducation.com)."
