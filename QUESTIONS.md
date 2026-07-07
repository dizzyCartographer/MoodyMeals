# QUESTIONS.md — parked ambiguities for Ria
Claude Code appends; Ria answers inline at morning/evening review. Answered items move to the bottom with the decision recorded (they become canon).

## Open
- [Q1] Can one meal serve both slots (breakfast-for-dinner)? Spec v0.1 says single slotKind. → blocks M0-4 final shape.
- [Q2] Model "who's home tonight" per PlanEntry in v0.1, or defer? → affects portions + Chad volume checks.
- [Q3] Liking/Fit resolution: −2…+2 enough?
- [Q4] Default "sick of this" cooldown: 6 weeks? 3 months? Ask per meal?
- [Q5] How loud may the "for real, go shopping" escalation get?

## M0-0 consistency-read findings (2026-07-07)
Full end-to-end read of requirements, build-spec, TEST_CASES, DECISIONS, DESIGN_BRIEF. Contradictions / ambiguities / decision-vs-spec drift below. The genuinely decision-needing ones are also raised in today's Decision Digest (D-32…D-36). **Nothing resolved unilaterally.**

### Blocks real work (also in digest)
- **[F1 → D-32] Stale blockers.** Q1, Q2, Q4, Q5 above are ALREADY resolved by canon: D-1 (multi-slot `slots:[SlotKind]`), D-5 (attendance via `attendees`), D-2 (`cooldownDefaultDays=42`), D-3 (`escalationMaxLevel=2`). But they're still listed "Open" here, listed as open in build-spec §7, AND listed under BACKLOG "Blocked pending Ria (build-spec §7)" as blocking M0-4. The data model in §2 already implements all four. Only **Q3** (Liking/Fit −2…+2 resolution) is genuinely still open — and even it is implemented as `Int -2…+2`. → propose: move Q1/Q2/Q4/Q5 to Answered, delete the BACKLOG blocker line, unblock M0-4.
- **[F2 → D-33] Leftover-chain data gap.** Scheduler Step 1d says "Producers write a leftover InventoryItem (kind: leftover, useBy date)"; tests LC-3 ("leftover InventoryItem, useBy = +2 days") and LC-5 ("past useBy stop satisfying requiresComponents") depend on it. But §2 `InventoryItem` has **no `kind` and no `useBy` field**. Adding fields = spec deviation (can't touch build-spec.md) → needs sign-off. Affects M0-5, M2 leftover chains.
- **[F3 → D-34] StapleItem items have no ItemSource.** PT-7 dedups "meal + staples floor + snack cadence"; SCH-13 routes Elsie's staples onto runs. But `ItemSource = {meal, snackCadence, manual, breakfastStaple}` has no `staple` case, so StapleItem-sourced ShoppingItems can't record provenance for dedup. Affects M0-5, M2-1.
- **[F4 → D-35] Elsie's needs — goal vs staples.** D-6 says StapleItems "replaces the abstract plate rule," yet `FoodNeedGoal.proteinVegStarch /* Elsie's plate rule */` is still in the enum and requirements still describe "needs protein+veg+starch." Seed data (M0-2/M0-6) needs to know whether Elsie gets the soft goal, the staples, or both.
- **[F5 → D-36] DM-4 unresolved rule.** A Precise recipe saved with a missing amount → "rejected or auto-downgraded to Loose (decision test — surfaces the rule)." TEST_CASES itself flags DM-4 (and NL-6) as decisions that reviewing = answering. Affects M0-3.

### Doc hygiene / lower priority (parked, not blocking)
- **[F6] CLAUDE.md filename drift.** CLAUDE.md's authority order and "Do not touch" list name `moody-build-spec.md` / `moody-meal-app-requirements.md`, but the repo files are `docs/build-spec.md` / `docs/requirements.md`. Standing-rule references are stale. Recommend updating CLAUDE.md to the real paths (did not edit unilaterally — it's a rules doc).
- **[F7] Novelty dial not a tunable.** SCH-9 tests a comfort↔adventurous "novelty dial" the user controls, but §8 TuningConfig only has the `wNovel` weight — no user-facing dial position key. Need a `noveltyDialPosition` (or an explicit mapping dial→wNovel). Affects M4.
- **[F8] cooldown min/max keys.** D-2 references `cooldownMinDays=42` / `cooldownMaxDays=180`, but §8 lists only `cooldownDefaultDays=42` (min/max in a parenthetical). Confirm min/max are discrete TuningConfig keys. Affects M4.
- **[F9] TEST_CASES section order.** Non-sequential: §21 (pressure-test) sits before §19g (The Vent) and §20 (Calendar); §19g trails §21. Cosmetic; no content conflict.
- **[F10] Scheduler step labels.** "Step 4a2" has no 4a/4a1. Cosmetic.
- **[F11] requirements.md open questions are stale-but-expected.** Its bottom "Open questions" (recipe naming, NL engine, lunch scope, nutrition source, Chuck sync) are already resolved by build-spec §1 + tests — north-star doc simply not back-annotated. No action needed.
- **[F12] methodAffinity key type.** `methodAffinity: [String:Int]` uses String keys documented as CookMethod (SwiftData dict constraint). Confirm intent = store `CookMethod.rawValue` strings so M0-2 encodes consistently. Low.

### M0-0b (backlog extension) — awaits approval
- **[F13] M3–M8 backlog drafted (M0-0b).** Task breakdowns for M3–M8 + a Phase 2 pointer are now in BACKLOG.md, criteria-tagged and traced to TC IDs, AI-prompt tasks marked PROMPT-REVIEW. AC requires your approval in a digest. Two structural asks: **M4 (16 tasks)** and **M5 (15 tasks)** are oversized — recommend splitting M4→M4/M4b and M5→M5/M5b/M5c. Not urgent (doesn't block M0-1); confirm at a review window.

## Answered (canon)
- (none yet)
