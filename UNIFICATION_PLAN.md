# Unification plan — one Moody from two builds

Two implementations exist. They are complementary halves of the same product:

| | **Local** (this repo) | **GitHub** (`dizzyCartographer/MoodyMeals`) |
|---|---|---|
| Surface | 7 pixel-audited Sticker Aisle screens, widgets, Live Activity, celebrations | Stock SwiftUI lists, self-flagged NEEDS-VISUAL-REVIEW |
| Domain | Demo AppState, hardcoded badges, fake solver | 18 SwiftData models, tri-state GF safety logic, shopping explosion→routing→guarantee, EventKit sync, Reminders export |
| Truth | The design kit | 41 Ria-answered canon decisions (DECISIONS.md) + protected spec docs |
| Tests | None | 102, behavioral, all green |
| Data | Demo fiction (Taco Tuesday, PB 23) | Real: 5 member profiles, 18 meals with ingredients + GF status, Elsie's actual lifeline, Chad's appetite math, full tuning table |
| Process | Ad-hoc sessions | Docs harness: backlog → tests → digest → canon |

**Verdict: their engine + her canon + their process, under our surface.** Neither build is discarded — the GitHub UI was always a placeholder awaiting exactly what we have, and our domain layer was always a placeholder awaiting exactly what they have.

## Canon violations in the local build (fix during graft)

1. **D-35 (worst):** `Meal.badges` hardcodes "Caddie GF ✓ / Elsie plain ✓ / Chad ×2 ✓" — no member may be hardcoded, ever. Badges must derive per-attendee from data (GlutenSafety verdict, MemberMealScore.isSafeFood, appetite), and "Elsie plain" must not read as fallback-as-plan.
2. **D-13:** local streak hero says "DINNERS FROM HOME" — canon counts ANY dinner (fallback, leftovers, even the nuclear option); 48h grace; freeze tokens earned at a tunable rate, not "every 7 dinners."
3. **D-40:** lunch is in scope; the designed week plan has nowhere to put it (design question, flagged to the brief).
4. **Tuning rule:** no behavioral number hardcoded — local's magic numbers route through their `TuningDefaults`.
5. **D-7 / D-4 / D-22 etc.:** eating out never auto-scheduled; no sheet-pan framing anywhere; persona timing never on :00/:15/:30/:45. Copy/solver passes needed.

## Phases

- **P0 — coexistence (tonight):** `unify` branch; merge `github/main` (unrelated histories — trees don't collide: their `MoodyMeals/`, our `Moody/`). XcodeGen absorbs their sources: one app target (our UI + their engine), their test target intact and green. Their `.xcodeproj` retires; `project.yml` rules.
- **P1 — the facade (tonight):** `AppState` keeps its exact `@Published` API but reimplements over `ModelContext` + their services: `week` = projection of this week's dinner `PlanEntry`s; `commitTonight` → `WeekPlan.assign`/`Tonight.swap`; `guaranteeLine` → `GuaranteeCheck`; badges → derived per-attendee (D-35 fixed at the root). Slug↔UUID mapping for deep links/scripted content; effort mapping (noCook+assembly→1 dot). Seeds switch to their real `SeedData`.
- **P2 — persistence & widgets:** SwiftData store moves into the App Group; widgets/Live Activity keep reading a `MoodySnapshot` projection emitted on save (no cross-process SwiftData risk).
- **P3 — canon compliance pass on the surface:** streak copy, badge states *(tri-state is the shipped interim model only — retired at M4-0 per D-44 in favor of safe/awaiting-substitution/unsafe bands + D-46 chips; style minimally, expect replacement)*, HC-5 never-silent GF confirm restyled to the kit *(D-44 narrows HC-5 to the unsafe band; the design ruling arrived — yellow is the ceiling, no red exists, see the Phase 2 escalation pattern)*, edge-state voice pass (law 4/7) on every ported string.
- **P4 — their integrations, properly homed:** calendar sync + Reminders export ship behind the Wave-1 Settings root with in-voice permission primers (their toolbar-button entry point retires only after Settings exists). Reminders export = secondary escape hatch; the designed run checklist stays primary (it feeds the guarantee; exports don't).
- **P5 — process adoption:** their docs harness (BACKLOG → tests → RUNLOG → twice-daily DECISIONS digest) becomes this repo's operating system. Canon order: Ria's answers > build-spec > requirements. Their M3–M8 backlog and our DESIGN_BRIEF_V2 waves merge into one plan.

## Engine issues to fix during graft (from adversarial review)

ShoppingListBuilder merges by name while explosion merges by UUID (dupe-name data loss); no uniqueness guards on (member,meal) scores or (date,slot) entries; CalendarSyncService/RemindersExport swallow errors "best-effort" against their own CAL-3 principle; no schema versioning before real data; guarantee coverage is name-only (documented v1 limit — keep documented).

## Decisions only Maria can make

1. ~~PRIVACY~~ **Resolved (Maria, 2026-07-09):** the family names throughout are nicknames — the repo is pseudonymized by design — and she judges GF status non-sensitive. The repo stays public at her discretion; no action needed.
2. ~~**D-39, D-17, D-18**~~ **Answered by Ria 2026-07-09 in the parallel cloud session** — D-39 soft-delete/archive only; D-17 per-tier floor (−2 ≤ 1×/14d, −1 ≤ 1×/7d); D-18 never auto-decide, keep swaps one-tap. See DECISIONS.md Answered (canon). No action needed.
3. **Taste grid:** ~~their PT-1 cold-start canon vs. workbook item 22~~ **Recommendation applied** — item 22 withdrawn from the workbook per PT-1 (the onboarding swipe pass creates scores; Phase 2 screen 12 designs it). Reopen only if Maria objects.
4. **Wednesday collision:** local demo says Chad-cooks-ramen-Wednesday; canon's only seeded anchor is Wednesday breakfast-for-dinner (D-1, inactive). Which is real?
5. **Push/remote strategy after unification** — once private: does the unified repo live on GitHub (recommended — restores your git connector too)?
