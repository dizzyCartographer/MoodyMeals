# RUNLOG.md — autonomous session log
Newest at top. One block per task; one Session summary per run window.

---
## Session summary — 2026-07-07 (first autonomous run)
- **Done:** repo bootstrap (clone + specs/harness/test-bank committed & pushed); M0-0 consistency read
- **Blocked:** none new (M0-4's listed blockers Q1/Q2/Q4/Q5 are stale — resolved by canon D-1/D-5/D-2/D-3; see D-32)
- **Needs visual review:** none
- **Test suite:** N/A — M0-0 is docs-only; no code yet (Xcode target lands at M0-1)
- **Next up:** M0-0b (extend backlog M3–M8), then M0-1 (Xcode scaffold)

### [M0-0] — Consistency read (all docs end-to-end)
- Outcome: **done**. AC met: findings list written below before any code. Contradictions/ambiguities/drift logged to QUESTIONS.md (F1–F12); the 5 decision-needing ones proposed in today's digest (D-32…D-36). Nothing resolved unilaterally.
- Tests added: none (analysis task)
- Docs touched: QUESTIONS.md (F1–F12), DECISIONS.md (digest D-32…D-36), RUNLOG.md. Did **not** touch build-spec.md / requirements.md (protected) or resolve any open question.

**Findings list (M0-0 AC):**
1. **Stale blockers (F1→D-32):** QUESTIONS Q1/Q2/Q4/Q5, build-spec §7, and BACKLOG "Blocked pending Ria" all list Q1/Q2/Q4/Q5 as open, but canon D-1/D-5/D-2/D-3 already resolve them and the §2 model implements them. Only Q3 is genuinely open. → M0-4 is effectively unblocked.
2. **Leftover-chain data gap (F2→D-33):** `InventoryItem` lacks `kind` + `useBy`, required by Step 1d and LC-3/LC-5.
3. **StapleItem provenance (F3→D-34):** `ItemSource` has no `staple` case, needed by PT-7/SCH-13.
4. **Elsie goal vs staples (F4→D-35):** D-6 "replaces the plate rule," but `FoodNeedGoal.proteinVegStarch` + requirements still describe it. Seed ambiguity.
5. **DM-4 rule (F5→D-36):** precise-recipe-missing-amount behavior undecided (reject vs downgrade).
6. **Doc hygiene (F6–F12, parked):** CLAUDE.md names stale file paths (`moody-*.md` vs `docs/*.md`); no `noveltyDialPosition` tunable for SCH-9; cooldown min/max not discrete §8 rows; TEST_CASES section order + "Step 4a2" label cosmetic; requirements' open-questions already resolved by build-spec (expected); `methodAffinity` key-type confirm.
- **Cross-check clean:** every TC ID referenced by BACKLOG (HC-6, DM-3, CAL-1..4, SF-1..3, SL-1..6, RT-1..6, GT-1..8) exists in TEST_CASES — no dangling references.
- Notes: authority resolved as QUESTIONS/DECISIONS-answers > build-spec > requirements. Treating DECISIONS "Answered (canon)" D-1…D-31 as canon (they're baked into the §2 model), which is why the §7/QUESTIONS "open" lists read as drift, not genuine blockers.

### [M1-2] — EventKit service (Moody calendar)
- Outcome: **done**. `CalendarStore` protocol seam + thin `EventKitCalendarStore` adapter + `CalendarSyncService`: events land on the dedicated "Moody" calendar only (CAL-1), edits update in place / clears remove — no orphans, incl. the D-37 needs-refill state dropping its stale event (CAL-2), denial leaves the app fully functional with visible explanation copy (CAL-3), and `ShopWindows.suggest` proposes non-overlapping windows around commitments (CAL-4, pure logic). Sync wired into the Plan tab (assign/clear/toolbar sync + denied alert). Suite 65/65.
- Tests added: 5 in CalendarSyncTests against a `MockCalendarStore` — CAL-1, CAL-2, CAL-2b (refill-flag × event removal), CAL-3, CAL-4.
- Notes: (1) **Mockable vs not (per AC):** all sync LOGIC is mock-tested; the `EKEventStore` adapter itself (permission dialogs, calendar creation on a real source) is simulator/manual-verify territory — flagged for a device pass later. (2) Found+fixed an infinite loop in window suggestion: `DateInterval.intersects` counts *touching* as intersecting, so the cursor stalled at busy-block boundaries; strict-overlap comparison, pinned by test (back-to-back windows are legal). (3) New constants `dinnerEventHour=18 / breakfastEventHour=7 / planEventDurationMinutes=60` added to TuningDefaults (not in §8 — flag for TuningConfig at M4-1). (4) Info.plist calendar usage string added to both configs.

### [M1-1] — Manual planning week grid — NEEDS-VISUAL-REVIEW
- Outcome: **done, review-gated**. New Plan tab: 7-day grid (dinner + breakfast rows), prev/this/next week nav, assign via meal picker (active + slot-eligible meals, GF-verified shield shown), one entry per (day, slot) — reassign edits, never duplicates. Lock toggle per entry (guards the scheduler, never the user). Swipe: clear / swap. D-37 flag state renders ("⚠︎ needs refill") when a planned meal was deleted. Suite 60/60.
- Tests added: 7 in WeekPlanTests — assign creates on day-anchor with attendees (10:41pm tap lands on that day), reassign-edits-no-duplicates, breakfast+dinner coexist, **lock persists (the AC)**, week-days helper, HC-5 confirmation guard both ways (gluten+GF-attendee ⇒ confirm; verified or GF-member-absent ⇒ frictionless, SCH-14 groundwork).
- Notes: (1) **HC-5 (§1) shipped WITH the feature**: picking a not-verified meal for a night a GF-hard member attends raises an explicit named confirm ("isn't verified safe for Caddie…") — manual override allowed, silent never. Names come from data, never hardcoded (D-35). (2) Attendees default to everyone (D-5); attendance-editing chips are a later UI pass. (3) Logic lives in a UI-free `WeekPlan` service so the AC is unit-tested, not XCUITest-dependent.

### [M0-7] — Basic CRUD screens (M0 COMPLETE) — NEEDS-VISUAL-REVIEW
- Outcome: **done, review-gated**. Meals + Recipes tabs (list/create/edit/delete). Meal form: title/notes/effort/slots/calm-day/tags/frequency/all-timer/eating-out + read-only composition with a live "Caddie-safe" readout. Recipe form: Loose/Precise picker, ingredient add (reuses catalog by name; NEW ingredients enter UNVERIFIED per HC-7), D-36 optional amounts, steps. Tri-state GF badge on every ingredient row (verified ✓ / contains gluten / unverified-check-label). Deletes ride the D-37 rails. Screenshot: docs/screenshots/m0-7-meals-list.png. Suite 53/53.
- Tests added: 3 in CRUDPersistenceTests — create→edit meal persists (updatedAt advances, F15 interim touch-on-exit), create→edit recipe with new-unverified ingredient (HC-7), end-to-end safe delete of a scored+planned+breakfast meal.
- Notes: **No aesthetic iteration done** (CLAUDE.md rule) — screens are deliberately plain SwiftUI; the design brief's language lands in a design session. F15 interim: edit screens touch `updatedAt` on exit; the systematic mechanism is still parked.

### [M0-5] — Core models, shopping/inventory/household (unblocked by D-34)
- Outcome: **done**. All nine §2 models + enums (`RunStatus`, `ItemSource` + D-34 `staple`, `StorageLocation`, `Capacity`, `CheckInModality`), `Snack` completed (cadence trio), `InventoryItem` carries D-33 `kind`/`useBy`, `StapleItem` under D-6. Seed extended: Elsie's lifeline (sandwich bread ×1 loaf, garbanzo beans ×2 cans) + Cojack sticks snack (cadence nil — SN-5, no phantom inference). Suite 47/47.
- Tests added: 10 in ShoppingModelTests — run+items round-trip w/ cascade (ingredients survive), `staple` provenance, purchase-record links, snack cadence trio (SN-2/SN-5 groundwork), leftover inventory (kind/useBy vs TuningDefaults window), waste event, check-in incl. skipped-is-signal, weekly reflection, staple w/ member link, fridge spec.
- Notes: (1) D-37's delete-rule bundle was applied in the preceding [DIGEST] commit (4 new tests: DM-5, DM-6, flag-and-refill, attendee/cook nullify — all green). D-38 flip applied there too. (2) Adversarial review caught the dangling-reference class recurring on the NEW edges — fixed under D-37's principle (F18: member staples go household-generic, purchase history outlives runs/snacks; +2 regression tests, +1 seed test) and parked the ingredient-deletion policy as **D-39** (F19). Final: 50/50.

### [M0-6] — Seed data (done ahead of blocked M0-5)
- Outcome: **done**. The five members (Caddie GF-hard; Ria hemeIron+antiInflammatory, grill+2/oven−2; Elsie proteinVegStarch per D-35; Chad highCalorie, 1.5×/+0.5 appetite), 24 ingredients (verified / unverified / contained-gluten mix per D-30), 16 meals covering every AC shape (all-timer w/ core memory, Taco-Tuesday tag, leftover chain D-4, breakfast-for-dinner D-1, eating-out D-7, HC-4 unverified-fries case), Wednesday b4d anchor seeded OFF. App shows household on launch. Suite 33/33.
- Tests added: 4 in SeedDataTests — members+needs, AC meal shapes (incl. GF-safety spot-checks through the seed), canon compliance (zero seeded scores per PT-1 cold-start, no sheet-pan per D-4, anchor off per D-1), idempotent double-load.
- Notes: Elsie's StapleItems (D-6) can't seed until M0-5 unblocks (D-34) — noted in seed comments. Scores deliberately empty: onboarding's swipe pass is the source of Liking/Fit signal, never the seed.

### [M0-4] — Core models, meals & planning
- Outcome: **done**. Full §2 `Meal` (scheduling knobs, leftover chains, multi-slot D-1, method tags D-28, all-timer/core-memory, eating-out D-7), `PlanEntry` (attendees D-5, lock, cook), `ThemeAnchor`, all enums. `TuningDefaults` added as the pre-M4 home for §8 defaults (componentFreshnessDays, anchorVarietyPeriodWeeks, cooldownDefaultDays) — no literals in tests. Suite 29/29.
- Tests added: 7 in PlanningModelTests — DM-3 (freeform meal valid+plannable), full-shape round-trip (non-default values incl. producer half of D-4), D-1 multi-slot, rotation/cooldown, PlanEntry date/slot/attendees/lock/cook, ThemeAnchor w/ §8 default, F17 independence+shareability regression. Plus one F17 assertion added to M0-2's breakfast test.
- Notes: **(1) Review caught real data corruption before it ever shipped:** SwiftData silently inferred `coreMemoryOwner` ↔ `currentBreakfast` as inverses — marking a core-memory meal overwrote breakfast defaults, breakfasts couldn't be shared (BF-3), breakfast edits erased core-memory data. Fixed with an explicit inverse (`FamilyMember.coreMemoryMeals`, F17 — forced deviation, retroactive OK requested). (2) F14 scope widened: PlanEntry.meal + attendees/assignedCook delete rules also trap on deletion (verified) — one D-37 decision now covers all five edges. (3) M0-5 marked BLOCKED(D-34) — pinged Ria; next unblocked task is M0-6 (seed data).

### [M0-3] — Core models, food
- Outcome: **done**. `Ingredient` (tri-state `isGlutenFreeVerified`), `Perishability`, `RunTier`, `Recipe`, `RecipeKind`, `RecipeItem` spec-§2-exact (reviewer-confirmed clean). Meal gained its composition fields (freeformNotes/recipes/directItems — staged build-out, planning knobs at M0-4). New `GlutenSafety.swift`: celiac rule as code — nil = unverified = unsafe, propagation per HC-6. Suite 22/22.
- Tests added: 12 in FoodModelTests — tri-state survives store (nil ≠ false), DM-2 loose-nil persistence, DM-4-as-D-36 mixed precision (stays `.precise`), HC-6 propagation via recipes AND direct items, HC-6b/c/d conservative-unknown pins, false-as-unsafe, direct-items-only positive control, recipe-level fail-safe, recipe→items cascade (ingredients survive).
- Notes: (1) Adversarial safety review (3 reviewers, one ran mutation testing) caught a real bypass — freeform notes + one verified item read safe; fixed conservative-side, **F16/F16b in QUESTIONS need Ria's confirm** (notes = unknown chunk vs. commentary; one-line flip either way). (2) Recipe-level `allIngredientsGFVerified` made fail-safe standalone (zero items ⇒ never verified). (3) M0-4 heads-up: F14 (meal-side delete rules) needs a D-37 decision before DM-5/DM-6 tests can land — Meal completion itself is unblocked.

### [M0-2] — Core models, people
- Outcome: **done**. `FamilyMember`, `DietaryRequirement`, `FoodNeedGoal`, `MemberMealScore` spec-§2-exact (non-optional `member`/`meal` included; cascade verified working on iOS 26.5). Minimal `Meal`/`Snack` placeholders staged (completed at M0-4/M0-5). Suite 10/10.
- Tests added: 8 in PeopleModelTests — full-field round-trip, hard/soft needs distinctness (§1 groundwork), MemberMealScore two-axes+safety, SF-1/SF-3 model-level, member-delete cascade, snacks many-to-many, currentBreakfast reference. All fetch through a FRESH ModelContext post-save (decode-from-store proven, not identity-map reads).
- Notes: (1) Chased a full-suite crash to a test-harness bug: ModelContext does not retain its ModelContainer — helper returning a bare context left the container deallocating; documented in the test file. (2) Ran a 3-reviewer adversarial verification; 10 findings, all applied or parked: F14 (Meal-side delete rules unpinned in spec §2 — dangling-reference crash risk at meal deletion; proposing D-37 at M0-4) and F15 (`updatedAt` touch mechanism — M0-7) in QUESTIONS.md. (3) D-35 canon honored: `proteinVegStarch` is a generic goal case; no member-specific code anywhere.

### [M0-1] — Xcode project scaffold
- Outcome: **done**. `xcodebuild test` green: 2/2 passing on iPhone 17 Pro (iOS 26.5). Hand-authored pbxproj (objectVersion 77, file-system-synchronized groups — files added later auto-join targets), shared scheme, app + test targets, SwiftData container with placeholder `AppInfo` model + `AppSchema` registry.
- Tests added: `SmokeTests.testTargetRuns`, `SmokeTests.testInMemoryContainerRoundTrips` (in-memory SwiftData round-trip).
- Notes: (1) Environment fix needed first — Xcode 26.6 had no iOS platform component; downloaded iOS 26.5 simulator platform (8.5 GB) via `xcodebuild -downloadPlatform iOS`. (2) One pbxproj bug found & fixed: missing `PBXFileReference` product entries → "No test bundle product" on the test action. (3) Benign CoreData stderr noise on first app-host launch (store creation in fresh sim) — not a test failure.

### [M0-0b] — Extend backlog (M3–M8)
- Outcome: **done** (awaits digest approval per AC). Drafted M3–M8 + Phase 2 pointer in BACKLOG.md at M0–M2 granularity; every task traces to TEST_CASES IDs; AI-prompt tasks tagged PROMPT-REVIEW, UI tagged NEEDS-VISUAL-REVIEW.
- Tests added: none (planning task)
- Notes: M4 (16 tasks) and M5 (15 tasks) are oversized — recommend split (M4/M4b; M5/M5b/M5c). Parked as F13 for your approval. Toolchain confirmed present: Xcode 26.6, Swift 6.3.3, iOS 26 + iOS 17 simulators — M0-1 scaffold is actionable next.

<!-- Template (keep for reference):
## Session summary — [DATE, night/day run]
- Done / Blocked / Needs visual review / Test suite / Next up
### [TASK-ID] — [title]
- Outcome / Tests added / Notes
-->

