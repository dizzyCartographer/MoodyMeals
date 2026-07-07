# MoodyMeals

A mood- and capacity-aware family meal planner. Native Swift/SwiftUI, SwiftData, EventKit, Claude API.

**The mission:** *"I don't need one meal. I need all the meals, and I need them to be from me."* Friends can bring a casserole; they can't bring capacity. Moody makes the cook harder to knock over.

Built around how an AuDHD household actually works: kill decision fatigue, leave room for creativity, manage novelty cyclically, read the room, respect object permanence, and guarantee that if you shop per the app, tonight's meal is always cookable.

## Documents
- `docs/requirements.md` — the north-star vision & requirements
- `docs/build-spec.md` — resolved decisions, SwiftData data model, scheduler spec, milestones
- `CLAUDE.md` — standing rules for autonomous Claude Code runs
- `BACKLOG.md` — the work queue (M0–M2 broken into criteria-tagged tasks)
- `TEST_CASES.md` — ~120 test cases; §1 and §10 are safety-critical
- `RUNLOG.md` / `QUESTIONS.md` / `DECISIONS.md` — the twice-daily review loop (DECISIONS.md is the 3–5-item morning digest)

## Workflow
Claude Code works `BACKLOG.md` top-down under `CLAUDE.md` rules: implement → test → commit → log. Ambiguities park in `QUESTIONS.md`; Ria reviews mornings and evenings.

Authority order: QUESTIONS answers > build-spec > requirements.
