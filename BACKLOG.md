# BACKLOG.md — Moody build queue
Work top-down. Format: `[ID] (est) Task — Acceptance criteria`. Statuses: `TODO / IN-PROGRESS / DONE / BLOCKED(Q#) / NEEDS-VISUAL-REVIEW`.

## M0 — Skeleton
- [M0-0] **[DONE 2026-07-07]** (90m) Consistency read — read ALL docs end-to-end (requirements, build-spec, TEST_CASES, DECISIONS); log every contradiction, ambiguity, or decision-vs-spec drift to QUESTIONS.md; propose fixes in the first Decision Digest. Do NOT resolve unilaterally. **AC:** a written findings list (even if empty) in RUNLOG before any code. → findings F1–F12 in QUESTIONS.md; digest D-32…D-36.
- [M0-0b] (45m) Extend this backlog — draft task breakdowns for M3–M8 at the same criteria-tagged granularity as M0–M2; mark AI-prompt tasks as review-gated. **AC:** backlog covers all milestones; Ria approves in a digest.
- [M0-1] (60m) Xcode project scaffold — SwiftUI app target, SwiftData container, test target builds and runs an empty test. **AC:** `xcodebuild test` green in simulator.
- [M0-2] (90m) Core models, people — `FamilyMember`, `DietaryRequirement`, `FoodNeedGoal`, `MemberMealScore` per spec §2. **AC:** round-trip persistence tests; TC §1 model-level invariants compile.
- [M0-3] (90m) Core models, food — `Ingredient`, `Recipe`, `RecipeKind`, `RecipeItem` incl. tri-state `isGlutenFreeVerified`. **AC:** loose recipe with nil amounts persists; TC-HC-6 passes.
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

## Parked for review windows (never autonomous)
- Any aesthetic iteration; notification copy/tone bank; Claude API prompt tuning.

## Blocked pending Ria (build-spec §7)
- [Q1] slotKind single vs multi (affects M0-4)  - [Q2] attendance modeling  - [Q3] score resolution  - [Q4] default cooldown  - [Q5] escalation ceiling
