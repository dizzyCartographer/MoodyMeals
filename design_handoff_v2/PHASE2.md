# PHASE2.md — designs for everything HANDOFF.md listed as not-built-yet

Same system, same laws, same tokens as README.md (§Design Tokens). Mockups: `Moody Phase 2.dc.html` (open in browser) · PNGs: `screenshots/11–19`. Cast is correct throughout: Caddie (celiac/GF), Elsie (safe foods), Chad (×2), Chuck; personas Hannah / Cat / Julie. All screens use `shelf #F7F4EE` background, ink borders, ≥48pt targets, max one sticker.

Also in this folder: `DESIGN_REVIEW.md` — fixes for the existing build (do those first; they're small).

## 11 · Onboarding step 4 — stressor interview (5a)
One question per screen, 3 curated answer cards + a voice "something else — just say it" pill (purple slot = voice, app-wide convention). Selected card = yellow tint + ink shadow. CTA "THAT'S THE ONE"; skip line notes Fine-tuning holds these later. Answers write stressor patterns (see screen 17). *[Merge note, per D-43 (2026-07-09): patterns are context for one-tap flexibility offers, never scheduler inputs — the app never preemptively rewrites a plan. Screen survives; the "feed the scheduler" framing is retired.]* Never more than one question visible.

## 12 · Onboarding step 5 — per-member swipe rating (5b)
Header = member blob + "CADDIE'S TAKES · CARD 12" + "~3 min · skippable". One meal card (photo, title, per-member relevant chips — for Caddie every card shows its GF status). Tap or swipe: nope / fine / LOVE ♥ (love = pink primary, largest). Sticker "12 ♥ SO FAR" on the card. Footer: next member up. *[Merge note, per D-42 (2026-07-09): Elsie has no safe-foods rule — her deck draws like everyone's; likings + the fairness floor carry her dinners.]* Writes `MemberMealScore.liking`. Copy law: "ratings feed the picker, never a report card."

## 13 · Meal library (5c)
Filter chips (safety filter first, selected = green tint + shadow; effort as dot scale ≤ ●●○○ matching the 4-level EffortLevel; method; rotation). Row states: active (green dot), ALL-TIMER sticker (fatigue-exempt), SIGNATURE ink chip, resting = blue tint card with "resting until <date> — comes back on its own", retired = dashed ghost with one-tap resurrect. Expanded row: per-member liking chips (blob + ♥/ok/×2) and two actions — "sick of this → rest it" (sets cooldown) and "pin to a day". Footer states the rotation philosophy: resting ≠ gone. *[Merge note, per D-46 (2026-07-09): library rows gain a second chip axis — per-person ✅/❌ "serves" alongside ❤️ — plus "serves X" / "loved by X" filters; revise at next design pass. Edge-state chip treatment is reserved for visual review.]*

## 14 · Recipe editor — Loose mode (5d)
Loose | precise segmented control, LOOSE default (yellow selected). Loose = ingredient name chips only, each with ✕, plus "+ add" and a voice mic. No amounts, no steps, no validation. Purple note card: "amounts live in your head. that's allowed." Behavior toggles as chips: "needs a calm day", leftover-chain card ("makes extra: shredded beef → feeds Chad's ramen within 3 days"). CTA: "SAVE — DONE ENOUGH". Precise mode (not mocked) adds amounts/steps in the same visual language; never required.

## 15 · Inventory (5e)
Top: photo-capture dropzone (dashed border, camera glyph) with the person-detection reassurance line ("auto-cropped, asked before keeping ✓"). RECONCILIATION: one chat bubble at a time (paper, ink border, blue shadow) — "red container, shelf 2 — chili or enchilada sauce?" with 3 answer chips (incl. a no-shame "no idea — toss it"). LEFTOVERS: rows with use-by chips (yellow when ≤2 days), leftover-chain chip (green, "feeds Wed ramen"), belief shown as words ("solid — saw them this morning" / "pretty sure" / "honestly guessing") — footer law: "confidence is a vibe here, never a percentage."

## 16 · Check-in — format roulette (5f)
Sticker announces tonight's format ("FORMAT: ONE TAP"). Card asks one question ("dinner happened?") with 3 answers: cooked ✓ (green, selected style), "fed, didn't cook — still counts" (white), "rest day" (blue). Below, dashed preview chips of other formats (two words / voice note / picture of the plate / Hannah asks) — communicates the rotation without adding choices. Formats never repeat two days running. "Fed, didn't cook" counts toward the streak; nothing here can render a miss.

## 17 · Fine-tuning (5g)
Every tunable = plain-language card with a per-card "reset" ghost (no global settings archaeology): cast chattiness slider (MILD↔FULL CHAOS), repeat-spacing stepper ("12 days"), shopping-nag patience slider (GENTLE↔FOR-REAL FASTER — this drives screen 19's timing). Cast management row (3 persona blobs → voices/duties/retirement). Stressor patterns as editable chips (fed by screen 11, "+ add" anytime; per D-43 they inform flexibility offers, never automatic behavior). All values map to TuningConfig-style named defaults.

## 18 · Reward menu + Loves corpus (5h)
Three tier cards — SMALL/weekly-ish, MEDIUM/streak weeks, BIG/THE RETURN (pink tint + pink shadow, the only emphasized tier). Every entry carries a source chip: "added by you" / "you agreed" — provenance always visible. LOVES CORPUS: chips with ✕ delete-anywhere, "+ add" + voice. Bottom card demos usage: personas quote entries verbatim ("the bookstore hour is EARNED. go." — Hannah); they never invent rewards.

## 19 · "For real, go shopping" escalation (5i)
Yellow-tint card + "FOR REAL THIS TIME" sticker (yellow = the app's ceiling for urgency; red does not exist). Headline states stakes as math ("3 dinners now ride on tonight's run"), body names the meals and pre-counts the list ("9 things, one store"). Three outs, always: "going — show me the list" (ink primary), "snooze to 5:00", "can't today — re-plan around the pantry" (green tint — adaptation is a first-class answer, not a failure path). Info card explains the quiet re-solve if snoozed past 6. Footer re-states the staples guarantee. Notification variant uses the same copy with the same three actions.

## Build order suggestion
17 → 13 → 14 → 15 → 11/12 → 16 → 18 → 19 (fine-tuning first exposes the dials the rest read; escalation last since it depends on run-routing timing).
