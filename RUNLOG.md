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

