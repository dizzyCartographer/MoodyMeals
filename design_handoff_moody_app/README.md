# Handoff: Moody — "The Fridge" home + design system

## Overview
Moody is a meal-planning app for an AuDHD mom of three (Ria) who loves to cook but is decision-fatigued by 4:30pm. The interface is itself an accommodation: low activation energy, tiny curated choice sets, object permanence (tonight's plan always visible), and a warm found-family group chat wrapped around the planner. It must never feel like productivity software.

The chosen direction is **"Fridge Door"**: the home screen is a fridge door — the Tonight card is pinned under a magnet, cast members leave sticky notes, the week is a row of magnets, and a 3-option energy check ("tank check") sits at the bottom. Visual language: **"Sticker Aisle"** — Target-shelf polish with candy pastels, thick ink outlines, hard offset shadows, slight sticker tilts.

## About the Design Files
The files in this bundle are **design references created in HTML** — prototypes showing intended look and behavior, not production code to ship. The task is to **recreate these designs in the target codebase's environment** (SwiftUI is the natural fit — the mockups are iPhone-framed and the spec includes iOS widgets + Live Activities — but use whatever the codebase already uses). If no codebase exists yet, pick the most appropriate stack for a native-feeling iOS app.

- `Fridge Door.dc.html` — **the chosen home screen** (authoritative, correct cast).
- `Moody Explorations.dc.html` — the full exploration canvas. Turn 3 option **3d** is the chosen home. Turn 2 (options 2a–2i) is the **system build-out**: tokens sheet, week plan, shopping, streaks, vent, persona thread, onboarding, widgets, motion. Turn 4 shows softer-pastel variants (rejected as a whole, but 4a–4c persona-note cards are good reference for Hannah/Cat/Julie voice).
- `ios-frame.jsx`, `support.js` — scaffolding so the HTML files open in a browser. Ignore for implementation.

⚠️ **Cast names**: Turns 1–3 of the exploration canvas were built with placeholder names (Juno/Milo/Tas/Dev, personas Peach/Grandma Greens/Mr. Kettle). The **authoritative cast is below**. `Fridge Door.dc.html` and turn 4 use the correct names.

## Fidelity
**High-fidelity.** Colors, type, spacing, radii, shadows, and copy voice are intentional — recreate pixel-perfectly (adapting pt/dp as needed). The exploration screens for week plan / shopping / streaks / vent / thread / onboarding are hi-fi in style but carry placeholder cast names (see above) and placeholder photos.

## The Cast (authoritative)
Household:
- **Ria** — mom, AuDHD, skilled cook, decision-fatigued at day's end. The user.
- **Chuck** — partner.
- **Caddie** — celiac. **Safety-critical**: every planned meal shows a per-meal "Caddie GF ✓" badge. This is a guarantee, not a preference.
- **Elsie** — food-averse (limited safe-foods list). Badge shows her safe option exists for tonight, e.g. "Elsie plain ✓".
- **Chad** — 14yo, needs volume. Badge "Chad ×2 ✓" = double batch planned. Has a weekly cook-night (Wed ramen in mockups).

Personas (fictional cast members who text like real people — stylized avatars, never photoreal):
- **Hannah** — snarky best friend, perfectly organized, knows exactly how messy life gets. Alternates with Cat as "the noticer" (spots a slump, nudges warmly).
- **Cat** — professional chef Ria "met at her sister's 40th"; no kids of her own, world's best aunt energy; drops chef technique tips. The other noticer.
- **Julie** — neurodivergent, whip-smart; might forget to cook 4 days running but knows sourdough technique and nutrition research. Notices *comebacks* fast — drops a meme, a relatable one-liner, or an ND reality-reminder ("task re-initiation costs more dopamine than the task"). Keeps the chat calibrated to Ria's and the kids' neurotypes. Never lectures.

Voice register is tunable mild ↔ full-sass (default ~6/10). Sass celebrates wins; **never targets misses**.

## Design Laws (product requirements, not suggestions)
1. **Low activation energy** — few taps, huge targets (≥48pt), voice entry on every input. "Decide for me" is always one tap and always the most prominent action.
2. **Minimal cognitive load** — ~3 options per choice, one question at a time, progressive disclosure.
3. **Object permanence** — tonight's meal, safety badges, grocery status always visible at a glance (home, widgets, Live Activity).
4. **Never shame, never zero** — streak UI may never render "0". Always "best 23 · day 2 of the rebuild" framing. Planned skips are "rest days," not misses. No red badges, no overdue aesthetics. Misses get zero animation — calm is the response.
5. **Novelty is load-bearing** — celebration styles, accent moments, check-in formats rotate (never same twice in a row). Navigation/layout NEVER moves.
6. **Her palette** — the 5 accent slots are filled from the user's declared favorite colors at onboarding. Confetti, tapbacks, magnets, shadows sample these slots. The values below are Ria's demo palette, not constants.
7. **Warmth with sass** — see cast voice.

## Design Tokens

### Color — fixed core
- `ink` #2A2440 — all outlines, primary text, hard shadows on emphasis elements
- `paper` #FFFFFF — cards
- `shelf` #F7F4EE — app background on standard screens
- `fridge` #EFEBE2 — home-screen background (the fridge door)
- `text-secondary` #8A84A0 · `text-disabled/dashed` #B3AECB
- sticky-note shadow: rgba(42,36,64,.12–.14)

### Color — user palette slots (Ria's demo values)
| slot | value | tint (≈82% toward white) | dark label text |
|---|---|---|---|
| her-1 pink | #FF7BAC | #FFE3EE / #FDE7F0 | #D46A92 / #B04A72 |
| her-2 green | #8CC63E | #E9F5D3 | #5F7F28 / #6B8A2E |
| her-3 yellow | #FFD34E | #FFF4CE / #FFF6D8 | #8A6D1E / #B3A075 |
| her-4 blue | #5BC2E7 | #E1F1FA | #3E7A96 |
| her-5 purple | #9B7EDE | #EFE8FA | #8E77B8 |

Rules: slots accept any 3–5 user colors. Tint = color mixed ~82% toward paper. Safety badges always sit on a tint with the matching dark label. Rotate which slot accents headers/celebrations day-to-day (novelty law).

### Type
- Display / card titles: **Baloo 2** 600–800 — 38/30/26 (page titles), 24/22 (card titles), 19 (sticky headline)
- Body / UI: **Nunito** — 700 body 14–15, 800 secondary 11.5–13, 900 labels 10.5–12 with letter-spacing .06–.12em, CAPS for section labels
- Never below 10.5px (mobile); hit targets ≥48pt.

### Space & shape
- Spacing scale: 4 / 8 / 12 / 20
- Radii: card 20–22 · pill/chip/button 999 · sticker/magnet 10 · sticky note 6 · tank segment 16 · widget 34
- Borders: 2px ink on interactive/emphasis elements; 2px dashed #B3AECB for empty slots
- Shadows: hard offset, zero blur. Emphasis: `3px 3px 0 ink` (buttons), `4–5px 5px 0 <palette slot>` (feature cards). Passive depth: `3-5px 4-5px 0 rgba(42,36,64,.12-.14)`.
- Tilt: decorative elements only (stickers, sticky notes, magnets) ±0.5–3°. Never tilt buttons, nav, or text blocks.
- Sticker chip: yellow tint bg, 2px ink border, r10, rotate ±2–3°, shadow `2-3px 2-3px 0 <slot>`. **Max one sticker moment per screen.**

## Screens

### 1. The Fridge (home) — `Fridge Door.dc.html`
Layout top→bottom (fridge bg #EFEBE2):
- **Header**: "The Fridge" (Baloo 2 26/800) left; 3 small magnet dots right (14px circles, ink border, palette fills) — purely decorative.
- **Tonight card** (paper, 2px ink, r20, shadow 5px 5px 0 rgba(ink,.12), rotate −0.5°, pink magnet dot 18px centered on top edge): label "TONIGHT · TACO TUESDAY" (10.5/900, letter-spacing .1em, #D46A92, centered) → meal name (Baloo 2 24/800, centered) → 3 safety badges centered ("Caddie GF ✓" on green tint, "Elsie plain ✓" on blue tint, "Chad ×2 ✓" on yellow tint) → actions grid 1.5fr/1fr: **DECIDE FOR ME** (pink #FF7BAC, ink border, r999, Baloo 2 14.5/800, shadow 3px 3px 0 ink) + "swap" (white, ink border).
- **Two sticky notes**, 2-col grid: (a) yellow-tint note, rotate +1.4°, blue magnet top-left: "HANNAH LEFT A NOTE" + quote + "+2 more · open thread →" — tap opens the thread. Note author rotates between Hannah/Cat/Julie (noticer duty). (b) pink-tint note, rotate −1.2°, green magnet top-right: "STREAK PATCH", "day 2 🧲" (Baloo 2 19/800), "PB 23 · the rebuild". Never renders 0 (law 4).
- **Week magnets**: label "WEEK MAGNETS" + wrapping row of 7 magnet chips (r10, ink border, ±1.5° tilts): done days get ✓, tonight is yellow w/ ink shadow (current), kid cook-night green ("Wed: CHAD 🍜"), joy-cook pink ("Sat: JOY 🍲"), open day dashed ("Sun ?"). Tap → Week plan.
- **Tank check** (pinned to bottom): 3 equal segments Fumes/Steady/Full (r16, ink border; selected = yellow + 3px ink shadow). One tap re-plans tonight's effort level.
- **Footer line**: "groceries covered thru Friday ✓" (11.5/800 #8A84A0) — the guarantee, quiet.

### 2. Week plan (exploration 2b)
List of 7 day rows (ink-border r16 cards): day label, meal name 14.5/900, meta line 11.5/800 (effort dots ●○○, attendance). Tonight row = yellow tint + yellow hard shadow + "ANCHOR" sticker (ink bg). Kid cook-night row shows blob avatar chip "CHAD COOKS". Saturday joy-cook row = pink tint + "JOY" sticker. Open day = dashed border + "deal me 3" yellow pill (deals exactly 3 candidates, law 2). Compact AM strip above list shows per-person breakfast defaults. Footer hint: "tap any day to swap · long-press to lock."

### 3. Shopping (exploration 2c)
Top: guarantee banner (green tint, ink border, green hard shadow): "Every dinner covered through Friday ✓" + at-risk note ("Sat's birria depends on the Costco run"). Then tiered run cards: **Tonight top-up** (yellow tint, "2 ITEMS" sticker, names the meals it protects, two actions: "on it" (ink pill) / "can't — swap Thu to GF mac" — every escalation carries a no-shame out); **Wednesday weekly** (12 items, category count chips on tints); **Saturday Costco** (bulk + project). Bottom: **ALWAYS STOCKED** shelf (staples as outlined chips, "oat milk — low"); note: "the fallback meal can ALWAYS be cooked from this shelf."

### 4. Streaks (exploration 2d)
Hero card (pink tint, pink hard shadow, "PB: 23" sticker): "DINNERS FROM HOME" / "day 2" (Baloo 2 44/800) / "of the rebuild" / "not starting over — picking back up. there's a difference." Week strip: 7 day tiles — done days filled with palette colors + ✓, planned rest day = blue tint labeled "rest day", future = "tbd"/dashed. Caption: "Wednesday was a rest day, not a miss. the math agrees: streak intact." **Freeze pops** card (blue tint): 2 popsicle icons, "auto-protects a wild day. you earn one every 7 dinners. no confessions required." **THE RETURN** card (ink bg, white text): "INBOUND / THE RETURN — 1 dinner away" + tri-color progress bar + "cook tonight and this app throws you a parade. no pressure. (some pressure.)"

### 5. The Vent (exploration 2e)
The one screen where the system goes quiet: dark dim room (radial #2C2540→#181425), no ink outlines, no stickers, no tilt, single purple accent. "say it ugly. nobody's grading." Big glowing mic button (112px halo), live waveform bars, RECEPTION reply card (brief, warm: "heard. that was a lot of day for one person."), two pills: "make tonight zero-effort" / "that's all. just needed out." Footer: "vents self-shred in 24h unless you keep them · nothing here touches your plan unless you say so." Reachable in one tap from anywhere (long-press tab bar in v1 spec).

### 6. Group thread (exploration 2f, voices per cast above)
iMessage-adjacent: left-aligned persona bubbles with blob avatar + name label + colored name; paper bubbles with ink border + hard shadow for the "moment" message; tint bubbles for asides; tapback chips (♥ 2, ★ Chuck). Quick-reply pills right-aligned. Real family members and personas coexist. Footer: "lurking counts as participating ✓"; composer placeholder "reply if you feel like it" + voice button. No unread-count pressure, no reply nagging.

### 7. Onboarding — cast co-creation (exploration 2g)
One question per screen, progress dots top-right. "Now: someone imaginary." Persona candidate cards (blob avatar, name + role, sample line in their voice); selected card = pink tint + pink hard shadow + ✓. Name field with voice input. Sass slider MILD ↔ FULL CHAOS (yellow fill, chunky ink-border thumb). Primary: "ADD HANNAH TO THE CAST"; skip line: "or skip — the cast works at any size." Also in onboarding flow (not mocked): household + hard requirements (celiac safety FIRST), favorite colors (fills palette slots), stressor interview, per-member meal swipe-rating (~3 min each, skippable).

### 8. Widgets + Live Activity (exploration 2h)
- **Small**: TONIGHT label + status dot, meal name (Baloo 2 19), badge summary line "GF ✓ · plain ✓ · ×2 ✓", one action pill "decide for me".
- **Medium**: adds full named badges, "covered thru FRI ✓", and 3 actions: decide for me (pink) / fumes / steady.
- **Live Activity** (cook mode, dark #17131F): persona avatar, "Taco night · eats at 6:00", sub-line "Chad on chop duty ✓ · tortillas warming", countdown (yellow Baloo 2), 4-segment step bar (prep ✓ chop ✓ sizzle eat) with palette fills.
- **Dynamic Island**: green status dot + eat time. Message: dinner exists, it's handled.

### 9. Motion — celebration family (exploration 2i, live animations in file)
Four styles, app picks per win, never repeats twice in a row, colors always from her slots:
1. **Confetti pop** — everyday win; small squares/dots fall ~1.4–2s, staggered.
2. **Sticker slap** — milestones; badge scales 0→1.18→0.95→1 with rotate −14°→+4°→−3°, cubic-bezier(.2,1.4,.4,1) ~600ms.
3. **Marquee** — guarantee satisfied; corner dots chase softly. Quiet confidence, no fanfare.
4. **Blob party** — THE RETURN only: full-screen ink takeover, cast blobs bounce (staggered 150ms), then all styles stack + cast pile-on in the thread. Biggest moment in the app, reserved for comebacks.
Misses/skips: **zero motion**. Standard transitions: ≤250ms ease-out; respect Reduce Motion (fall back to gentle opacity).

## Interactions & Behavior
- **Decide for me**: one tap → instantly commits a meal (constraint-solved: safety first, then attendance, effort ≤ tank, rotation freshness). No confirmation modal; undo via "swap".
- **Swap**: presents exactly 3 alternatives (law 2).
- **Tank check**: Fumes re-plans tonight to lowest-effort/fallback; answers persist and tune the week.
- **Fallback**: always cookable from ALWAYS-STOCKED staples; offered prominently on Fumes.
- **Noticer duty**: Hannah/Cat alternate slump-noticing; Julie owns comeback-noticing. Notes surface on the home sticky, full message in thread.
- **Shopping escalation** ("for real, go shopping"): urgent styling = yellow tint + sticker, never red/guilt; always paired with a snooze and an adaptation path ("can't — swap Thu").
- **Streak math**: planned skips = rest days (streak intact); unplanned miss → freeze pop auto-applies if available; otherwise counter reframes to "best N · rebuilding: day M". The string "0" must be unreachable.
- **Check-in**: rotating formats (one-tap / casual text / voice), never the same look on consecutive days.
- **Novelty engine**: rotates accent slot, celebration style, check-in format, persona voice cadence. Never moves navigation or renames actions.

## State Management (sketch)
- `household[]`: members with dietary constraints (celiac = hard constraint), aversions/safe-foods, volume needs, attendance calendar, cook-nights.
- `personas[]`: name, voice profile, sass level, noticer-rotation state.
- `plan{}`: per-day slot → meal, lock flag, anchor flag, effort, assigned cook; per-meal derived safety-badge results.
- `pantry/inventory`: belief-confidence per item (shown softly, never percentages); leftovers with use-by.
- `runs[]`: tiered shopping runs; `guarantee`: computed "covered through X" from plan × inventory × runs.
- `streak{}`: current, personalBest, freezeTokens, state (active/rebuilding/return-pending). UI derives strings that never render 0.
- `tank`: today's energy answer; `ventSessions` (ephemeral, 24h TTL).

## Assets
- Fonts: Baloo 2 + Nunito (Google Fonts; both available on iOS via bundling).
- Food photos: mockups use striped placeholders labeled "photo: …" — replace with real photography (warm, homey, never stocky).
- Avatars: pure code — blob shapes (irregular border-radius), 2px ink border, dot eyes + small smile; kids pick their blob shape/color. No image assets, never photoreal.
- No icon font; the few glyphs are text (✓, ×2, 🧲, 🍜, 🍲) — replace emoji with drawn icons at implementation if preferred.

## Files
- `Fridge Door.dc.html` — chosen home screen, correct cast (open in browser)
- `Moody Explorations.dc.html` — full canvas: tokens (2a), week plan (2b), shopping (2c), streaks (2d), vent (2e), thread (2f), onboarding (2g), widgets (2h), motion (2i); chosen home = 3d; pastel variants (turn 4)
- `ios-frame.jsx`, `support.js` — browser scaffolding only, not part of the design
