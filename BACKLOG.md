# BACKLOG.md — Moody build queue
Work top-down. Format: `[ID] (est) Task — Acceptance criteria`. Statuses: `TODO / IN-PROGRESS / DONE / BLOCKED(Q#) / NEEDS-VISUAL-REVIEW`.

## M0 — Skeleton
- [M0-0] **[DONE 2026-07-07]** (90m) Consistency read — read ALL docs end-to-end (requirements, build-spec, TEST_CASES, DECISIONS); log every contradiction, ambiguity, or decision-vs-spec drift to QUESTIONS.md; propose fixes in the first Decision Digest. Do NOT resolve unilaterally. **AC:** a written findings list (even if empty) in RUNLOG before any code. → findings F1–F12 in QUESTIONS.md; digest D-32…D-36.
- [M0-0b] **[DONE 2026-07-07 — APPROVED 2026-07-09 (F13)]** (45m) Extend this backlog — draft task breakdowns for M3–M8 at the same criteria-tagged granularity as M0–M2; mark AI-prompt tasks as review-gated. **AC:** backlog covers all milestones; Ria approves in a digest. → drafted below (M3–M8 + Phase 2 pointer); M4/M5 flagged oversized (split candidates). Approval parked in QUESTIONS (F13).
- [M0-1] **[DONE 2026-07-07]** (60m) Xcode project scaffold — SwiftUI app target, SwiftData container, test target builds and runs an empty test. **AC:** `xcodebuild test` green in simulator. → 2/2 passing, iPhone 17 Pro sim (iOS 26.5).
- [M0-2] **[DONE 2026-07-07]** (90m) Core models, people — `FamilyMember`, `DietaryRequirement`, `FoodNeedGoal`, `MemberMealScore` per spec §2. **AC:** round-trip persistence tests; TC §1 model-level invariants compile. → 8 tests, fresh-context decode verified; adversarial review applied (F14/F15 parked).
- [M0-3] **[DONE 2026-07-07]** (90m) Core models, food — `Ingredient`, `Recipe`, `RecipeKind`, `RecipeItem` incl. tri-state `isGlutenFreeVerified`. **AC:** loose recipe with nil amounts persists; TC-HC-6 passes. → 12 tests incl. HC-6 both paths + D-36 mixed precision; safety review applied (F16/F16b conservative defaults pinned).
- [M0-4] **[DONE 2026-07-07]** (90m) Core models, meals & planning — `Meal`, `PlanEntry`, `ThemeAnchor`, enums. **AC:** meal with zero recipes + freeform text is valid (TC-DM-3). → 7 tests; review caught + fixed a SwiftData implicit-inverse data-corruption bug (F17); DM-5/DM-6 tests parked on D-37.
- [M0-5] **[DONE 2026-07-07]** (60m) Core models, shopping/inventory/etc — `ShoppingRun/Item`, `Snack`, `PurchaseRecord`, `InventoryItem`, `WasteEvent`, `CheckIn`, `WeeklyReflection`, `FridgeSpec` (+`StapleItem`). **AC:** persistence tests for each. → unblocked by D-34; 10 tests; D-33 leftover fields + `staple` source in; Elsie's lifeline staples seeded (D-6).
- [M0-6] **[DONE 2026-07-07]** (45m) Seed data — the five household members with hard requirements/soft goals per requirements doc; ~15 seed meals incl. GF-verified and unverified items, one all-time favorite, one Taco-Tuesday-tagged meal. **AC:** seed loads idempotently; used by all later tests. → 16 meals, 24 ingredients, Wednesday b4d anchor seeded OFF; done ahead of M0-5 (blocked on D-34).
- [M0-7] **[DONE 2026-07-07 — NEEDS-VISUAL-REVIEW]** (90m) Basic CRUD screens for meals/recipes (list + edit). **AC:** builds, creates/edits persist. → Meals/Recipes tabs, tri-state GF badges, D-37-safe deletes; screenshot in docs/screenshots/; 3 CRUD tests. **M0 COMPLETE.**

## M1 — Plan + see
- [M1-1] **[DONE 2026-07-07 — NEEDS-VISUAL-REVIEW]** (90m) Manual planning UI — week grid, assign meal to date+slot, lock toggle. **AC:** PlanEntry created/edited; lock persists. → Plan tab, both slots, week nav, HC-5 confirm flow built in; 7 tests; screenshot in docs/screenshots/.
- [M1-2] **[DONE 2026-07-07]** (90m) EventKit service — dedicated "Moody" calendar; create/update/delete events from PlanEntries; handle permission denial gracefully. **AC:** TC-CAL-1..4 (integration tests may be simulator-limited; document what's mockable). → 5 tests vs mock seam; EK adapter thin, manual-verify; sync wired into Plan tab.
- [M1-3] **[DONE 2026-07-07 — NEEDS-VISUAL-REVIEW]** (60m) Tonight view — today's dinner, swap button, per-member safe badge. **AC:** TC-SF-1..3. → 4 tests; per-member badges incl. GF-hard cap; swap records status. **M1 COMPLETE.**

## U — Unification completion (P2–P4 of UNIFICATION_PLAN.md; P0/P1 done + merged 2026-07-09)
- [U-0] (60m) DESIGN_REVIEW.md fixes (Ria's designer pass, in design_handoff_v2/) — adopt the label-contrast fix everywhere (retire `labelMuted`), de-sticker the week-plan date chip, restore swipe-back alongside the styled back chip, streaks caption derives from strip data (never contradicts the tiles), confetti z-order if cheap. **AC:** each review verdict closed or noted in RUNLOG; screenshots. NEEDS-VISUAL-REVIEW.
- [U-1] **[DONE 2026-07-12]** (90m) App Group store move — SwiftData store into the App Group container; widgets/Live Activity read a `MoodySnapshot` projection emitted on save (no cross-process SwiftData). **AC:** app + widgets show the same live data across relaunch; existing store data survives the move. → `StoreLocation` in the engine (7 tests incl. byte-equality migration + never-clobber); real July-9 store migrated on-sim, verified.
- [U-2] **[DONE 2026-07-12 — NEEDS-VISUAL-REVIEW]** (90m) Surface canon-compliance pass — streak copy audit (D-13), badge states (tri-state = shipped interim per D-44; style minimally), HC-5 confirm styled to the kit (unsafe band only per D-44; yellow ceiling, no red — escalation-pattern gravity), edge-state voice pass (law 4/7 **+ D-48: reassurance shown never narrated — no "no judgment"/"no shame" copy, no simplicity meta-commentary**) on every ported string. **AC:** ported strings/states pass the voice laws incl. D-48; screenshots. NEEDS-VISUAL-REVIEW. → 4 D-48 cuts + 1 minimizer rewrite; AM strip/run cards/date chip/guarantee banner de-fictioned (derived); badges already compliant; HC-5 confirm verified UNREACHABLE in this surface (ships with the meal library — see RUNLOG).
- [U-3] (60m) Integrations homed — calendar sync + Reminders export move behind a Settings root with in-voice permission primers (toolbar entry retires only after Settings exists; DESIGN_BRIEF_V2 Wave-1 item 7 designs the surface). **AC:** CAL-1..4 stay green; export reachable from Settings. NEEDS-VISUAL-REVIEW.

## TF — TestFlight (added 2026-07-12; Maria: "MVP to TestFlight sooner than later")
- [TF-1] **[DONE 2026-07-12 — NEEDS-VISUAL-REVIEW (icon)]** (90m) TestFlight prep — automatic signing (team RC99K6SXQX), kit-derived placeholder app icon, `ITSAppUsesNonExemptEncryption=false`, build number = git commit count, archive/export/upload lane (`scripts/testflight.sh`), runbook (`docs/TESTFLIGHT.md`). **AC:** sim suite green under the signing config; archive reaches Apple's gate. → done; archive verified up to Apple's pending-PLA wall (her accept = the last gate).
- [TF-2] **[DONE 2026-07-12]** (30m) First TestFlight upload — PLA accepted + app record created (Maria, same day); attempt 1 bounced by validation 90474 (XcodeGen's target-level `TARGETED_DEVICE_FAMILY=1,2` default shadowed the project-level iPhone-only setting — pinned per-target, lane hardened to fail loudly on rejected uploads); attempt 2 **"Upload succeeded"** — build 58 processing. Maria's remaining step: ASC → TestFlight → Internal Testing → add herself → install. **Family wave deliberately gated on milestone C (D-53).**

## C — Cloud (D-53, 2026-07-12; jumps ahead of M2 leftovers — the family TestFlight wave is gated on it)
- [C-1] (2×90m — split candidate C-1a models / C-1b tests) CloudKit model-compatibility pass — all §2 models meet CloudKit mirroring rules (relationships optional, every property defaulted, no unique constraints); shape-pin tests (e.g. M0-2's non-optional `member`/`meal`) re-pinned to the new shapes; **§1 safety SEMANTICS unchanged and every safety test still green** — only shape assertions may move, never safety behavior. Store stays in the App Group (U-1 intact). **AC:** suite green end-to-end on the CloudKit-legal schema; a written before/after model-shape table in RUNLOG.
- [C-2] (90m) CloudKit sync, her devices — `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.mariayarley.Moody"))`, iCloud container capability + entitlement (app target; widgets keep reading the snapshot), schema deployed, offline-first verified. Vent excluded from sync per D-25 (local store or per-vent opt-in — smallest honest mechanism). **AC:** edit on device A appears on device B; airplane-mode edits reconcile on reconnect; vents never leave the device by default.
- [C-3a] (90m) Household-sharing spike — SwiftData's CKShare surface is the open question (as of iOS 17/18 it's thin); evaluate: SwiftData-native path vs NSPersistentCloudKitContainer-style share management vs scoped CK layer for the shared zone. **AC:** a written recommendation with the tradeoff table in RUNLOG + QUESTIONS entry if it forces a spec deviation; no code ships from the spike.
- [C-3b] (2×90m) Household sharing — one live household copy, family phones equal editors via invites Ria controls (invite/remove UI rides the Settings root, pairs with U-3); participant removal cuts access. **AC:** two-account integration verified on hardware; family wave unblocks. *(blocked by C-3a)*

## M2 — Shopping core
- [M2-1] **[DONE 2026-07-07]** (90m) Meal→items explosion — precise amounts summed, loose items listed without amounts, dedup. **AC:** TC-SL-1..5. → pure `ShoppingExplosion` service, 5 tests; GF qualifier carried for RT-6.
- [M2-2] **[DONE 2026-07-07]** (90m) Run tiers + routing — perishability/neededBy routing per spec §4 step 4. **AC:** TC-RT-1..6. → pure `RunRouting`, 6 tests; unroutable ⇒ violation for GT.
- [M2-3] **[DONE 2026-07-07]** (90m) Guarantee check v1 (no inventory) — coverage between now and next confirmed run; violation → structured result naming at-risk meals. **AC:** TC-GT-1..6. → 16 tests; adversarial review found 3 verified blockers (phantom purchases, day-vs-clock granularity, no freshness floor) — all fixed + mutation-pinned.
- [M2-4] **[DONE 2026-07-07]** (60m) Markdown + Reminders export of a run's list. **AC:** TC-SL-6; Reminders export behind permission check. → 3 tests; strictest-need-by merging (PT-7 spirit); Shopping tab UI ships with M2-5.
- [M2-5] (45m) Run skip/delay flow — recheck guarantee, produce at-risk report object (UI later). **AC:** TC-GT-7..8.
- [M2-6] (45m) Ingredient archive/retire + merge (added 2026-07-09 per D-39) — catalog ingredients get retire (hidden from pickers; recipes/history render unchanged) + merge-duplicates flow; hard delete never exposed. **AC:** retire hides from recipe-editor picker while existing references stay intact; merge re-points all six referencing edges; tests pin both (closes F19 crash class).

## M3 — Brain, part 1 (Claude NL capture) — [APPROVED 2026-07-09 (F13); reordered value-first per Ria "break it up as you see fit"]
*Tags: PROMPT-REVIEW = AI-prompt/tone task, review-gated (do not tune autonomously). NEEDS-VISUAL-REVIEW = UI. Order below = execution order.*
- [M3-1] (90m) `MoodyBrain` service layer — thin Claude tool-use client, keys from env, "what leaves the device" payload-category log, offline/failure queueing. **AC:** NL-7, NL-8; no secrets committed. PROMPT-REVIEW.
- [M3-6] (60m) Daily check-in (one-tap) — CheckIn wired, capacity Low/Med/High, skip = signal. **AC:** RM-1 (part), RM-5 groundwork. NEEDS-VISUAL-REVIEW.
- [M3-7] (60m) Capacity-aware Tonight + "just decide" — ~3 filtered picks + one-tap decide. **AC:** RM-1. NEEDS-VISUAL-REVIEW.
- [M3-2] (90m) Brain-dump → recipe (`createRecipe`) — parse messy text into Loose/Precise. *(D-44/D-45 re-scope: the same capture call assesses the recipe against ALL household food rules — GF band + per-line suggested subs, plus per-rule helps/hurts/neutral annotations with reasons; rubric pins: homemade bread→unsafe, mac-n-cheese→"which gf pasta?", tbsp flour→calm sub request; whole foods never flagged.)* **AC:** NL-3, HC-7 as re-scoped by D-44, rubric example pins as eval fixtures, rule-annotation fixtures (red-meat-heavy / iron-rich shapes). PROMPT-REVIEW.
- [M3-3] (90m) Log-by-talking + compound feedback (`logMealFeedback`) — one utterance → status + per-member liking + recency + frequency delta. **AC:** NL-1, NL-2. PROMPT-REVIEW.
- [M3-4] (60m) Meal query (`queryMeals`) — NL queries, no writes. **AC:** NL-5.
- [M3-5] (45m) Ambiguity guard — write-intent with no target asks; never guesses. **AC:** NL-6.
- [M3-8] (90m) Loves Corpus foundation — LoveItem model, editable page, conversational-capture offer, consented-observation stub, source visibility. **AC:** LOV-2, LOV-3, LOV-4. PROMPT-REVIEW + NEEDS-VISUAL-REVIEW.
- [M3-9] (60m) Stressor profile — StressorPattern model, calendar-signal matching, editable page. **AC:** STRS-5 (adaptation wiring lands M4/M5). NEEDS-VISUAL-REVIEW.
- [M3-10] (45m) Onboarding conversational seed — corpus + stressors + favorite colors; skippable/resumable. **AC:** LOV-7 palette captured. PROMPT-REVIEW + NEEDS-VISUAL-REVIEW.

## M4 — Scheduler v1 core — [APPROVED 2026-07-09 (F13); split M4/M4b per Ria "break it up as you see fit"]
*Core = produces a valid, safe week plan. Guardrails, chains & care moved to M4b (review point between).*
- [M4-0] **[TODO — D-42 answered 2026-07-09]** (2×90m — split candidate M4-0a/M4-0b) Generalize food rules + D-44 GF risk-class model (added 2026-07-09; amended twice per Ria) — **(a)** replace `DietaryRequirement`/`FoodNeedGoal` with per-member `FoodRule` per D-45 as amended — STRUCTURED record {member, direction: never/limit/boost, subject, reason, frequency window}, never freeform; assessment prompt built deterministically from rule fields; matching is generative annotation at capture (no manual tag taxonomy), output schema-validated {rule, verdict, reason}; scheduler consumes stored annotations deterministically; rule add/change ⇒ batch re-annotation; seed: Chuck limit red meat/pork ≤1×/wk; Ria boost iron/fiber/anti-inflammatory; Chad boost calorie-dense; Elsie NO rule (D-35 objective + scores + staples carry the end goal); rule-filterable recipe/ingredient views from stored annotations. **(b)** replace tri-state `isGlutenFreeVerified` with D-44 (as thrice-refined): recipe-level band {safe | awaitingSubstitution | unsafe | notCheckedYet} assigned by GENERATIVE ASSESSMENT via MoodyBrain at capture/edit (one call, result stored; rubric = Ria's bread/mac-n-cheese/tbsp-flour examples; PROMPT-REVIEW; offline → notCheckedYet + queue; *depends on M3-1/M3-2*), per-line suggested subs, Ria's overrides permanent and outranking re-assessment, per-ingredient preferred brand, per-recipe standard modifications, HOUSEHOLD standard substitutions with bulk-apply checklist (full preview names every recipe + exact line changing; per-recipe subs override household defaults), "awaiting substitution" indicator calm per design law #4, unsafe tier nuclear (aligns w/ HC-9 flour line); shopping list carries sub/preferred brands (RT-6 pipe); migration = batch assessment of existing recipe box → first-pass triage view. Per-person CHIPS per D-46 (❤️ from scores/all-timer; ✅/❌ from stored annotations vs each member's rules) on meal list/detail/picker + serves-X/loved-by-X filters; steak-and-potatoes example pinned as a test. **AC:** §1 REWRITTEN to D-44 invariants and submitted for Ria's sign-off before old tests are deleted (never silent); whole-food-never-prompts; awaiting-substitution is SCHEDULABLE incl. Caddie nights (badge rides to plan/Tonight; shopping line carries substitution-needed qualifier) while UNSAFE is excluded from auto-fill and keeps HC-5 warn-confirm on manual assignment; D-44 example pins: homemade-bread→unsafe, mac-n-cheese→calm question, tbsp-flour-in-20→calm question; sub-or-brand-documented ⇒ safe with indicator fully cleared; bulk-apply clears N ticked recipes in one action while unticked keep the flag; migration emits a reviewable first-pass triage (unsafe / awaiting-substitution piles, everything visible); manual band/profile overrides persist and outrank re-scores; add-a-rule-at-runtime (new restriction honored with zero code change). NEEDS-VISUAL-REVIEW (rule/brand/sub/bulk/triage UI).
- [M4-1] (90m) `TuningConfig` singleton + Fine-tuning settings — all §8 keys w/ defaults, plain-language sliders, reset-to-default; tests read config not literals. Adds keys per D-33/D-34/F7/F8 **if approved**. **AC:** every §8 tunable present. NEEDS-VISUAL-REVIEW.
- [M4-2] (90m) Hard filter (Step 1/1c) — exclude hard-req violations vs attendees, non-active rotation, notToday; GF verified-rule; all-timers exempt. **AC:** HC-1, HC-2, HC-3, SCH-14, ATF-2.
- [M4-3] (90m) Scoring engine (Step 3) — weighted score(m,d) from TuningConfig weights. **AC:** SCH-1, SCH-2, SCH-3, SCH-4.
- [M4-5] (90m) Anchors (Step 2) — ThemeAnchor fill + variety rotation. **AC:** ANC-1..4.
- [M4-6] (90m) Cooldown & rotation (Step 5) — "sick of this" → resting + refill; auto-return; retired stays out. **AC:** CD-1..5, ATF-1.
- [M4-7] (60m) Frequency + recency + locks (Step 4) — no repeat in recency window; frequency pressure; locks immovable. **AC:** SCH-5, SCH-8.
- [M4-12] (60m) Cold-start reduced mode (Step 4f) — frequency+effort+hard only until signal; labeled; onboarding swipe pass. **AC:** PT-1.
- [M4-14] (60m) Reactivity + 12-month horizon — re-score today+tomorrow only; horizon gen; near-term syncs; novelty dial. **AC:** SCH-7, SCH-9 *(needs F7)*, SCH-12.

## M4b — Scheduler guardrails, chains & care — [split approved 2026-07-09]
- [M4-4] (60m) Method affinity (D-28) — per-cook affinity; loved method NEVER nannied. **AC:** MTH-1, MTH-2 ⚠️, MTH-3.
- [M4-8] (90m) Fit-coverage guardrails (Step 4) — boost-rule coverage per D-45 annotations (iron, calorie-dense, etc. ≥ per-rule windows); patch lowest-margin; warnings. **AC:** SCH-10, SCH-11 generalized per D-45.
- [M4-9] (90m) Leftover chains (Step 1d/4a2) — requiresComponents placement, pull-in producer, leftover InventoryItem+useBy, busy-night bonus. **AC:** LC-1..5, SCH-17, PT-10. *(depends on D-33)*
- [M4-10] (60m) Fairness floor (Step 4d) — per-tier windows per D-17 (2026-07-09): −2 ≤ once/14 days, −1 ≤ once/7 days per person, never consecutive; the two window keys land in TuningConfig at M4-1 (supersede `dislikeFloorPerWeek`). **AC:** PT-2 re-parameterized per D-17.
- [M4-11] (60m) Cook nights + servings (Step 4c) — kid anchors, likesToCook, portions = Σ appetiteBase + favorite boost. **AC:** SCH-15, SCH-16.
- [M4-13] (60m) Calm-day gate + calendar conditions (Step 1b/4b) — requiresCalmDay eligibility; user-editable signal→rule maps; Wednesday b4d anchor seeded OFF. **AC:** SCH-6 + condition-gate tests.
- [M4-15] (45m) Signature floor (4g) + joy-cooking invite (4h) — memory reps; invitation register. **AC:** ATF-5, ATF-6, ATF-7. PROMPT-REVIEW (invite copy).
- [M4-16] (90m) Stressor-day assistance (4e) — per D-43 as refined: on a declared stressor match OR a sudden calendar-load spike (rides SCH-7/PT-6 reactivity), compute ONE concrete reasoned suggestion — best plan-preserving swap or low-effort alternative, with named stakes (displaced meal's enjoyment, prep-time window, who it delights) — surfaced one-tap-acceptable, never auto-applied; swap + "just decide" affordances lead; cook-nights never auto-move (D-18); PT-9's no-fault streak pause stays. **AC:** STRS-1..3 as re-scoped by D-43; PT-9 as re-scoped by D-18; suggestion-never-auto-applies test. Suggestion copy is PROMPT-REVIEW (pairs with M5-3's EQ register). NEEDS-VISUAL-REVIEW.

## M5 — Notification infra, reminders & EQ core — [APPROVED 2026-07-09 (F13); split M5/M5b/M5c per Ria]
*Nearly all tasks PROMPT-REVIEW.*
- [M5-1] (90m) Notification infra — UNUserNotificationCenter scheduling, persisted history (survives relaunch), quiet/snooze plumbing. **AC:** NT-6.
- [M5-2] (90m) Tonight reminder generation — fresh copy, varied emoji/phrasing/time; JIT pre-gen; offline bank. **AC:** NT-1, NT-2, NT-10, PT-3, PT-4. PROMPT-REVIEW.
- [M5-3] (90m) EQ engine core (§7b) — decide need/channel/format from read-the-room; one tiny step + named stakes; ⚠️ shame-audit. **AC:** NT-11, NT-12, NT-13. PROMPT-REVIEW. *(D-43: ignored-notification count + time-since-app-open are the PRIMARY read-the-room inputs, ahead of calendar prediction.)*
- [M5-14] (60m) Shopping escalation (D-3) — normal→"for real" w/ named stakes; snooze ≤7d auto-return; NEVER mutes §1 safety. **AC:** GT-8, GT-9, GT-10, GT-11 ⚠️, NT-4. PROMPT-REVIEW.
- [M5-15] (45m) Check-in modality rotation + quiet-down — oneTap/textStyle/voice; `quietDownAfterSkips`. **AC:** NT-3, NT-5, RM-2.
- [M5-16] (45m) Unresolved-recipe nudges (added 2026-07-09, D-44 fourth refinement + D-45) — a scheduled meal in awaitingSubstitution/notCheckedYet gets a time-bound nudge stream keyed to the covering run's need-by, then cook time; each nudge LEADS with a generated recommended resolution ("Jovial holds up in baked mac & cheese") with one-tap accept, alternates behind it; resolution silences immediately; EQ/tone rules apply. **AC:** nudge-fires-before-run-need-by; recommendation-first copy; one-tap-resolve-updates-shopping-line; resolved ⇒ silent; test IDs assigned in the D-44 §1/NT rewrite. PROMPT-REVIEW (nudge copy).

## M5b — Personas & the presentation envelope — [split approved 2026-07-09]
- [M5-4] (90m) Persona cast + co-creation (D-21/26) — Persona model, 2+2 onboarding, roles (Noticer/Never-Left/Hype/Kindred), stylized avatars. **AC:** NT-18, NT-20b, NT-21. PROMPT-REVIEW + NEEDS-VISUAL-REVIEW.
- [M5-5] (90m) Presentation Envelope + communication-style notifications (D-20) — {persona,channel,visual,sound,copy} tuple; intent donation; palette from loves. **AC:** NT-14, NT-15, NT-16. NEEDS-VISUAL-REVIEW.
- [M5-6] (90m) Habituation Horizon enforcement (D-21/22) — `dimensionConstancyMaxDays`, `habituationHorizonDays`, quarter-hour ban, near-dup rejection. **AC:** NT-19, NT-22 ⚠️, NT-24, NT-17.
- [M5-7] (60m) Persona rituals + rest/return (D-22) — ritual windows, jittered minutes, non-daily; personas rest & return. **AC:** NT-20, NT-23.
- [M5-8] (90m) Re-entry choreography (D-23/24) — Noticer→Never-Left→Hype; ⚠️ gap-blindness audit; Kindred; group thread. **AC:** NT-25, NT-26 ⚠️, NT-27, NT-28, NT-29, NT-30, NT-31 ⚠️. PROMPT-REVIEW.
- [M5-9] (60m) Meme follow-up (D-9) — one follow-up after `memeFollowUpDelayHours`, user pack, no repeat 30d, then silence. **AC:** NT-7, NT-8, NT-9.

## M5c — Streaks, rewards & the Vent — [split approved 2026-07-09]
- [M5-10] (90m) Streaks (§7c, D-13) — process-only, bend-don't-break, never-zero, comeback>continuation, freeze tokens; ⚠️ no intake streaks. **AC:** STRK-1..8. NEEDS-VISUAL-REVIEW.
- [M5-11] (60m) Reward menu (§7c2, D-14) — RewardItem model, bidirectional pairing, tier match, rate limit, zero injected commerce. **AC:** RWD-1..6 ⚠️. PROMPT-REVIEW + NEEDS-VISUAL-REVIEW.
- [M5-12] (60m) Loves-driven generation (§7d) — corpus refs in generated content; rotation/cooldown; never weaponized. **AC:** LOV-1, LOV-5, LOV-6 ⚠️. PROMPT-REVIEW.
- [M5-13] (60m) The Vent (§7c3, D-25) — voice-first dump, listener register, ⚠️ isolation covenant, local-only mode, one consented follow-up, never punitive. **AC:** VNT-1..6 ⚠️. PROMPT-REVIEW + NEEDS-VISUAL-REVIEW.

## M6 — Inventory + photos — [APPROVED 2026-07-09 (F13)]
- [M6-1] (90m) Photo → vision → structured items (`reconcileInventory` p1) — item list + flaggedUnclear. **AC:** INV-1. PROMPT-REVIEW.
- [M6-2] (60m) Photo privacy gate — person detected → retake/crop; crop is what ships. **AC:** PT-5 ⚠️.
- [M6-3] (90m) Reconciliation conversation — resolve unclear, raise confidence. **AC:** INV-2. PROMPT-REVIEW.
- [M6-4] (60m) Confidence + decay — `inventoryDecayHalfLifeDays`; auto-drop below 0.7. **AC:** INV-3.
- [M6-5] (60m) Passive updates — run completion upserts; eaten decrements/decays. **AC:** INV-4, INV-5.
- [M6-6] (45m) Never-blocking + cook-what-I-have — zero-data flows work; ≥0.7 proposals. **AC:** INV-6, INV-7.
- [M6-7] (90m) Guarantee check v2 (inventory-aware) — subtract beliefs ≥`inventoryConfidenceThreshold`. **AC:** GT-4; re-verify GT-1..3 with inventory.
- [M6-8] (60m) Waste logging (§18) — WasteEvent via one sentence; reflection surfacing + actions; ⚠️ no guilt copy. **AC:** WST-1..5. PROMPT-REVIEW (WST-5).

## M7 — Breakfast + LUNCH (D-40) + snacks — [APPROVED 2026-07-09 (F13)]
- [M7-1] (60m) Per-member breakfast default — currentBreakfast resolves; zero daily entries; graceful nil (DM-6). **AC:** BF-1, DM-6. NEEDS-VISUAL-REVIEW. *(D-40: currentLunch model landed early; M7-1/2 cover lunch defaults + burnout with the same ACs applied to lunch.)*
- [M7-2] (60m) Breakfast burnout swap — per-person cooldown, 2–3 alts, new default; rest cycles back. **AC:** BF-2, BF-3, BF-5.
- [M7-3] (45m) Breakfast staples on cadence — source `breakfastStaple` onto runs. **AC:** BF-4.
- [M7-4] (60m) Snack cadence inference — from PurchaseRecords; `snackInferenceMinPoints`. **AC:** SN-1, SN-5.
- [M7-5] (60m) Snack replenishment — cadence→run, dedup, run-out flag, manual override. **AC:** SN-2, SN-3, SN-4, SN-6.

## M8 — Occasions, all-timers, HomePod — [APPROVED 2026-07-09 (F13)]
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
- *(cleared 2026-07-07 per D-32 — Q1/Q2/Q4/Q5 were already canon via D-1/D-5/D-2/D-3; M0-4 unblocked. Q3 closed 2026-07-09 — Liking/Fit stays −2…+2 per Ria's live approval. Nothing currently blocked; the Wednesday question dissolved 2026-07-09 per D-47 — seed data is disposable, nothing awaits Ria.)*
