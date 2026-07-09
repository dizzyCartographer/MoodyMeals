# CLAUDE.md — Standing rules for autonomous runs on Moody

## Project
Moody: a mood/capacity-aware family meal-planning iOS app. Swift/SwiftUI, SwiftData, EventKit, Claude API.
Authority order when documents conflict: `QUESTIONS.md` answers from Ria > `moody-build-spec.md` > `moody-meal-app-requirements.md`.

## Work loop
1. Take the topmost unblocked task in `BACKLOG.md`.
2. Implement it. Small, focused changes only — do not refactor beyond the task's scope.
3. Run the full test suite (`xcodebuild test` on the iPhone simulator). All green before commit.
4. Commit with message `[TASK-ID] summary`. One commit per task. **Push after every commit** (chosen by Ria 2026-07-09: she runs cloud coding sessions from her phone off the GitHub remote — a stale remote strands them; a `.claude/settings.json` hook also auto-pushes as backup).
5. Append an entry to `RUNLOG.md` (task, outcome, tests added/passing, anything notable).
6. Move to the next task.

## Hard rules
- **Never guess on open decisions.** If a task touches an open question in the build spec §7 or anything ambiguous, write it to `QUESTIONS.md`, mark the task `BLOCKED(Q#)` in the backlog, and move to the next unblocked task.
- **Never violate the safety invariants** in TEST_CASES.md §1 (dietary hard constraints). If any test in that section fails, stop feature work and fix it first — nothing ships over a red safety test.
- **Tests before commit, always.** A task without tests for its acceptance criteria is not done.
- **UI tasks are review-gated.** Implement, screenshot via simulator if possible, mark `NEEDS-VISUAL-REVIEW` in RUNLOG. Do not iterate on aesthetics autonomously.
- **No new dependencies** without a QUESTIONS.md entry. Prefer first-party frameworks.
- **No hardcoded behavioral numbers.** Every threshold/weight/window comes from `TuningConfig` (build-spec §8) with the documented default. Inventing a new constant = add it to TuningConfig + note it in RUNLOG.
- **Do not touch** `moody-meal-app-requirements.md` or `moody-build-spec.md` — those are Ria's documents.
- Claude API keys come from the environment; never commit secrets.

## Style
- Swift 6 concurrency-clean. SwiftData models exactly as specified in the build spec §2 — deviations require a QUESTIONS entry.
- Naming from the spec is canonical (Loose/Precise, RunTier, MemberMealScore, etc.).
- Every scheduler/guarantee behavior must trace to a test case ID from TEST_CASES.md; reference the ID in the test name (e.g. `test_HC1_glutenNeverScheduledForCaddie`).

## Reaching Ria (added 2026-07-07, per Ria)
Ria walks away during autonomous runs. Send a dispatch push (PushNotification) — one line, lead with what's needed and what it unblocks — when:
- a new Decision Digest is posted or work is blocked on her answer,
- a run window ends (with the session summary headline),
- anything needs her approval (safety, new dependency, spec deviation).
Never ping for routine progress.

## Session end — the Decision Digest (required, every run)
Before a run window closes: commit or stash cleanly, confirm the branch is pushed, then write TWO things:

1. **RUNLOG session summary** (done / blocked / needs-visual-review / suite status / next up).
2. **DECISIONS.md digest** — the top of DECISIONS.md gets a dated block containing **3 to 5 legitimate decisions** Ria should make, ranked by how much they unblock. Rules:
   - *Legitimate* means: it changes what gets built, blocks a queued task, is a taste/UX judgment, or is a tunable whose default felt wrong in testing. Never padding — if only 2 genuine decisions exist, list 2 and say so.
   - Never more than 5. Overflow goes to QUESTIONS.md (the deep archive); the digest links any that are urgent.
   - Each decision: **one-line question, 2–3 concrete options with a recommended default, and what it blocks.** Ria should be able to answer each in under a minute.
   - Anything Ria answers in DECISIONS.md becomes canon (same authority as QUESTIONS answers); copy resolved items to the Answered section with the date.
   - If a previous digest item went unanswered and now blocks work, it may reappear once, marked ⏫ — never nag beyond that; find other unblocked work.
