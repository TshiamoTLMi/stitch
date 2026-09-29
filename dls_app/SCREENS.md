# Digital Lesela Sete — Screen Design Specification

> **RULE: This document is the authoritative source-of-truth for all screen designs.**
> Do NOT redesign any screen or change its layout without updating this document first.
> Sprint work must be additive (add features, connect data) — not visual rewrites.

---

## Design System Tokens (frozen)

| Token | Value | Usage |
|---|---|---|
| `background` | `#131313` | Page backgrounds |
| `surfaceLow` | `#1C1B1B` | Cards, bottom nav |
| `surfaceHigh` | `#2A2A2A` | Secondary surfaces, selected chips |
| `surfaceHighest` | `#353534` | Highest elevation surfaces |
| `primary` | `#F2CA50` | Gold — CTAs, active nav, brand |
| `primaryContainer` | `#D4AF37` | Gradient partner for gold |
| `secondary` | `#FFB4A5` | "In the Wash" status glow |
| `tertiary` | `#96E400` | Lime — AI, scanner, generate |
| `onSurface` | `#E5E2E1` | Body text |
| `onSurfaceVariant` | `#D0C5AF` | Secondary text, icons |
| `onPrimary` | `#3C2F00` | Text on gold buttons |

**Fonts:** `Plus Jakarta Sans` (headlines, FontWeight.w800) · `Inter` (body)  
**Radius rules:** Buttons/pills = `999px` · Cards = `18-24px` · Inputs = `999px` (no visible border)  
**No border rule:** UI elements do NOT have visible outlines/borders. Depth comes from surface layering.

---

## App Flow (navigation graph)

```
[login_signup_page.dart]  ──→  [home_shell.dart]
                                      │
               ┌──────────────────────┼──────────────────────┐
               ▼                      ▼                       ▼
      Tab 0: Home             Tab 1: Closet           Tab 2: Generate
    dashboard_page.dart    wardrobe_dashboard.dart  outfit_generator_page.dart
                                      │
                                      ▼ (FAB → push)
                                 upload_screen.dart
               
               Tab 3: Events          Tab 4: Profile
           event_planner_page.dart   profile_page.dart
```

---

## Screen 1 — Splash / Login

**Source HTML:** `splash_login/code.html`  
**Flutter file:** `lib/views/auth/login_signup_page.dart`  
**Status:** ✅ Locked (Sprint 1)

### Layout
- Full-screen hero background image (fashion editorial, dark/grayscale)
- Black fade gradient overlay (top transparent → bottom `#131313`)
- Radial gold ambient glow (subtle)

### Elements (top to bottom)
1. `DIGITAL ATELIER` — pill badge, gold text on `primary/10` bg, `letterSpacing: 2.6`
2. `Digital\nLesela Sete` — 58px, w800, tracking -2.5, white
3. `Your Drip, Sorted.` — 17px, `onSurfaceVariant`, tracking 0.3
4. **Enter the Atelier** button — gold gradient border pill (1.5px), `#131313` fill, fingerprint icon + white text
5. `or continue with` — divider row
6. **Google** + **Apple** social pills — `surfaceLow` fill, `onSurfaceVariant` icon + text
7. `Don't have an account? Sign up.` — link text
8. Privacy · Terms · Help — tiny uppercase footer

### Sprint Behaviour
- All buttons (`Enter`, Google, Apple) navigate to `HomeShell` via `pushReplacement`
- Auth (Firebase) not wired. Sign up / login forms are Sprint 3

---

## Screen 2 — Home Shell (Navigation)

**Source HTML:** `wardrobe_dashboard/code.html` (nav bar section)  
**Flutter file:** `lib/views/home/home_shell.dart`  
**Status:** ✅ Locked (Sprint 1)

### AppBar
- Background: `#131313`
- Title: `Digital Lesela Sete`, gold (`#D4AF37`), w800, tracking -0.4
- Right action: notification bell icon

### Bottom Navigation Bar
- Floats in `12px` margin container, `surfaceLow/92%` bg, `borderRadius: 40`
- 5 tabs: **Home** (home) · **Closet** (checkroom) · **Generate** (auto_awesome) · **Events** (calendar_today) · **Profile** (person)
- Selected indicator: `surfaceHigh` pill
- Active tab 1 (Closet): shows gold `+` FAB → opens `UploadScreen`

---

## Screen 3 — Wardrobe / Closet Tab

**Source HTML:** `wardrobe_dashboard/code.html`  
**Flutter file:** `lib/views/wardrobe_dashboard.dart`  
**Status:** ✅ Locked (Sprint 1)

### Header
- `My Wardrobe` — 42px, w800, tracking -1.5, white
- `Curating your digital legacy, one piece at a time.` — 13px, `onSurfaceVariant`

### Filter Chips (horizontal scroll)
- Options: `All Items · Tops · Bottoms · Shoes · Accessories`
- Selected = `primary (#F2CA50)` bg with `onPrimary (#3C2F00)` text
- Unselected = `surfaceHigh (#2A2A2A)` bg with `onSurfaceVariant` text
- Pill shape (radius 999), no border

### Wardrobe Grid
- 2-column `SliverGrid`, `childAspectRatio: 0.70`
- Item card (`_WardrobeCard`):
  - `borderRadius: 18`, bg `surfaceLow (#1C1B1B)`
  - Image fills top ~80% (`Image.network`, `BoxFit.cover`)
  - **Status badge** (top-left overlay):
    - Lime dot `#96E400` + glow = "Clean"
    - Peach dot `#FFB4A5` + glow = "In the Wash"
    - Badge bg: `#BB201f1f` (semi-transparent)
  - **Footer** (52px fixed height): category name (w800, 14px) + "My Closet" subtitle

### Empty States
- Waiting: gold `CircularProgressIndicator`
- Firebase error: cloud_off icon + "Firebase not connected." message
- No items: checkroom icon + "Your wardrobe is empty." + "Tap + to add your first piece."

### FAB
- Provided by `HomeShell` when Closet tab is active (`_index == 1`)
- 64×64 container, gold gradient, `borderRadius: 20`, gold shadow, `+` icon (`onPrimary`)

---

## Screen 4 — Closet Scanner / Upload

**Source HTML:** `closet_scanner/code.html`  
**Flutter file:** `lib/views/upload_screen.dart`  
**Status:** ✅ Locked (Sprint 1)

### Layout
- Scaffold bg: `#0E0E0E` (darkest black)
- Full-screen `Stack`
- Background layer: selected image (darkened) OR solid `#0E0E0E`
- Radial vignette: black radial gradient overlay

### Top Controls Bar
- Left: close `X` circle button (black/38%, white icon) → `pop()`
- Centre: `LESÉLA SETE` — gold, 13px, w800, tracking 3
- Right: flash icon circle (gold icon)

### Viewfinder Box  (`_ViewfinderBox`)
- Width: 80% of screen, `AspectRatio 3:4`
- Faint lime border (1.5px, `#96E400/30%`)
- **4 corner accents**: `CustomPaint` — lime lines, 3px stroke, 24×24 each
- Pulse line: horizontal bar at 50% alignment, lime glow shadow
- No-image hint: camera icon + `TAP SHUTTER TO CAPTURE` text
- AI tag chips (decorative): `TYPE: ...` · `TEXTURE: ...` — lime left-border pill

### Bottom Controls
- Instruction text row with side lines
- **No image mode**: Gallery circle (left) · Shutter button (centre, gold ring + white fill) · Flip camera (right)
- **Image selected mode**: Gallery circle (left) · `Add to Wardrobe` gold pill button (centre) · Refresh/retake (right)
- Upload state: `CircularProgressIndicator` replaces button text

### AI Pulse Orb (decorative)
- Bottom-right, 52×52, `surfaceHigh/85%`, lime border, lime glow shadow, `auto_awesome` icon

---

## Screen 5 — Outfit Generator

**Source HTML:** `outfit_generator/code.html`  
**Flutter file:** `lib/views/home/outfit_generator_page.dart`  
**Status:** ✅ Locked (Sprint 1 — logic wired, no visual changes needed)

### Key Elements
- `Outfit Choice Bot` headline
- Weather card: `surfaceLow`, `wb_sunny` gold icon, **auto-detected** via `WeatherService`
  (Open-Meteo) with source badge (`live` / `cached` / `default`) and a neutral fallback of
  22°C Warm. Options map 1-to-1 to the engine's six conditions: `Hot`, `Warm`, `Mild`,
  `Cold`, `Freezing`, `Rainy` — manual override always available.
- Dropdowns: Occasion · Mood · Weather (pill-shaped, `surfaceLow` fill)
- `Find My Fit` elevated button (gold, full width)
- Result card: style score, top/bottom/shoes/outerwear items, caption
- Regenerate + Save to History action buttons

---

## Screen 6 — Event Planner

**Source HTML:** `event_planner/code.html`  
**Flutter file:** `lib/views/home/event_planner_page.dart`  
**Status:** ✅ Locked (Sprint 1 — CRUD wired, no visual changes)

### Key Elements
- `Event Planner` headline
- Create event panel: event name text field · Occasion dropdown · Date picker · "Create Event" button
- Upcoming events list: `StreamBuilder`, event cards with occasion + outfit suggestion

---

## Screen 7 — Profile / Style DNA

**Source HTML:** `profile_style_dna/code.html`  
**Flutter file:** `lib/views/home/profile_page.dart`  
**Status:** ✅ Locked (Sprint 1 — static UI, auth wiring is Sprint 3)

### Key Elements
- Gradient-ring avatar (gold ring around circular photo)
- Stats tiles: item count, outfits generated, events planned
- AI insight panel (lime tertiary accent)
- Sign out button

### Release-readiness state contract (2026-09-26)
- Profile metrics use readable labels and distinguish loading, ready, empty, partial,
  error, offline, cached, and stale data states.
- Style evolution entries render newest-first with readable dates, mapped activity labels,
  concise descriptions, and safe fallbacks when optional audit fields are missing.
- Retry actions preserve the authenticated shell and do not replace unavailable data with
  complete-looking zero values.
- Login recovery shows validation, progress, neutral success, failure, offline, and retry
  states without changing the existing auth route or visual tokens.
- Event guidance shows the event name, date, occasion, recommendation reason, and one
  existing wardrobe or generator action. Android reminder status and Web in-app fallback
  status are explicit; no new top-level destination is added.

---

## What YOU Need to Provide (Blockers)

These are things only you can do — the code is already written and waiting:

| # | What | Why it's blocking |
|---|---|---|
| 1 | **Finalize Firebase Auth platform config** (Android SHA + OAuth, iOS OAuth) | Google sign-in can fail on physical devices if console credentials are incomplete |
| 2 | **Set production Firestore/Storage rules** | Required to safely ship beyond development settings |
| 3 | **Add `GoogleService-Info.plist` to `ios/Runner/`** | Required for iOS Firebase and Google sign-in runtime |
| 4 | **Run iOS setup on macOS** (`pod install`, signing/provisioning) | iPhone build/install cannot complete on Windows |
| 5 | **Run physical smoke tests** (Android + iPhone) | Final release gate requires real-device validation |
| 6 | **Images / brand assets** | Splash hero image currently loads from Unsplash URL — needs a local asset if going offline |

---

## Sprint Roadmap

Process audit tracking reference:
- `AUDIT_TRACKING_PLAN.md`

| Sprint | Focus | Screens affected |
|---|---|---|
| **Sprint 1** ✅ | Upload pipeline + wardrobe grid (Firestore stream) | Screen 4 (Upload), Screen 3 (Closet) |
| **Sprint 2** ✅ | Category tagging on upload, filter chips wired, item detail view | Screen 3, Screen 4 |
| **Sprint 3** ✅ | Real Firebase Auth (email + Google sign-in), protected routes | Screen 1 (Login), HomeShell auth guard |
| **Sprint 4** ✅ | Outfit generator with real wardrobe data, save history | Screen 5 (Generate) |
| **Sprint 5** ✅ | Event planner with outfit suggestions wired to wardrobe | Screen 6 (Events) |
| **Sprint 6** ✅ | Profile / Style DNA with real user data, AI caption display | Screen 7 (Profile) |
| **Sprint 7** ✅ (code phase) | Automated QA + release prep docs + final physical-test handoff | All screens |
| **Sprint 8** 🟡 ACTIVE — preflight gate CLEARED ✅ | Release Readiness & Preflight Verification | All screens (no visual change) |
| **Sprint 9** 🚧 IN-PROGRESS | P1 AI Personalization & On-Device Outfit Engine | Screen 5 (Generate), Screen 7 (Profile) |

---

## Source HTML Files (reference, do not modify)

| HTML File | Maps To |
|---|---|
| `splash_login/code.html` | Screen 1 — Login |
| `wardrobe_dashboard/code.html` | Screen 3 — Closet + nav bar |
| `closet_scanner/code.html` | Screen 4 — Upload Scanner |
| `outfit_generator/code.html` | Screen 5 — Generate |
| `outfit_result/code.html` | Screen 5 sub-screen — Result |
| `event_planner/code.html` | Screen 6 — Events |
| `profile_style_dna/code.html` | Screen 7 — Profile |
| `sign_up/code.html` | Sprint 3 — Sign Up page |
| `aura_noir_elite/DESIGN.md` | Global design system tokens |

---

## Sprint 7 Execution Status (Current)

### Completed
- Added code-based service tests for generator, recommendations, and caption generation.
- Confirmed sprint docs align with current implementation state.
- Completed repository-side iOS readiness docs and setup guidance.

### Next
1. Run Android physical smoke checklist end-to-end.
2. Run iPhone smoke checklist on macOS/Xcode.
3. Capture physical-test outcomes and close final release gate.

---

## Sprint 3 Action Plan (Current)

### Completed
- Email/password login and sign-up wired to Firebase Auth.
- Google sign-in implemented (web popup + mobile OAuth credential flow).
- App-level auth gate added so unauthenticated users are routed to login and authenticated users land in Home shell.
- Home shell no longer uses guest fallback ids; authenticated context is required.

### Operational note
1. Google sign-in requires platform console setup to work at runtime:
  - Android SHA-1/SHA-256 in Firebase project settings.
  - Correct OAuth consent/supported domains where applicable.
2. iOS support now includes repo-side permission and URL-scheme setup, but final iPhone validation still requires:
  - `GoogleService-Info.plist` in `ios/Runner/`
  - `pod install` on macOS
  - Xcode signing/provisioning

---

## Sprint 4 Audit Summary (2026-04-11)

### Completed
- Generator now persists results via `OutfitHistoryService`.
- Generator now displays recent history list from `outfit_history`.
- Caption text is stored alongside generated outfit data.
- Generator actions produce audit trail entries in `audit_events`.

### Validation
1. `flutter analyze` passed.
2. Data contract validated in code path for save + retrieval.

---

## Sprint 5 Audit Summary (2026-04-11)

### Completed
- Event records now persist recommendation payloads (`recommended_outfits`).
- Event list renders persisted recommendations first.
- Event creation now writes audit entries.
- Event query hardening avoids index-precondition runtime errors.

### Validation
1. `flutter analyze` passed.
2. Event create/read path verified at code integration level.

---

## Sprint 6 Audit Summary (2026-04-11)

### Completed
- Profile metrics now read live user-scoped Firestore data.
- AI insight panel now reflects top category and latest caption.
- Style evolution log now displays `audit_events` stream.
- Added one-tap demo dataset generation for test readiness.

### Validation
1. `flutter analyze` passed.
2. Android toolchain prerequisites completed for physical device testing.

### Device setup progress
1. Android cmdline-tools installed.
2. Android SDK licenses accepted.
3. Physical device visible to ADB but currently `unauthorized` until on-device prompt is accepted.

---

## Sprint 8 Execution Status (ACTIVE — Preflight Gate CLEARED)

**Focus:** Release Readiness & Preflight Verification
**Status:** 🟡 ACTIVE — baseline preflight gate cleared (2026-09-29)
**Screens affected:** All screens (no visual change — design contract remains frozen)

### Scope
1. Re-verify the repository baseline build/test gate before any Sprint 9 feature work.
2. Confirm branch hygiene: keep development on `dev` and promote `dev` into `test` for pre-prod testing.
3. Keep release-readiness evidence current for the remaining physical/external gates.

### Preflight Evidence (2026-09-29)
`tooling\preflight_check.ps1` executed end-to-end → **`All preflight checks passed.`**

| Gate | Result |
|---|---|
| `flutter analyze` | ✅ Passed |
| `flutter test` (full suite) | ✅ Passed |
| Focused story tests (9 files) | ✅ Passed |
| `flutter build apk --debug` | ✅ Passed |
| `flutter build apk --release` | ✅ Passed (`app-release.apk`, 61.6MB) |
| `flutter build web --release` | ✅ Passed (`Built build\web`) |

### Branch Verification
- Branch model (per `AUDIT_TRACKING_PLAN.md` §3): `dev` = coding development → `test` = pre-prod testing → `main` = production.
- Development commits are authored on `dev`, then promoted `dev` → `test` for pre-prod validation.
- Sprint 8 docs landed on `dev`; `test` was fast-forwarded from `dev` so pre-prod reflects the latest development baseline.

### Remaining before close
1. Android physical notification / launcher / upgrade + account-preservation checks.
2. Production-like Web reset / OAuth / upload / PWA install / low-network checks.
3. Firebase Console + deployed-rules verification (release owner).

---

## Sprint 9 Execution Status (IN-PROGRESS)

**Focus:** P1 AI Personalization & On-Device Outfit Engine
**Status:** 🚧 IN-PROGRESS
**Screens affected:** Screen 5 (Generate), Screen 7 (Profile)

### Planned scope (from `FEATURE_PLANS.md` P1)
1. **AI Style DNA v1** — derive an explainable style profile from onboarding + closet metadata.
2. **AI Outfit Ranking v2** — improve scoring using weather/event context and preference history.
3. **Feedback Loop** — like/dislike on suggestions, feeding future ranking.
4. **On-Device Outfit Engine** — keep generation serverless/on-device with the existing rule engine and offline fallbacks.
5. **Onboarding retention** — save interrupted onboarding progress and show completion state.

### Constraint
Work must be **additive** to this contract. No screen redesign, navigation change, or token change
without updating this document first. Services remain UID-scoped and deterministic/offline-safe.
