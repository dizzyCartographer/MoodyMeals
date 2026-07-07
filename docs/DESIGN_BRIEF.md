# Moody — Design Brief
### For a design-focused Claude session. Everything visual/interaction-relevant, extracted from the full spec.

## The mission (design against this)
*"I don't need one meal. I need all the meals, and I need them to be from me."* Moody makes an AuDHD mom-of-three who LOVES to cook harder to knock over at 4:30pm. The interface itself is an accommodation.

## Who it's for
Ria: AuDHD, skilled cook, decision-fatigued at day's end. Household of 5 incl. a celiac kid (safety badges matter), a meat-averse kid, a 14yo who needs volume. The app must feel like a warm found-family group chat wrapped around a planner — never like productivity software.

## Design laws (non-negotiable)
1. **Low activation energy everywhere.** Few taps, huge targets, voice entry on every input. The "just decide for me" action is always one tap, always prominent.
2. **Minimal cognitive load.** Small curated choice sets (~3 options), never walls of options. One question at a time. Progressive disclosure.
3. **Object permanence.** What's planned, what's on hand, what's for tonight = visible at a glance (Today card, widgets). Nothing important lives buried in menus.
4. **Never shame, never zero.** Streak UI literally may not render "0" — always "best: 23 · rebuilding: day 2." Misses get warm framing. No red badges of guilt, no overdue-task aesthetics.
5. **Novelty is load-bearing.** Visual treatments rotate (celebration styles, accent moments, imagery). Repetition = invisibility by day 4–21. BUT: navigation/layout stays stable — novelty lives in *content and celebration*, never in "where did the button go."
6. **Her palette.** Accent colors, confetti, celebratory styling sample the user's declared favorite colors (set at onboarding) — not a designer default.
7. **Warmth with sass available.** Voice register mirrors the user (tunable mild ↔ full-sass). Sass celebrates wins; never targets misses.

## Screen inventory (v1)
- **Tonight / Today card** — the hero. Tonight's meal, per-member safety badges (GF ✓ per person), swap + "just decide" + safe-fallback actions, capacity one-tap (Low/Med/High). Widget + Live Activity variants.
- **Week plan** — grid of dinner slots (+ per-person breakfast defaults shown compactly), lock toggles, theme-anchor markers (Taco Tuesday), attendance chips (who's home), assigned-cook avatar on kid cook-nights.
- **Meal library** — browse/filter by effort, method (grill/griddle/oven…), tags, per-member liking/fit; rotation-state visible (active / resting-until / retired); Signature and All-Timer badges; "sick of this" action.
- **Recipe editor** — Loose vs Precise modes; Loose = fast ingredient list, no amounts, no friction.
- **Shopping** — tiered runs (Costco / weekly / midweek) as cards with dates; consolidated list grouped by run; guarantee status ("everything covered through Friday ✓" / at-risk meals named); staples always-stocked section.
- **Inventory** — photo capture flow (person-detected → retake/crop prompt), reconciliation chat ("is that chili or sauce?"), belief-confidence shown softly (not clinical percentages), leftover items with use-by.
- **The Vent** — one tap from anywhere. Voice-first, minimal chrome, feels like a private quiet room, not a form. Reception replies are brief and warm. Visually distinct from the rest (calmer, dimmer).
- **Group thread / personas** — communication-style; cast avatars (stylized, not photoreal); lurkable — reading is enough, no reply affordance pressure.
- **Streaks** — per the never-zero law; freeze tokens visible as friendly objects; comeback state ("THE RETURN") gets the biggest visual moment in the app.
- **Reward menu & Loves corpus** — editable lists, tiered rewards, visible sources ("added by you / you agreed"), delete anywhere.
- **Check-in** — rotating formats by design: one-tap, casual text, voice. Never the same look daily.
- **Fine-tuning (settings)** — every tunable as plain-language sliders/steppers with "reset to default"; stressor patterns and cast management live here too.
- **Onboarding** — conversational: household + hard requirements (celiac safety first), favorite colors/books/shows/shops, stressor interview, 2-real+2-fictional persona cast co-creation, per-member meal swipe-rating (love/fine/nope, ~3 min each, skippable).

## Signature moments to design
- The **comeback celebration** (biggest moment in the app).
- A **persona message** arriving (sender avatar + name, feels like a text from a person).
- The **"for real, go shopping" escalation** (urgent but never guilt-styled) and its snooze.
- **Joy-cooking invitation** ("clear Saturday, clean kitchen — cook for real?").
- A **guarantee-satisfied** state: quiet confidence, not a gold star.

## Explicitly avoid
Productivity-app aesthetics (red overdue badges, progress-guilt), gamification that punishes, clinical/medical vibes, dense dashboards, photoreal personas, any UI where a miss looks like failure.

## Deliverables wanted from the design session
1. Design language: tokens (type, spacing, color system that accepts a user palette), component patterns.
2. Mockups of: Tonight card, Week plan, Shopping, Streaks, Vent, one persona/group-thread message, onboarding cast co-creation.
3. Widget + Live Activity concepts.
4. Motion/celebration direction (novelty-friendly: a family of styles, not one).
