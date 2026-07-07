# QUESTIONS.md — parked ambiguities for Ria
Claude Code appends; Ria answers inline at morning/evening review. Answered items move to the bottom with the decision recorded (they become canon).

## Open
- [Q3] Liking/Fit resolution: −2…+2 enough? *(non-blocking — implemented as Int −2…+2 per spec §2 unless Ria wants finer)*
- [Q6/D-34] Add `staple` to ItemSource for StapleItem-sourced shopping items? Ria asked for the existing source list (2026-07-07); answered in chat, awaiting confirm.
- [Q7/D-35] Elsie seed profile: staples-only, or staples + `proteinVegStarch` soft goal? Re-explained 2026-07-07, awaiting answer.
- [Q8/D-36] Precise recipe saved with a missing amount: reject, downgrade to Loose, or allow mixed? Re-explained with example 2026-07-07, awaiting answer.

## M0-0 consistency-read findings (2026-07-07)
Full end-to-end read of requirements, build-spec, TEST_CASES, DECISIONS, DESIGN_BRIEF. Contradictions / ambiguities / decision-vs-spec drift below. The genuinely decision-needing ones are also raised in today's Decision Digest (D-32…D-36). **Nothing resolved unilaterally.**

### Blocks real work (also in digest)
- **[F1 → D-32] ✅ RESOLVED 2026-07-07 (Ria: yes).** Q1/Q2/Q4/Q5 moved to Answered below; BACKLOG blocker line removed; M0-4 unblocked. Build-spec §7 still lists them (protected doc — left as-is; canon outranks it per authority order).
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
- **[Q1] (2026-07-07, via D-32/D-1):** Multi-slot YES — `slots: [SlotKind]` array + `requiresCalmDay` gate. Breakfast-for-dinner is real; Wednesday anchor seeded off.
- **[Q2] (2026-07-07, via D-32/D-5):** Attendance modeled in v0.1 — `attendees` on PlanEntry; hard constraints apply to attendees only; Chad appetite multipliers.
- **[Q4] (2026-07-07, via D-32/D-2):** Cooldown default 42 days (min 42 / max 180), per-meal override in range.
- **[Q5] (2026-07-07, via D-32/D-3):** Escalation may genuinely yell (level 2, novelty-rotated) AND is snoozable ≤7 days; auto-returns; never mutes §1 safety.
