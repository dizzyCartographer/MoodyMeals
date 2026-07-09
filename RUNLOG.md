# RUNLOG.md — autonomous session log
Newest at top. One block per task; one Session summary per run window.

---
### [D-44] — GF safety model rewritten: risk classes + brands + substitutions (2026-07-09, live)
- Outcome: **canon recorded (D-44)**. Ria retired the verified-per-ingredient model entirely ("I do not want to have to mark fresh broccoli as gf"): whole foods safe with no marking; gluten carriers (seeded: flour, bread, pasta, crackers, beer, regular soy sauce; extendable) are the only class that raises anything — recipe shows "substitutions may be required" until a per-recipe standard mod is recorded (her quiche → King Arthur gf pie crust mix, verbatim in canon); packaged goods get optional preferred brands that ride to shopping lists, safe by default when unset. §1 flagged for rewrite at M4-0 with her sign-off gate before old tests die; shipped app keeps conservative behavior until then. Her GF-API question → Q9 (Open Food Facts, assistive-grade, M6, new-dep gate; near-term Claude capture-time carrier flagging at M3-2). Elsie (second push-back): NO rule at all — D-35 objective + scores + staples carry the end goal; smallest-fix-later only if usage shows dinners failing her. M4-0 re-scoped (split candidate a/b), M3-2 re-scoped, D-42 digest amended again.
- Tests added: none (docs only; code swap lands at M4-0).
- Refinement (same session): carriers ARE flagged until subs are documented — calm indicator, never nuclear (design law #4); documented sub/brand ⇒ fully safe, indicator gone. NEW: household standard substitutions ("flour as thickener → corn starch") with a bulk-apply checklist across flagged recipes (checklist not auto-apply — flour-in-roux ≠ flour-in-crust; per-recipe subs override household defaults). M4-0(b) re-scoped.
- CORRECTION (Ria, same session): "awaiting substitution" is SCHEDULABLE — incl. Caddie nights, no confirm friction (badge rides plan/Tonight as cook-time reminder; shopping line gets substitution-needed qualifier). Only UNSAFE gates (excluded from auto-fill; HC-5 warn-confirm on manual assignment). Previous "both bands block scheduling" claim was wrong and is retracted in D-44 + M4-0 AC.
- D-42 marked ANSWERED (a): five consecutive live messages specifying the model's details constitute approval; provenance noted in the digest entry, Ria offered a one-word veto in chat. M4-0 → TODO.
- Final framing (same session): "first pass sorts actually-unsafe from needs-a-little-thought; Ria fine-tunes from reality" — migration emits a reviewable triage of the whole recipe box; her band/profile overrides persist and outrank re-scores forever; thresholds are her sliders. Added to M4-0 AC.
- Second refinement (same session): severity SCORED, not binary — states are "awaiting substitution" (calm question) vs "unsafe" (nuclear, structural gluten only). Quantified via carrier substitution profiles (dropIn / quantitySensitive / nonSubstitutable) + thresholds (count share ≥0.25 OR ≥1 cup normalized → unsafe; TuningConfig keys at M4-1). Ria's example pins: bread→unsafe, mac-n-cheese→question, tbsp-flour→question. Both bands block Caddie auto-scheduling until resolved — tone differs, safety doesn't. Bulk preview must name every recipe + exact line (zero hunting). M4-0(b) re-scoped again.

### [D-43] — Stressor days: flexibility, not automation (2026-07-09, live)
- Outcome: **canon recorded**. Ria's refinement of D-18: keep declared stressor patterns in the flow, but a match OFFERS flexibility (swap/"just decide" lead, low-effort alternates staged) — never preemptive caps/plan rewrites/auto-switching. Behavioral disengagement (ignored-notification count, time-since-app-open) named the primary state signal, ahead of calendar prediction. STRS-1..3 re-scoped in TEST_CASES; M4-16 re-scoped to "stressor-day flexibility" (NEEDS-VISUAL-REVIEW); M5-3 annotated with primary signals. Net effect: fewer rules in the scheduler, not more.
- Tests added: none (docs only; implementations land at M4-16 / M5-3 / M5-15).
- Refinement (same session): "extra assistance, not decisions" — Ria's canonical example recorded in D-43 (sudden-calendar-spike trigger; ONE concrete reasoned suggestion; plan-preserving swaps preferred; named stakes; one-tap accept; never auto-applied; EQ-register copy = PROMPT-REVIEW). M4-16 re-scoped again to "stressor-day assistance" (est. bumped to 90m), STRS-1 annotation updated.

### [D-42] — Food-rules generalization proposed (2026-07-09, live; AMENDED same session)
- Outcome: **proposed, awaiting Ria** (D-42 digest). Ria spotted that dietary needs are enum-hardcoded (`DietaryRequirement`/`FoodNeedGoal`) — a new restriction (Chuck's high cholesterol) can't land without a code change, violating D-35's no-hardcoding spirit at the condition level. Proposed generic per-member FoodRule {never/limit/boost/require + tags + frequency knob}; task queued as M4-0 BLOCKED(D-42).
- Amendment (same session): Ria rejected the two carve-outs as excessive. Gluten tri-state folds into plain tags — Caddie = require{gf}, untagged = not-for-Caddie ("Done."), meal-level gf tag covers checked takeout; behavior identical, §1 tests must stay green through the swap. Elsie's plate rule folds in as boost{protein, veg, starch} @ ~nightly; staples lifeline untouched. Sole remaining carve-out: taste dislikes stay in scores (D-17).
- Tests added: none (proposal only).

### [D-39/D-17/D-18] — Live answers recorded (2026-07-09, docs only)
- Outcome: **applied to docs**. Ria (live chat): D-39 ingredients soft-delete/archive only (retire/merge, never hard-delete — F19 closed, F18 confirmed; affordance queued as M2-6); D-17 dislike floor per-tier (−2 ≤ once/14d, −1 ≤ once/7d per person; consecutive ban stands — supersedes single `dislikeFloorPerWeek`, keys land at M4-1); D-18 no auto hold/yield on cook-night × stressor (manual + one-tap swap; PT-9 auto-yield retired, no-fault streak pause stays; M4-16 re-scoped). DECISIONS/QUESTIONS/BACKLOG/TEST_CASES annotated.
- Tests added: none — no code touched; suite stands at 102/102 from M2-4. Implementations land with M2-6 / M4-1 / M4-10 / M4-16.
- Notes: asked Ria one scope clarification — whether D-18's "what's useful can change" also applies to STRS-1's preemptive stressor adaptations (effort caps, quiet notifications) or only to moving cook-nights. Design status surfaced: this coding session has no access to the Claude Design project from the remote env (design auth unavailable here); the three NEEDS-VISUAL-REVIEW screenshots are functional scaffolding, not the design pass.

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

### [M2-4] — Markdown + Reminders export
- Outcome: **done**. `ShoppingListBuilder.build`: per-entry explosion merged to one line per ingredient with the STRICTEST need-by (PT-7 spirit), routed via M2-2, grouped by run; unroutable lines land in an at-risk section (never dropped). `markdown()`: checklist format, run headings with dates, ⚠️ at-risk section (SL-6: every uncovered item once, readable). `RemindersExport`: permission-gated behind a `RemindersStore` seam — denied returns a visible reason naming the markdown fallback; authorized adds every item to a per-run Reminders list. Thin `EventKitRemindersStore` adapter + Info.plist usage string (both configs). Suite 102/102.
- Tests added: 3 in ShoppingListBuilderTests — SL-6 (once/grouped/summed/readable + at-risk), Reminders authorized path (items land on the run's list), denied path (visible, never silent). One test-scenario self-catch: the midweek run legitimately carried cod within its shelf window — scenario corrected, not the code.
- Notes: Shopping tab UI intentionally deferred to M2-5 so list + at-risk report ship as one reviewed screen.

### [D-40/D-41] — Lunch in scope; snacks stay replenishment
- Outcome: **applied**. Ria (live): "we eat lunch too... and snacks." D-40: `SlotKind.lunch` everywhere — week-grid row, meal-editor toggle, calendar sync at `lunchEventHour=12`, per-person `currentLunch` default with explicit nullify inverse (D-37 pattern, no implicit-inverse repeat), 2 seed lunch meals. Breakfast-pattern automation (default + burnout swap) lands with M7 as re-scoped. D-41: snacks confirmed stocked-not-scheduled — no change needed. Suite 99/99.
- Tests added: 3-slot coexistence (D-40), currentLunch persists + degrades independently of breakfast.

### [M2-3] — Guarantee check v1 ⚠️ (§10)
- Outcome: **done, review-hardened**. `GuaranteeCheck.check()`: per-tier horizon (furthest next-confirmed run), violations name meal + date + missing items + both ways out (swap / mini-run **on or before** the meal day — always actionable), sorted by date. Inventory beliefs offset at ≥0.7 (GT-4, boundary pinned), never blocking (INV-6). Suite 98/98.
- Tests added: 16 in GuaranteeCheckTests + 3 in RunRoutingTests + SL-5 today-pin. GT-1..6 plus mutation-killers for: same-day-run coverage, tonight+run-later-today, stale purchases, stale confirmed runs, swapped entries, proposed-runs-count, threshold boundary, past entries, out-of-stock staples, fresh-never-bulk (real pin), freshness floor, no-deadline bulk preference + lead boundary.
- Notes: **The adversarial review (3 agents, compiled repros + mutation testing) found 3 verified blockers before commit:** (1) purchases from ANY past done run covered forever — 3-week-old cod "covered" tomorrow's cod dinner (false negative breaking the core promise); fixed with per-cycle coverage windows + `freshShortShelfDays=4` shelf limit (new TuningDefaults, → TuningConfig at M4-1). (2) Day-anchored meal dates vs wall-clock run times — a Saturday-morning run could never cover Saturday dinner, and today's meals were categorically unroutable (the GT-5 cry-wolf failure); fixed with a DAY-granularity contract across route()/check(). (3) No freshness floor — this week's run "covered" fresh fish 17 days out; fixed via the same shelf window. Also: `outOfStock` wired through (SL-4's exception now reachable), routing identity rides ExplodedLine (perishability + preferredRunTier — same-name lookup seam closed), `guaranteeLookaheadRuns=1` documented in TuningDefaults per §8. Shelf-stable purchase coverage stays presence-level until M6's inventory (documented limit).

### [M2-2] — Run tiers + routing
- Outcome: **done**. Pure `RunRouting` per spec §4 step 4: fresh never rides bulk and takes the LATEST fresh-capable run before need-by (RT-1), cadence items with no deadline default to the midweek top-up (RT-2), far-out shelf-stable prefers bulk inside `bulkPreferenceLeadDays=14` (new TuningDefaults constant from §4's ">2 weeks", noted; RT-3), unroutable items raise a violation for the guarantee — never a silent drop (RT-4), `preferredRunTier` override beats inference but degrades to inference when unsatisfiable (RT-5), and export text preserves dietary qualifiers + the plus-extra marker (RT-6). Suite 80/80.
- Tests added: 6 in RunRoutingTests, one per RT case (incl. bulk-in-window-still-never-fresh, and override-fallback edges).
- Notes: routing consumes the M2-1 `ExplodedLine`s and emits violations in the exact shape M2-3's guarantee check needs.

### [M2-1] — Meal→items explosion
- Outcome: **done**. Pure `ShoppingExplosion`: sums precise amounts per (ingredient, unit) across recipes and direct items (SL-1), merges loose requirements into the same line with a `plusExtra` marker — dedup never loses intent (SL-2), freeform meals contribute nothing unless direct items exist (SL-3), pantry staples skipped unless flagged out (SL-4 — exclusion list lives in TuningDefaults: oil/salt/pepper/butter/taco seasoning, case-insensitive), and range selection covers exactly the cookable entries in [from, to) — skipped entries and adjacent weeks never leak (SL-5). GF qualifier rides on every line for RT-6's export text. Suite 74/74.
- Tests added: 5 in ShoppingExplosionTests, one per SL case.
- Notes: `outOfStock` is a parameter — inventory belief supplies it at M2-3/M6; nothing here blocks on inventory (INV-6 spirit).

### [M1-3] — Tonight view (M1 COMPLETE) — NEEDS-VISUAL-REVIEW
- Outcome: **done, review-gated**. Tonight tab: today's dinner card (title, notes, swapped-from-plan marker; needs-refill flag state; "pick dinner" when empty), swap via the same HC-5-guarded picker, per-member safety badges (safe ✓ / not-verified-GF ⚠ / not-today 🌙 / —), and per-person "Safe for X" lists (SF-1). Screenshot: docs/screenshots/m1-3-tonight.png. Suite 69/69.
- Tests added: 4 in TonightTests — SF-1 (per-member list, not household), SF-2 (per-person badges + hard-constraint-outranks-flag: an unverified meal is never "safe" for a GF-hard member even if flagged), SF-3 (notToday hides while active, restores when lapsed, zero user action), swap-records-status.
- Notes: `Tonight.isSafe` caps the comfort flag with §1: GF-hard members' safety requires GF verification — the flag alone can never override celiac safety.

### Session summary — 2026-07-07 (day run, continued)
- **Done today:** M0-0, M0-0b, M0-1…M0-7 (M0 complete), M1-1…M1-3 (M1 complete). Digest cycle ×3: D-32…D-39 (8 answered, D-39 open).
- **Blocked:** none. **Open for Ria:** D-39 (ingredient deletion policy, non-urgent), Q3 (score resolution, non-blocking), F13 (M3–M8 backlog approval), F15 (updatedAt mechanism, parked).
- **Needs visual review:** M0-7 (CRUD), M1-1 (week grid), M1-3 (Tonight) — screenshots in docs/screenshots/.
- **Test suite:** 69/69 passing.
- **Review-loop catches today:** identity-map round-trips (M0-2), freeform GF bypass + mutation-tested nil-path gap (M0-3), implicit-inverse data corruption (M0-4 blocker), dangling-reference class on M0-5 edges (F18), DateInterval touching-intervals infinite loop (M1-2).
- **Next up:** M2-1 (meal→items explosion).

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

