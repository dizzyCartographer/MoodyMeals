# BACKLOG.md — Moody build queue
Work top-down. Format: `[ID] (est) Task — Acceptance criteria`. Statuses: `TODO / IN-PROGRESS / DONE / BLOCKED(Q#) / NEEDS-VISUAL-REVIEW`.

## M0 — Skeleton
- [M0-0] **[DONE 2026-07-07]** (90m) Consistency read — read ALL docs end-to-end (requirements, build-spec, TEST_CASES, DECISIONS); log every contradiction, ambiguity, or decision-vs-spec drift to QUESTIONS.md; propose fixes in the first Decision Digest. Do NOT resolve unilaterally. **AC:** a written findings list (even if empty) in RUNLOG before any code. → findings F1–F12 in QUESTIONS.md; digest D-32…D-36.
- [M0-0b] **[DONE 2026-07-07 — awaits digest approval]** (45m) Extend this backlog — draft task breakdowns for M3–M8 at the same criteria-tagged granularity as M0–M2; mark AI-prompt tasks as review-gated. **AC:** backlog covers all milestones; Ria approves in a digest. → drafted below (M3–M8 + Phase 2 pointer); M4/M5 flagged oversized (split candidates). Approval parked in QUESTIONS (F13).
- [M0-1] **[DONE 2026-07-07]** (60m) Xcode project scaffold — SwiftUI app target, SwiftData container, test target builds and runs an empty test. **AC:** `xcodebuild test` green in simulator. → 2/2 passing, iPhone 17 Pro sim (iOS 26.5).
- [M0-2] **[DONE 2026-07-07]** (90m) Core models, people — `FamilyMember`, `DietaryRequirement`, `FoodNeedGoal`, `MemberMealScore` per spec §2. **AC:** round-trip persistence tests; TC §1 model-level invariants compile. → 8 tests, fresh-context decode verified; adversarial review applied (F14/F15 parked).
- [M0-3] **[DONE 2026-07-07]** (90m) Core models, food — `Ingredient`, `Recipe`, `RecipeKind`, `RecipeItem` incl. tri-state `isGlutenFreeVerified`. **AC:** loose recipe with nil amounts persists; TC-HC-6 passes. → 12 tests incl. HC-6 both paths + D-36 mixed precision; safety review applied (F16/F16b conservative defaults pinned).
- [M0-4] (90m) Core models, meals & planning — `Meal`, `PlanEntry`, `ThemeAnchor`, enums. **AC:** meal with zero recipes + freeform text is valid (TC-DM-3).
- [M0-5] (60m) Core models, shopping/inventory/etc — `ShoppingRun/Item`, `Snack`, `PurchaseRecord`, `InventoryItem`, `WasteEvent`, `CheckIn`, `WeeklyReflection`, `FridgeSpec`. **AC:** persistence tests for each.
- [M0-6] (45m) Seed data — the five household members with hard requirements/soft goals per requirements doc; ~15 seed meals incl. GF-verified and unverified items, one all-time favorite, one Taco-Tuesday-tagged meal. **AC:** seed loads idempotently; used by all later tests.
- [M0-7] (90m) Basic CRUD screens for meals/recipes (list + edit). **AC:** builds, creates/edits persist. NEEDS-VISUAL-REVIEW.

## M1 — Plan + see
- [M1-1] (90m) Manual planning UI — week grid, assign meal to date+slot, lock toggle. **AC:** PlanEntry created/edited; lock persists. NEEDS-VISUAL-REVIEW.
- [M1-2] (90m) EventKit service — dedicated "Moody" calendar; create/update/delete events from PlanEntries; handle permission denial gracefully. **AC:** TC-CAL-1..4 (integration tests may be simulator-limited; document what's mockable).
- [M1-3] (60m) Tonight view — today's dinner, swap button, per-member safe badge. **AC:** TC-SF-1..3. NEEDS-VISUAL-REVIEW.

## M2 — Shopping core
- [M2-1] (90m) Meal→items explosion — precise amounts summed, loose items listed without amounts, dedup. **AC:** TC-SL-1..5.
- [M2-2] (90m) Run tiers + routing — perishability/neededBy routing per spec §4 step 4. **AC:** TC-RT-1..6.
- [M2-3] (90m) Guarantee check v1 (no inventory) — coverage between now and next confirmed run; violation → structured result naming at-risk meals. **AC:** TC-GT-1..6.
- [M2-4] (60m) Markdown + Reminders export of a run's list. **AC:** TC-SL-6; Reminders export behind permission check.
- [M2-5] (45m) Run skip/delay flow — recheck guarantee, produce at-risk report object (UI later). **AC:** TC-GT-7..8.

## M3 — Brain, part 1 (Claude NL capture) — [M0-0b draft, awaits digest approval]
*Tags: PROMPT-REVIEW = AI-prompt/tone task, review-gated (do not tune autonomously). NEEDS-VISUAL-REVIEW = UI.*
- [M3-1] (90m) `MoodyBrain` service layer — thin Claude tool-use client, keys from env, "what leaves the device" payload-category log, offline/failure queueing. **AC:** NL-7, NL-8; no secrets committed. PROMPT-REVIEW.
- [M3-2] (90m) Brain-dump → recipe (`createRecipe`) — parse messy text into Loose/Precise; gluten defaults unverified. **AC:** NL-3, HC-7. PROMPT-REVIEW.
- [M3-3] (90m) Log-by-talking + compound feedback (`logMealFeedback`) — one utterance → status + per-member liking + recency + frequency delta. **AC:** NL-1, NL-2. PROMPT-REVIEW.
- [M3-4] (60m) Meal query (`queryMeals`) — NL queries, no writes. **AC:** NL-5.
- [M3-5] (45m) Ambiguity guard — write-intent with no target asks; never guesses. **AC:** NL-6.
- [M3-6] (60m) Daily check-in (one-tap) — CheckIn wired, capacity Low/Med/High, skip = signal. **AC:** RM-1 (part), RM-5 groundwork. NEEDS-VISUAL-REVIEW.
- [M3-7] (60m) Capacity-aware Tonight + "just decide" — ~3 filtered picks + one-tap decide. **AC:** RM-1. NEEDS-VISUAL-REVIEW.
- [M3-8] (90m) Loves Corpus foundation — LoveItem model, editable page, conversational-capture offer, consented-observation stub, source visibility. **AC:** LOV-2, LOV-3, LOV-4. PROMPT-REVIEW + NEEDS-VISUAL-REVIEW.
- [M3-9] (60m) Stressor profile — StressorPattern model, calendar-signal matching, editable page. **AC:** STRS-5 (adaptation wiring lands M4/M5). NEEDS-VISUAL-REVIEW.
- [M3-10] (45m) Onboarding conversational seed — corpus + stressors + favorite colors; skippable/resumable. **AC:** LOV-7 palette captured. PROMPT-REVIEW + NEEDS-VISUAL-REVIEW.

## M4 — Scheduler v1 — [M0-0b draft]
*Note: M4 is large (16 tasks) — candidate to split (M4 core / M4b guardrails+chains). Flagged for Ria.*
- [M4-1] (90m) `TuningConfig` singleton + Fine-tuning settings — all §8 keys w/ defaults, plain-language sliders, reset-to-default; tests read config not literals. Adds keys per D-33/D-34/F7/F8 **if approved**. **AC:** every §8 tunable present. NEEDS-VISUAL-REVIEW.
- [M4-2] (90m) Hard filter (Step 1/1c) — exclude hard-req violations vs attendees, non-active rotation, notToday; GF verified-rule; all-timers exempt. **AC:** HC-1, HC-2, HC-3, SCH-14, ATF-2.
- [M4-3] (90m) Scoring engine (Step 3) — weighted score(m,d) from TuningConfig weights. **AC:** SCH-1, SCH-2, SCH-3, SCH-4.
- [M4-4] (60m) Method affinity (D-28) — per-cook affinity; loved method NEVER nannied. **AC:** MTH-1, MTH-2 ⚠️, MTH-3.
- [M4-5] (90m) Anchors (Step 2) — ThemeAnchor fill + variety rotation. **AC:** ANC-1..4.
- [M4-6] (90m) Cooldown & rotation (Step 5) — "sick of this" → resting + refill; auto-return; retired stays out. **AC:** CD-1..5, ATF-1.
- [M4-7] (60m) Frequency + recency + locks (Step 4) — no repeat in recency window; frequency pressure; locks immovable. **AC:** SCH-5, SCH-8.
- [M4-8] (90m) Fit-coverage guardrails (Step 4) — iron ≥`ironCoveragePerWeek`, calorie-dense ≥`calorieDense…`; patch lowest-margin; warnings. **AC:** SCH-10, SCH-11.
- [M4-9] (90m) Leftover chains (Step 1d/4a2) — requiresComponents placement, pull-in producer, leftover InventoryItem+useBy, busy-night bonus. **AC:** LC-1..5, SCH-17, PT-10. *(depends on D-33)*
- [M4-10] (60m) Fairness floor (Step 4d) — `dislikeFloorPerWeek`, no consecutive −2. **AC:** PT-2. *(D-17 default)*
- [M4-11] (60m) Cook nights + servings (Step 4c) — kid anchors, likesToCook, portions = Σ appetiteBase + favorite boost. **AC:** SCH-15, SCH-16.
- [M4-12] (60m) Cold-start reduced mode (Step 4f) — frequency+effort+hard only until signal; labeled; onboarding swipe pass. **AC:** PT-1.
- [M4-13] (60m) Calm-day gate + calendar conditions (Step 1b/4b) — requiresCalmDay eligibility; user-editable signal→rule maps; Wednesday b4d anchor seeded OFF. **AC:** SCH-6 + condition-gate tests.
- [M4-14] (60m) Reactivity + 12-month horizon — re-score today+tomorrow only; horizon gen; near-term syncs; novelty dial. **AC:** SCH-7, SCH-9 *(needs F7)*, SCH-12.
- [M4-15] (45m) Signature floor (4g) + joy-cooking invite (4h) — memory reps; invitation register. **AC:** ATF-5, ATF-6, ATF-7. PROMPT-REVIEW (invite copy).
- [M4-16] (60m) Stressor adaptation + cook-night collision (4e) — severity holds/yields; preemptive effort caps. **AC:** STRS-1..3, PT-9. *(D-18 default)*

## M5 — Notifications & the generative EQ engine — [M0-0b draft]
*Note: M5 is very large (15 tasks) — genuinely 2–3 milestones. Recommend split (M5 infra+reminders / M5b personas+envelope / M5c streaks+rewards+vent). Flagged for Ria. Nearly all tasks PROMPT-REVIEW.*
- [M5-1] (90m) Notification infra — UNUserNotificationCenter scheduling, persisted history (survives relaunch), quiet/snooze plumbing. **AC:** NT-6.
- [M5-2] (90m) Tonight reminder generation — fresh copy, varied emoji/phrasing/time; JIT pre-gen; offline bank. **AC:** NT-1, NT-2, NT-10, PT-3, PT-4. PROMPT-REVIEW.
- [M5-3] (90m) EQ engine core (§7b) — decide need/channel/format from read-the-room; one tiny step + named stakes; ⚠️ shame-audit. **AC:** NT-11, NT-12, NT-13. PROMPT-REVIEW.
- [M5-4] (90m) Persona cast + co-creation (D-21/26) — Persona model, 2+2 onboarding, roles (Noticer/Never-Left/Hype/Kindred), stylized avatars. **AC:** NT-18, NT-20b, NT-21. PROMPT-REVIEW + NEEDS-VISUAL-REVIEW.
- [M5-5] (90m) Presentation Envelope + communication-style notifications (D-20) — {persona,channel,visual,sound,copy} tuple; intent donation; palette from loves. **AC:** NT-14, NT-15, NT-16. NEEDS-VISUAL-REVIEW.
- [M5-6] (90m) Habituation Horizon enforcement (D-21/22) — `dimensionConstancyMaxDays`, `habituationHorizonDays`, quarter-hour ban, near-dup rejection. **AC:** NT-19, NT-22 ⚠️, NT-24, NT-17.
- [M5-7] (60m) Persona rituals + rest/return (D-22) — ritual windows, jittered minutes, non-daily; personas rest & return. **AC:** NT-20, NT-23.
- [M5-8] (90m) Re-entry choreography (D-23/24) — Noticer→Never-Left→Hype; ⚠️ gap-blindness audit; Kindred; group thread. **AC:** NT-25, NT-26 ⚠️, NT-27, NT-28, NT-29, NT-30, NT-31 ⚠️. PROMPT-REVIEW.
- [M5-9] (60m) Meme follow-up (D-9) — one follow-up after `memeFollowUpDelayHours`, user pack, no repeat 30d, then silence. **AC:** NT-7, NT-8, NT-9.
- [M5-10] (90m) Streaks (§7c, D-13) — process-only, bend-don't-break, never-zero, comeback>continuation, freeze tokens; ⚠️ no intake streaks. **AC:** STRK-1..8. NEEDS-VISUAL-REVIEW.
- [M5-11] (60m) Reward menu (§7c2, D-14) — RewardItem model, bidirectional pairing, tier match, rate limit, zero injected commerce. **AC:** RWD-1..6 ⚠️. PROMPT-REVIEW + NEEDS-VISUAL-REVIEW.
- [M5-12] (60m) Loves-driven generation (§7d) — corpus refs in generated content; rotation/cooldown; never weaponized. **AC:** LOV-1, LOV-5, LOV-6 ⚠️. PROMPT-REVIEW.
- [M5-13] (60m) The Vent (§7c3, D-25) — voice-first dump, listener register, ⚠️ isolation covenant, local-only mode, one consented follow-up, never punitive. **AC:** VNT-1..6 ⚠️. PROMPT-REVIEW + NEEDS-VISUAL-REVIEW.
- [M5-14] (60m) Shopping escalation (D-3) — normal→"for real" w/ named stakes; snooze ≤7d auto-return; NEVER mutes §1 safety. **AC:** GT-8, GT-9, GT-10, GT-11 ⚠️, NT-4. PROMPT-REVIEW.
- [M5-15] (45m) Check-in modality rotation + quiet-down — oneTap/textStyle/voice; `quietDownAfterSkips`. **AC:** NT-3, NT-5, RM-2.

## M6 — Inventory + photos — [M0-0b draft]
- [M6-1] (90m) Photo → vision → structured items (`reconcileInventory` p1) — item list + flaggedUnclear. **AC:** INV-1. PROMPT-REVIEW.
- [M6-2] (60m) Photo privacy gate — person detected → retake/crop; crop is what ships. **AC:** PT-5 ⚠️.
- [M6-3] (90m) Reconciliation conversation — resolve unclear, raise confidence. **AC:** INV-2. PROMPT-REVIEW.
- [M6-4] (60m) Confidence + decay — `inventoryDecayHalfLifeDays`; auto-drop below 0.7. **AC:** INV-3.
- [M6-5] (60m) Passive updates — run completion upserts; eaten decrements/decays. **AC:** INV-4, INV-5.
- [M6-6] (45m) Never-blocking + cook-what-I-have — zero-data flows work; ≥0.7 proposals. **AC:** INV-6, INV-7.
- [M6-7] (90m) Guarantee check v2 (inventory-aware) — subtract beliefs ≥`inventoryConfidenceThreshold`. **AC:** GT-4; re-verify GT-1..3 with inventory.
- [M6-8] (60m) Waste logging (§18) — WasteEvent via one sentence; reflection surfacing + actions; ⚠️ no guilt copy. **AC:** WST-1..5. PROMPT-REVIEW (WST-5).

## M7 — Breakfast + snacks — [M0-0b draft]
- [M7-1] (60m) Per-member breakfast default — currentBreakfast resolves; zero daily entries; graceful nil (DM-6). **AC:** BF-1, DM-6. NEEDS-VISUAL-REVIEW.
- [M7-2] (60m) Breakfast burnout swap — per-person cooldown, 2–3 alts, new default; rest cycles back. **AC:** BF-2, BF-3, BF-5.
- [M7-3] (45m) Breakfast staples on cadence — source `breakfastStaple` onto runs. **AC:** BF-4.
- [M7-4] (60m) Snack cadence inference — from PurchaseRecords; `snackInferenceMinPoints`. **AC:** SN-1, SN-5.
- [M7-5] (60m) Snack replenishment — cadence→run, dedup, run-out flag, manual override. **AC:** SN-2, SN-3, SN-4, SN-6.

## M8 — Occasions, all-timers, HomePod — [M0-0b draft]
- [M8-1] (90m) Occasion menus — occasionTag meals, saved grouping, reuse last year's draft; ~3wk-ahead prompt. **AC:** OCC-1, OCC-3. NEEDS-VISUAL-REVIEW.
- [M8-2] (60m) Occasion lead-time routing — special ingredients onto runs early (beats cadence). **AC:** OCC-2.
- [M8-3] (45m) Eating-out nuclear guard — never auto/occasion; manual only. **AC:** OCC-4, OCC-5.
- [M8-4] (60m) All-timers / core-memory tier — isAllTimeFavorite, coreMemory owner/note; findable by person; occasion surfacing. **AC:** ATF-3, ATF-4.
- [M8-5] (90m) App Intents quick-hits — what's-for-dinner / add-to-run / leftovers / log-waste; ≥3 phrasings each. **AC:** HP-1..5.

## Phase 2 (post-M8) — [pointer, per build-spec §6]
Nutrition (USDA) + auto-Fit tagging; Instacart; fridge-spec container recs; weekly-reflection weight tuning; read-the-room behavioral signals; local sales awareness (SALE-1..3, Kroger/Harris-Teeter path); place-loves store routing (LOV-8). All Phase 2 — not scheduled here.

## Parked for review windows (never autonomous)
- Any aesthetic iteration; notification copy/tone bank; Claude API prompt tuning.

## Blocked pending Ria
- *(cleared 2026-07-07 per D-32 — Q1/Q2/Q4/Q5 were already canon via D-1/D-5/D-2/D-3; M0-4 unblocked. Only Q3 (score resolution) remains open and it's non-blocking: −2…+2 per spec §2 unless Ria wants finer.)*
