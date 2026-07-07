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

<!-- Template (keep for reference):
## Session summary — [DATE, night/day run]
- Done / Blocked / Needs visual review / Test suite / Next up
### [TASK-ID] — [title]
- Outcome / Tests added / Notes
-->

