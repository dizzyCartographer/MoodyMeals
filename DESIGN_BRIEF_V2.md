# Moody design brief, round 2 — the missing screens

**To: the design session that produced `design_handoff_moody_app/`.**
**From: the build session (Claude Code) that implemented it.**

Round 1 is built. All seven screens from your kit exist in native SwiftUI, pixel-audited against your mockups — see `docs/screenshots/` in this folder for the current state, and `HANDOFF.md` for what was built and the judgment calls made. Your token sheet now lives as code in `Moody/DesignSystem/Theme.swift`; treat that file as the canonical token values going forward.

This brief is the gap list: every surface the product needs that round 1 never designed. It was compiled by sweeping your README's implications, the built app's dangling affordances, and standard iOS hygiene — then deduplicated. Maria will art-direct from build screenshots, so mockups are **art direction, not specs**: one authoritative frame per screen is enough; I extrapolate states from your system.

## ⚠️ CANON ADDENDUM (added 2026-07-09 — read before designing)

A parallel build surfaced 41 user-ratified product decisions (`UNIFICATION_PLAN.md` has the full story). The ones that change mockups:

- **Lunch is in scope (D-40).** The week plan needs a home for breakfast/lunch/dinner slots, not just dinner rows + an AM strip. This reshapes Wave-1 item 6 (day editor) and the week plan itself.
- **Safety badges are tri-state, per-attendee, derived (D-35, D-38, HC-3/5).** Never hardcode member names in designs as if always-present: a meal can be *verified GF* / *contains gluten* / *unverified — check label*, and badges reflect who's ATTENDING (Caddie away unlocks gluten — design that state). Design the **never-silent GF override confirm** (HC-5): assigning an unverified meal to a celiac attendee needs a deliberate-weight confirm moment — no red (law 4), but real gravity. This is the one place the kit's candy language must carry medical seriousness.
- **Streaks count ANY dinner (D-13)** — fallback, leftovers, takeout — with a 48h grace window. "DINNERS FROM HOME" copy is wrong; reframe the hero as "dinner happened."
- **Persona cast rules (D-20…D-26):** 3–5 co-created cast, ≥2 homage-of-real-people + ≥2 fictional; four roles — Noticer, **Never-Left** (never references absence, pure continuity), Hype (celebrates comebacks only after re-engagement, never first), **Kindred** (canonically ADHD, disappears too, returns self-gap-blind). The group thread NEVER discusses her absence. Onboarding's cast co-creation step should reflect the 2+2 suggestion.
- **No sheet-pan framing anywhere (D-4)** — it stresses the user. **Eating out is nuclear (D-7)** — never suggested, never scheduled; don't design affordances that propose it.
- **Meal library (Wave-1 item 4) has a working behavioral spec** in the parallel build's plain UI (full CRUD field inventory, loose/precise recipes, tri-state GF badge) — mock the *design*; the fields and flows are already decided.

## Standing decisions — do not redesign these

- **Cast**: Ria, Chuck, Caddie (celiac), Elsie (safe foods), Chad (×2, Wed cook). Personas: Hannah, Cat, Julie. Use them in all mockups — no placeholder names this round.
- **Muted labels were darkened** (Maria's call, 2026-07-08): `labelMuted` companions now use each slot's primary label color; your originals measured ~2.4:1 on their tints. Don't ship new 2.4:1 text; keep companion text ≥4:1 on its tint.
- **Backgrounds**: shelf `#F7F4EE` is the standard page background (your token sheet won over the white-bodied mockups). Home stays fridge `#EFEBE2`. Vent stays the dark room.
- **Hit targets**: anything interactive gets ≥48pt in build regardless of drawn size — design as you like visually; I expand invisible hit areas.
- **Type is fixed-size for now** (non-scrolling fixed-height layouts). If you design new screens to *reflow gracefully* (scrolling containers, no fixed-height pinning where avoidable), you unblock Dynamic Type later — worth doing on every new screen.
- **Navigation today**: no tab bar exists. Pushed screens float a kit-styled back chip (paper circle, ink border, hard shadow) over hidden system chrome. **Open question for you — see item 1.**

## Delivery contract

Write mockups into **`design_handoff_v2/`** in this folder, same format as round 1: `.dc.html` canvas files with inline styles, 402×874 frames, plus a README with the same structure (overview, per-screen notes, any new tokens). Your round-1 format dropped straight into my pipeline (slice → headless-render → build → pixel-audit against your frames); keep it and everything automates. If you add tokens, add them to the README token sheet — I'll mirror them into `Theme.swift`.

---

## Wave 1 — load-bearing (the app points at these and they don't exist)

1. **Navigation shell decision.** The spec says the Vent is "one tap from anywhere (long-press tab bar in v1)" — but no tab bar was ever designed. Either design the tab bar (which tabs? how does law 5 "navigation never moves" bind it?) or bless the current home-as-hub + back-chip pattern and give the Vent its global affordance some other way. This decision shapes everything else in this wave.

2. **"We ate" — dinner-done logging.** The single biggest gap: nothing in the app ever marks a dinner cooked. The whole streak/celebration economy (day counts, freeze pops earned every 7 dinners, THE RETURN) has no input. Needs: the affordance on the Tonight card and/or cook-mode end, and the calm confirmed state. This is also where celebrations actually fire.

3. **In-app cook mode.** Your Live Activity (prep ✓ chop ✓ sizzle eat, "Chad on chop duty", eats at 6:00) can only mirror an in-app session that doesn't exist. Needs: entry point (Tonight card), the step screen, duty assignment, eat-time setting, and the end state that feeds item 2. Also design the Live Activity **end/stale** states (dinner eaten ✓; abandoned mid-cook).

4. **Meal library + meal detail.** Swap, "deal me 3", and rotation freshness all presuppose a browsable meal pool with per-meal detail (photo, effort, how it's Caddie-safe, what Elsie's plain option is, per-member notes) and add/edit. Today it's a hardcoded pool of 5 and the same 3 candidates forever. The detail view is also the destination for "tap a meal" everywhere.

5. **Shopping run detail — the in-store checklist.** Run cards promise lists ("12 items") that render nowhere; "on it" is a dead button. This is the screen Ria stands in the store with: check-off, category grouping, and on completion the guarantee updates (quiet marquee moment). Include: **all-runs-done** empty state ("covered thru Friday, nothing to buy") and the **escalation** state ("for real, go shopping" — yellow + sticker, never red, always with snooze + the no-shame swap-out, which today does nothing).

6. **Day editor sheet.** Long-press promises lock; the model carries anchor, effort, assigned cook, attendance, and rest-day per day with no surface. One sheet: lock/unlock, declare rest day ("planned skip — streak intact"), assign cook, set who's home. The rest-day declaration matters for law 4 — it's how skips become guilt-free *in advance*.

7. **Settings root + household & safety editor.** No settings surface exists at all. The household editor is the serious one: Caddie's celiac constraint, Elsie's safe-foods list, cook nights — onboarding promises "adjust anytime — the week re-solves around safety." Give safety edits deliberate weight (this is medical-adjacent data, not preferences). Settings root also hangs: cast management, palette editor, always-stocked editor + fallback-meal picker, AM breakfast defaults, notifications, and the privacy surface (item 10).

8. **Day-zero / empty states.** Every round-1 mockup shows a thriving mid-week. Design the honest starting points, all under law 4 (never a zero, never shame): home with no plan yet (what's the Tonight card before there's a tonight?), streaks with no PB ("first streak in progress" is the built copy), week plan all-open, thread before anyone posts (and with a skipped/zero-persona cast), and **decide-for-me finding no solution** (solver fails → offer the always-stocked fallback warmly, never an error state).

9. **Onboarding steps 4–5 + resume.** The stressor interview and per-member meal swipe-rating (~3 min each, skippable) are named in your README but unmocked — swipe-rating is where taste data and Elsie's safe list come from. Onboarding is long; design the **interrupted/resume** state (she *will* background the app mid-flow).

10. **Notifications + permission primers.** Check-ins ("rotating formats, never same twice"), noticer notes, and escalations all arrive as notifications — none designed. Needs: lock-screen content designs (communication-notification style so Hannah/Cat/Julie appear with blob avatars), the in-voice pre-permission primer ("want the cast to actually text you?"), the denied-permission degraded mode, and the same pair (primer + denial fallback) for mic + speech recognition since voice entry is law 1. Also the **privacy/data surface**: this app stores a child's medical constraint and vent audio — export, erase-everything, kept-vent management.

11. **App icon + launch screen.** Sticker-aisle treatment; note law 6 friction — the palette is per-user but the icon is fixed, so pick icon colors that read as *the brand's* not *Ria's*. Launch screen = fridge background so cold start doesn't flash white.

## Wave 2 — important

12. **Kept-vents archive + the consent moment.** "Vents self-shred in 24h unless you keep them" — needs the keep affordance in the Vent and the archive (same quiet dark idiom, no stickers). Also the boundary moment: tapping "make tonight zero-effort" crosses from the dark room back to the sticker world and *touches the plan* — the Vent promises that only happens "if you say so," so show what saying so looks like.

13. **Cast management.** Roster screen: add/remove personas ("the cast works at any size"), rename, per-persona sass (reuse the onboarding slider), noticer-duty visibility. Today onboarding's persona choice is theater — the selection is discarded.

14. **Check-in alternate formats + voice capture overlay.** Only the one-tap tank check exists. Design the casual-text and voice check-in variants (law 5: rotate, never same twice in a row) and the universal voice-capture state (recording/confidence/cancel) that every mic in the app shares — currently only the Vent has one.

15. **Pantry/inventory + leftovers.** Belief-confidence per item "shown softly, never percentages" (your rule — design what soft looks like), leftovers with use-by, and the correction affordance ("we're actually out of tortillas") that keeps the guarantee honest. Widget **placeholder/no-plan** states belong in this wave too.

## Wave 3 — nice-to-have

16. Palette editor (slots re-pickable post-onboarding) · kid blob-avatar picker · freeze-pop earned/applied quiet states (zero animation on the miss path) · pinned-meal management ("TACO TUESDAY · pinned by you" has no pin control) · tapback interaction design · Dynamic Island compact/minimal/expanded (only the lock-screen banner was designed).

## Decisions I need (no mockups — one-line answers in your README)

- **iPad/landscape stance** — recommend: iPhone-only, portrait-locked for v1; the build already locks portrait.
- **Dynamic Type policy** — which sizes to honor once layouts reflow; what truncates vs. wraps (the Tonight card's three badges are the stress case).
- **Pinned vs. locked** — the spec has both a lock flag and "pinned by you"; same thing or two concepts?

## Not your problem (code work on my side, listed so you know the buttons will become real)

Live persona replies (thread is currently one-way), week rollover/real dates (the chip says JUL 6–12 forever), freeze-pop earn/spend mechanics, wiring the escalation swap, tapback gestures. Design their surfaces; I'll make them true.

---

*Everything above was verified against the built app — each "dead button" citation comes from the actual Swift. When your `design_handoff_v2/` lands in this folder, the build pipeline picks it up: I'll have screens in the simulator and screenshots back in `docs/screenshots/` for art direction, usually same-day.*
