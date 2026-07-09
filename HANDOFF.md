# Moody — overnight build handoff

Built overnight 2026-07-07 → 07-08 from `design_handoff_moody_app/`. Native SwiftUI, iOS 17+, no third-party dependencies.

## Run it

```bash
xcodegen generate        # only needed after adding/removing files
open Moody.xcodeproj     # then ⌘R on any iPhone simulator (iPhone 17 Pro matches the mockups' 402×874)
```

The project is **XcodeGen-managed**: `project.yml` is the source of truth — never hand-edit `Moody.xcodeproj`, just re-run `xcodegen generate`.

First launch shows onboarding (cast co-creation). To skip: finish or tap "or skip — the cast works at any size."

## What's built

| Piece | State |
|---|---|
| The Fridge (home) | Pixel-faithful to the chosen mockup; decide-for-me, swap (exactly 3), tank check, long-press door → Vent |
| Week plan | All 7 day rows, tap-to-swap, long-press-to-lock, "deal me 3" on open days |
| Shopping | Guarantee banner, 3 tiered run cards with no-shame outs, ALWAYS STOCKED shelf |
| Streaks | Hero card (never renders "0"), week strip, freeze pops, THE RETURN |
| The Vent | Dark quiet room, Quicksand headline, fake waveform, zero-effort escape hatch |
| Group thread | Personas (blob avatars) vs family (flat initial circles), tapbacks, quick replies, local composer |
| Onboarding | 3 steps: household/safety → palette colors → persona co-creation with sass slider |
| Celebrations | Confetti / sticker slap / marquee / blob party; rotation never repeats; **no API exists for misses** |
| Widgets | Small + medium "Tonight" (guarantees always visible), `moody://` deep links wired |
| Live Activity | Cook-mode lock screen + Dynamic Island; demo trigger: launch env `MOODY_DEMO=cookmode` |

Screenshots of every screen: `docs/screenshots/`.

## Architecture (30 seconds)

- `Moody/DesignSystem/` — `Theme` (tokens), `Palette` (the 5 user slots — **swappable by design**, law 6), components (`MagnetDot`, `StickyNote`, `SafetyBadge`, `BlobAvatar`, …). Hard shadows are zero-blur and composited off the flattened silhouette.
- `Moody/Models/` + `Moody/Data/AppState.swift` — domain per the README's state sketch; all demo data lives in `AppState`. `Streak.displayDay` clamps so "0" is unreachable.
- `Moody/Screens/<Name>/` — one folder per screen; screens take optional navigation closures, wired in `Moody/App/RootView.swift`.
- `MoodyWidgets/` — widget extension. `CookModeActivity.swift` compiles into **both** targets (ActivityKit needs matching types) — don't remove it from the app's sources.
- Personas are scripted (`AppState.thread`, message banks) behind a plain data layer — swapping in live Claude API generation later means replacing the source of `ThreadMessage`s, not touching views.

## Debug hooks (simulator conveniences, safe to delete later)

```bash
SIMCTL_CHILD_MOODY_SCREEN=week xcrun simctl launch <sim> com.mariayarley.Moody   # jump to any screen
# values: home week shopping streaks vent thread onboarding
SIMCTL_CHILD_MOODY_DEMO=decide …     # fires the confetti celebration on launch
SIMCTL_CHILD_MOODY_DEMO=cookmode …   # starts the cook-mode Live Activity
SIMCTL_CHILD_MOODY_RESET=1 …         # deletes the persisted snapshot + restores demo seeds
```

Gotcha: `MOODY_SCREEN=onboarding` persistently resets the `hasOnboarded` flag, so the *next* plain launch shows onboarding again. Launch once with any other `MOODY_SCREEN` value to restore it.

## Deliberate calls made overnight (flag if you disagree)

- **Backgrounds**: exploration mockups 2c/2d/2g use white pages, but the README token sheet says `shelf #F7F4EE` is the standard screen background — the token won. (Home uses `fridge #EFEBE2` per its mockup.)
- **Week plan carries two stickers** (ANCHOR + JOY) exactly as its mockup shows, despite the one-sticker law.
- **Vent headline** uses actual Quicksand (now bundled) — the mockup's face, not in the original font list.
- **Navigation chrome**: system back button was glassy/off-language; pushed screens hide the nav bar and float a kit-styled back chip instead. Swipe-back is disabled as a result — revisit if that bothers you.
- **Week magnet labels** derive from `meal.id` ("Tue tacos"); swapping tonight to e.g. "GF mac & peas" shows "Tue gfmac" — a display-keyword field on `Meal` is the fix when real data arrives.

## Not built yet (obvious next steps)

- ~~Real persistence~~ core state now persists via an App Group JSON snapshot (`Moody/Data/Persistence.swift`; debounced saves from `AppState`, demo data stays the first-launch seed)
- Voice entry (mic buttons are affordances, not wired to dictation)
- Live persona generation via Claude API (structure is ready; needs a key)
- Onboarding steps 4+: stressor interview, per-member meal swipe-rating
- Real meal/recipe data + the constraint solver beyond the demo pool
- ~~Widget ↔ app shared state~~ widgets now read the App Group snapshot (live tonight-meal + tank; refresh ≤15 min or instantly on app saves)

## Review status

A 28-agent review ran overnight (4 lenses: core correctness, screen correctness, design-law compliance, accessibility/robustness), with every finding adversarially verified before being accepted: 24 raw findings → 23 confirmed → **all highs and mediums fixed the same night**, plus most lows.

Fixed (highlights):
- **Small widget tap was destructive**: whole-widget URL was `moody://decide`, so glancing-taps silently re-planned dinner. Now opens the app; deciding stays a deliberate in-app action.
- **`swapOptions()` could return 2, not 3** (law 2) when tank = Fumes — now guaranteed exactly 3, low-effort ranked first.
- **"PB 0" was reachable** for a brand-new user (law 4's spirit) — PB strings now clamp like `displayDay`, sticker hides when there's no PB yet.
- **Fonts now use `fixedSize`** — Dynamic Type scaling would have broken the fixed-height screens; deliberate trade-off, revisit when layouts can reflow.
- **VoiceOver**: the Vent got an accessibility action (was long-press-only), week rows became real buttons with a lock action, tank segments expose selection, thread composer is labeled, blob party is dismissible.
- Debug hooks made run-once (`.task`), Live Activity dedup, swap-sheet snapshot (no reshuffle during dismiss), onboarding double-tap guard, effort dots drawn as shapes everywhere (Nunito lacks ●○ glyphs).

Flagged for your judgment (not fixed):
- **Muted-label contrast**: `labelMuted` companions measure ~2.4:1 on their tints (e.g. "PB 23 · the rebuild" pink-on-pink). It's the mockup's exact palette — but worth a design pass; using the slot's primary `label` color instead already hits 4.4:1.
- **Week plan's "JUL 6–12" date chip** reads as a third sticker moment (law 5 says max one; the mockup itself draws it). Mockup parity won tonight.
- Unwired model stubs kept intentionally: `Persona.role/.duty`, `HouseholdMember.need` (safety badges are hardcoded demo strings). *[Historical — badges are derived post-P1 graft; the go-forward derivation is FoodRules + D-46 chips (see DECISIONS.md D-42/D-44/D-46), not the `need` enum.]*
