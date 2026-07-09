# TEST_CASES.md — Moody test bank (for Ria's review)
Derived from the requirements + build spec. Format: **ID — Given / When / Then.** Household: Ria, Chuck, Caddie (GF-celiac, hard), Elsie (meat-averse, protein+veg+starch), Chad (14, high-calorie goal).
Sections marked ⚠️ are safety-critical: a red test here halts feature work.

## §1 ⚠️ Hard constraints (dietary safety)
*(D-44 2026-07-09: this section is scheduled for REWRITE at M4-0 — the unverified⇒unsafe tri-state model (HC-3, HC-4, HC-6, HC-7 as written) is retired in favor of Ria's risk-class model: whole foods safe with no marking; gluten carriers need a recorded per-recipe substitution; packaged goods carry optional preferred brands and are safe by default. HC-1/2/5/8/9/10 survive. The rewritten §1 goes to Ria for sign-off BEFORE old tests are deleted; the shipped app keeps the current, more conservative behavior until M4-0 lands.)*
- **HC-1** — Given Caddie attends dinner / When the scheduler fills any slot / Then no meal containing a gluten ingredient is ever selected, regardless of score.
- **HC-2** — Given a meal scores maximum Liking+Fit for all five members but contains regular soy sauce (gluten) / When scheduling with Caddie attending / Then it is excluded (optimization can never outrank a hard constraint).
- **HC-3** — Given an ingredient with `isGlutenFreeVerified == nil` (unverified) / When evaluating meal safety for Caddie / Then the meal is treated as UNSAFE (unverified = unsafe for GF members).
- **HC-4** — Given "crispy" frozen fries marked unverified / When they appear in a meal / Then the meal is flagged for label verification before it can be scheduled with Caddie attending.
- **HC-5** — Given a user manually assigns a gluten meal to a night Caddie attends / When saving the PlanEntry / Then the app warns explicitly and requires confirmation (manual override allowed, silent never).
- **HC-6** — Given a Loose recipe with nil amounts including one unverified ingredient / When safety is evaluated / Then unverified status propagates to the meal (amounts irrelevant to safety).
- **HC-7** — Given NL input creates a new recipe "beer-battered fish" / When parsed / Then gluten-containing ingredients default to unverified/unsafe, never silently verified.
- **HC-8** — Given a meal is edited to add a gluten ingredient / When it already sits on future PlanEntries with Caddie attending / Then those entries are flagged and re-fill is proposed.
- **HC-9** — ⚠️ THE FLOUR LINE (dual rationale): no surface of the app ever suggests from-scratch wheat baking or raw wheat-flour work at home — (1) aerosolized contamination, (2) never baking something super delicious Caddie can't have. Packaged gluten items (bread, buns, crackers) remain normal purchases, tagged not-Caddie-safe. GF-mix baking (King Arthur GF standard) fully suggestible.
- **HC-10** — Inclusion check on special deliciousness: any app-suggested celebratory/special/aromatic home-cooked item (occasion menus, joy-cooking, Signature bakes) must be Caddie-safe when she lives here — mundane contained gluten passes; exclusionary showstoppers never generate.

## §2 Per-member safe foods & "not today"
- **SF-1** — Given GF mac & cheese is `isSafeFood` for Chad only / When asking "what's safe for Chad tonight" / Then it returns Chad's safe list, not a household list.
- **SF-2** — Given a meal safe for Chad but not Elsie / When rendering the Tonight view / Then safety badges show per person.
- **SF-3** — Given Caddie marks tacos "not today" / When scheduling this week / Then tacos are excluded while her `notTodayUntil` is active, but remain available once it lapses.
- **SF-4** — Given a per-person "not today" on a meal / When another member queries their own safe foods / Then the meal still appears for them.
- **SF-5** — Given a safe food flips to "not today" mid-week and it was Thursday's dinner / When the flip is saved / Then Thursday is re-filled automatically with an alternative.

## §3 Data model integrity
- **DM-1** — A meal composed of two recipes + one direct ingredient + freeform notes persists and round-trips.
- **DM-2** — A Loose recipe with ingredients and no amounts persists; shopping explosion lists items without quantities.
- **DM-3** — A meal with zero recipes ("Chipotle takeout") is valid, plannable, and contributes zero shopping items unless direct items exist.
- **DM-4** — A Precise recipe missing an amount on one item is either rejected or auto-downgraded to Loose (decision test — surfaces the rule).
- **DM-5** — Deleting a meal cascades its MemberMealScores but never deletes the shared Ingredients.
- **DM-6** — `currentBreakfast` referencing a deleted meal degrades gracefully (nil, prompt to pick anew).

## §4 Scheduler — scoring & optimization
- **SCH-1** — Given two candidate meals, equal except meal A has higher summed Liking / Then A is chosen.
- **SCH-2** — Given meal A leads on Liking, meal B on Fit, weights equal / Then combined score decides; raising wF flips the choice to B (weighting works).
- **SCH-3** — Given a meal eaten 3 days ago with a 21-day recency window / Then its recency penalty prevents re-scheduling this week absent user lock.
- **SCH-4** — Given a meal with `frequencyTarget = weekly` not scheduled in 10 days / Then frequencyPressure boosts it above an otherwise-equal meal.
- **SCH-5** — Given "we should eat curry more often" raises curry's frequency target / Then the next horizon fill schedules curry more often — but never twice inside its recency window.
- **SCH-6** — Given Thursday's calendar is dense (inferred low capacity) / Then only `noCook`/`assembly`/`simple` meals fill Thursday.
- **SCH-7** — Given today's check-in says low capacity / Then today+tomorrow re-score; entries beyond tomorrow do NOT churn.
- **SCH-8** — Given a locked PlanEntry / When the scheduler re-fills the horizon / Then the locked entry never moves.
- **SCH-9** — Given the novelty dial at max comfort / Then new/underused meals rarely surface; at max adventurous, a never-scheduled meal appears within the next 2 weeks.
- **SCH-10** — Weekly Fit coverage: given Ria's hemeIron goal and an iron-forward meal pool / Then any generated week contains ≥2 iron-forward dinners, patched by swapping lowest-margin slots if the greedy fill missed.
- **SCH-11** — Given Chad's highCalorie goal / Then generated weeks keep ≥N calorie-dense meals (threshold configurable); dropping below produces a coverage warning.
- **SCH-12** — 12-month horizon: generation completes, only near-term (≤4 weeks) syncs to EventKit, far entries stay internal.
- **SCH-13** — Elsie's lifeline (REVISED per Ria): sandwich basics + garbanzo beans are StapleItems, permanently covered by the shopping guarantee — if stock belief drops below min, they appear on the very next run, no matter what's planned.
- **SCH-14** — Attendance: with Caddie absent from Friday's attendees, gluten meals are eligible Friday and `caddie-away-special` meals get a bonus; the moment she's re-added, HC-1 applies again in full.
- **SCH-15** — Servings scale: burgers (Chad liking +2) for all 5 → portions = 4×1.0 + 2.0 = 6.0; shopping amounts scale to match (two 1/3-lb burgers for Chad is the norm, not a surprise).
- **SCH-16** — Cook night: Caddie's Tuesday fills only from meals where her `likesToCook == true` AND all-attendee-safe.
- **SCH-17** — Busy-night hero: on a dense day, fried rice (requiresComponents satisfied, effort simple) outranks an equal-scoring involved meal; the leftover chain's payoff lands on the low-capacity night.

## §5 Rotation, cooldown & return
- **CD-1** — "Everybody's sick of this" → state `resting`, `cooldownUntil` set, all future unlocked PlanEntries with it re-filled immediately.
- **CD-2** — Given `cooldownUntil` passes / Then the meal returns to `active` automatically and becomes schedulable — no user action.
- **CD-3** — A rested meal never appears in suggestions, "just decide," or auto-fill during cooldown.
- **CD-4** — `retired` meals never return automatically; they remain findable in the library.
- **CD-5** — Given a rested meal is an anchor-theme member (taco meal resting) / Then the anchor fills from other theme meals; if the theme pool empties, a coverage prompt fires (see §13).

## §4b Method affinity (D-28)
- **MTH-1** — With Ria as cook (grill +2, oven −2), an equal-scoring grill meal beats an oven meal decisively; over a month, grill meals outnumber oven meals heavily on her cook nights.
- **MTH-2** — ⚠️ Never nannied: a forecast of 102° neither removes nor down-weights a loved-method meal; generated copy may salute the heat but contains no discouragement, no "are you sure," no swap suggestion.
- **MTH-3** — Method affinity is per-cook: on Caddie's cook-night, HER affinities weight selection, not Ria's.
- **MTH-4** — Joy-cooking invitations can target a loved method ("a grill project Saturday?"); avoided-method meals appear only when constraints force it, with the reason stated.

## §5b Leftover chains
- **LC-1** — Fried rice (`requiresComponents: ["cooked rice"]`) can't be placed Wednesday unless a rice-producing meal sits Mon/Tue (within freshness window).
- **LC-2** — Scheduling fried rice Wednesday auto-proposes pulling a rice producer into Tuesday if none exists.
- **LC-3** — Marking Tuesday's rice meal eaten spawns a leftover InventoryItem ("cooked rice", useBy = +2 days).
- **LC-4** — If the producer gets swapped out, the dependent consumer is flagged and re-fill proposed — never left silently broken.
- **LC-5** — Leftover items past useBy stop satisfying `requiresComponents` and surface as waste-risk prompts.

## §6 Themed anchors
- **ANC-1** — Given an active Taco Tuesday anchor / Then every Tuesday dinner is a `mexican`-tagged meal.
- **ANC-2** — Given `varietyPeriodWeeks = 3` / Then the specific Tuesday meal changes at least every 3 weeks while remaining in-theme.
- **ANC-3** — Deactivating an anchor releases future Tuesdays to normal scheduling without touching past entries.
- **ANC-4** — An anchor never overrides a hard constraint: if the only in-theme meal is unsafe for an attendee, the anchor slot falls back to normal fill + coverage prompt.

## §7 Breakfast — the opposite pattern
- **BF-1** — Given Chad's `currentBreakfast` is set / Then every morning resolves to it with zero decisions and no daily PlanEntries required.
- **BF-2** — "I'm sick of this breakfast" (per person) → old default goes to cooldown, 2–3 alternatives offered, chosen one becomes the new default.
- **BF-3** — A breakfast resting for Chad remains Elsie's active default if she uses the same meal (cooldown is per-person here).
- **BF-4** — The current breakfast's staples auto-appear on shopping runs at cadence (source `breakfastStaple`) so mornings never hit empty.
- **BF-5** — A rested breakfast cycles back into the alternatives list after cooldown (we come back to things).

## §8 Shopping list explosion
- **SL-1** — Two precise recipes both needing onions (1 + 2) → one line: onions ×3.
- **SL-2** — A loose item ("some cilantro") merges with a precise amount of the same ingredient → listed with the precise amount + "plus extra" marker (dedup without losing intent).
- **SL-3** — Freeform meals contribute nothing unless direct items exist.
- **SL-4** — Pantry-staple exclusion list (oil, salt, pepper, butter, taco seasoning) is honored unless the item appears in inventory as out.
- **SL-5** — Date-range explosion covers exactly the PlanEntries in range — no leakage from adjacent weeks.
- **SL-6** — Markdown export round-trips: every uncovered item appears once, grouped by run, readable plain text.

## §9 Run routing
- **RT-1** — Fresh cod needed Thursday → routed to the latest run before Thursday that accepts `freshShort` (weekly or midweek), never bulk.
- **RT-2** — Milk → midweek run by default (freshShort + cadence).
- **RT-3** — Frozen GF nuggets needed in 3 weeks → bulk (Costco) run eligible and preferred.
- **RT-4** — An item needed BEFORE the next eligible run → guarantee violation raised (feeds §10), not silently dropped.
- **RT-5** — `preferredRunTier` override on an ingredient beats inference.
- **RT-6** — GF specialty items carry their dietary qualifier through to export text (e.g. "gluten free chicken tenders frozen") for cleaner store search.

## §10 ⚠️ Shopping guarantee
- **GT-1** — Given all runs done as planned / Then every PlanEntry until the next confirmed run has all items covered — the invariant holds on the happy path.
- **GT-2** — Given Thursday needs cod and no run before Thursday carries it / Then the check names Thursday's meal, the missing item, and proposes: swap the meal OR add a mini-run.
- **GT-3** — Skipping the weekly run triggers an immediate re-check listing exactly the at-risk meals and their dates.
- **GT-4** — Inventory at confidence 0.9 says rice is on hand → rice omitted from the list. Same belief at 0.5 → rice bought anyway (0.7 threshold).
- **GT-5** — Nightly check produces no false alarms when coverage is complete (alert fatigue kills the system).
- **GT-6** — Adding a meal to tomorrow after this week's run already happened → instant guarantee check on save, immediate flag if uncovered.
- **GT-7** — Delaying a run by 2 days re-evaluates only the affected window.
- **GT-8** — Escalation state machine: normal reminder → (run still skipped + meals at risk) → "for real" escalation with named stakes → never repeats identical copy twice (novelty hook, §14).
- **GT-9** — "For real, shut up": user snooze silences all shopping escalation immediately for N days (N ≤ escalationSnoozeMaxDays).
- **GT-10** — A snoozed escalation auto-reactivates when the snooze expires (≤7 days) with a fresh (novel) re-entry message — never silently stays off.
- **GT-11** — Snooze never suppresses §1 dietary-safety warnings; only shopping escalation is muted.

## §11 Snacks & replenishment
- **SN-1** — Given Cojack sticks purchased on days 0, 5, 11, 16 / Then inferred cadence ≈ 5 days (±1) and `cadenceIsInferred = true`.
- **SN-2** — Manual cadence override sets `cadenceIsInferred = false` and stops re-inference from overwriting it.
- **SN-3** — Given cadence 5 days and last purchase 6 days ago / Then the snack auto-appears on the next eligible run (source `snackCadence`).
- **SN-4** — A snack favorited by Chad and Elsie appears once on the list, not twice.
- **SN-5** — Two data points or fewer → no inference (insufficient history), no phantom cadence.
- **SN-6** — A likely run-out (cadence says empty before next run) → included on the *earlier* run or flagged.

## §12 Inventory (belief, not ledger)
- **INV-1** — Photo analysis returns 12 identified items + 3 unclear → 12 upserted at stated confidence, 3 created `flaggedUnclear` and queued for the reconciliation convo.
- **INV-2** — Reconciliation answer "that's leftover chili, half a container" updates label, quantity, and raises confidence.
- **INV-3** — Confidence decays with time since `lastConfirmedAt`; after the decay horizon an item drops below the 0.7 guarantee threshold automatically.
- **INV-4** — Completing a shopping run upserts purchased items into inventory at high confidence.
- **INV-5** — Marking a meal `eaten` decrements its precise ingredients' inventory beliefs; loose ingredients decay confidence instead of quantity.
- **INV-6** — Inventory is never blocking: with zero inventory data, all flows work (buy everything).
- **INV-7** — "Cook what I have" only proposes meals whose items are all ≥0.7 confidence on hand.

## §13 Coverage / pool health
- **CV-1** — Given the "meals Elsie likes" pool drops below threshold (e.g. <5 active) / Then a prompt suggests searching/adding meals meeting that criterion.
- **CV-2** — Given iron-forward active meals < needed for Ria's weekly coverage / Then a pool-health prompt fires before the scheduler starts failing SCH-10.
- **CV-3** — Cooldowns count against the pool: resting meals don't count as available.
- **CV-4** — Pool prompts route into NL search ("find GF iron-rich dinners everyone might like").

## §14 Notifications & novelty (the load-bearing kind)
- **NT-1** — Ten consecutive tonight-reminders: no two use identical copy; emoji and phrasing rotate.
- **NT-2** — Reminder time varies within the allowed window across a week (not the same minute daily).
- **NT-3** — Check-in modality rotates across `oneTap` / `textStyle` / `voiceConversational` with no fixed cycle.
- **NT-4** — Escalation notifications visibly differ in tone/structure from routine reminders.
- **NT-5** — A skipped check-in generates NO nag follow-up; the skip is recorded as signal (RM-2).
- **NT-6** — Notification history persists so novelty constraints are enforceable across launches.
- **NT-7** — Emotionally intelligent follow-up: an unactioned dinner alert after `memeFollowUpDelayHours` triggers ONE friendly meme follow-up (image from the user-curated meme pack + rotating warm caption, "Hey girl… I know you want a yummy meal" energy) — never a sterner repeat of the original.
- **NT-8** — Meme follow-ups never repeat the same image+caption pair within 30 days; pack is user-managed (user supplies images).
- **NT-9** — After the meme follow-up, silence = signal: no third touch that day; RM-2 quiet-down logic takes over.
- **NT-10** — Generative, not templated: 30 consecutive notifications contain no reused body text; channel/format distribution shows real variety (no single format >50%).
- **NT-11** — Tone matches state: suspected slump → generated messages measurably shift toward warm/humorous/low-ask; high-capacity streak → permits playful kick-in-the-pants. Never shame in any state (automated shame-audit on generated copy: no guilt framings, no "you failed/again/still haven't").
- **NT-12** — Every generated nudge contains at most ONE concrete next step and, where urgency is used, a real named stake — never vague pressure.
- **NT-13** — Slump mode raises novelty: format/genre switching frequency increases vs. baseline when slump is suspected.
- **NT-14** — Envelope uniqueness: no two consecutive messages share the same {persona, channel, visual-kit} combination; over 14 days, ≥4 distinct personas and ≥3 distinct channels appear.
- **NT-15** — Communication-style rendering: persona messages display sender name + avatar (donated intent), visually distinct from standard app notifications.
- **NT-16** — Visual kit samples the user's declared color palette when present; attached images rotate with no repeat inside their cooldown.
- **NT-17** — Envelope history survives relaunch; a near-duplicate envelope generated within the novelty window is rejected and rebuilt before scheduling.
- **NT-18** — Stable cast: over 30 days, messages come from the SAME 3–5 co-created personas (no drive-by strangers); each persona's voice/avatar stays consistent across its messages.
- **NT-19** — Habituation guard: no envelope dimension (persona, timeslot, channel, visual family) holds constant beyond `dimensionConstancyMaxDays`; no full pattern (persona+timeslot+channel) recurs within `habituationHorizonDays`.
- **NT-20** — Personas rest and return: a persona can go quiet for a stretch and reappear with continuity ("back from the in-laws!"); a resting persona sends nothing until its return.
- **NT-20b** — 2+2 grounding: onboarding proposes the two-real/two-fictional cast composition with a plain explanation of why; the user can override freely; real-person-inspired personas default to stylized avatars and are framed as "inspired by," never as the person.
- **NT-21** — Cast co-creation: onboarding produces user-approved personas (names, relationships, vibes editable); the user can retire/replace a cast member anytime and the replacement enters rotation seamlessly.
- **NT-22** — ⏰ Quarter-hour ban: across ALL scheduled envelopes, zero deliveries at :00/:15/:30/:45; sampled minutes skew organic (≥80% not multiples of 5). 9:17 ✓, 3:22 ✓, 10:00 ✗, 4:15 ✗.
- **NT-23** — Persona rituals: the chef's fresh-idea messages land inside her AM window with market/fish-forward content; the booster's quick-meal beat lands mid-afternoon; window minutes jitter, days-of-week vary, and no ritual fires daily (`personaRitualFreqPerWeek` respected).
- **NT-24** — Rituals × habituation: a ritual window is a stable character trait, but the full pattern (persona+day+channel) still never repeats within the Habituation Horizon — verified over a 30-day simulation.
- **NT-25** — The Noticer fires first: on slump suspicion, the initial touch comes from the Noticer persona in warm zero-ask register (no task, no question requiring action) — before any escalation or reminder logic.
- **NT-26** — ⚠️ Gap-blindness audit: post-gap messages from the Never-Left persona contain zero absence references — no "welcome back," "been a while," "miss you," "where have you been," no streak/pause mentions. Automated audit on generated copy; violation → regenerate.
- **NT-27** — Re-entry choreography order: Noticer (during slump) → Never-Left ordinary continuity (on first return activity) → Hype comeback celebration + reward (only after re-engagement, e.g. ≥2 interactions) — and the celebration NEVER comes from the Never-Left persona.
- **NT-28** — The Kindred: disappears from rotation as character behavior and returns self-gap-blind; iykyk register passes the shame audit (recognition, never mockery); on Ria's own return, a solidarity reveal is permitted ("wasn't the only one") — the ONLY sanctioned oblique gap reference, and only from the Kindred, only about themselves.
- **NT-29** — Group thread: renders as a named group conversation (communication notifications); personas cross-reply with consistent voices; ambient messages contain no ask; overheard-content delivery works (a recipe arrives via persona-to-persona exchange).
- **NT-30** — Group budget: a chatter burst delivers as ONE grouped touch; group messages respect quiet mode, snooze, and stressor-day suppression; user can mute the thread and 1:1 personas continue unaffected.
- **NT-31** — ⚠️ Absence-talk ban: group content post-gap contains zero references to Ria's absence or inactivity (automated audit; violation → regenerate). Lurk-reads are logged as engagement signal for read-the-room.

## §15 Read the room
- **RM-1** — Low-capacity check-in → Tonight offers the user's per-member safe/fallback meal first and reduces questions asked.
- **RM-2** — Two consecutive skipped check-ins + ignored notifications → the app quiets (fewer, gentler prompts) rather than escalating.
- **RM-3** — A week of swaps-to-low-effort on dense days → weekly reflection proposes lowering default effort on dense days; accepting adjusts scheduler weights.
- **RM-4** — Weekly reflection is generated from real data (statuses, swaps, waste, check-ins) and is editable; edits persist as canon.
- **RM-5** — Calendar density fallback: no check-in today → capacity inferred from event count/spread, else defaults medium.

## §16 Natural language (Claude API) — parsing contracts
- **NL-1** — "We had tacos tonight, Chad loved it, Elsie skipped" → tacos PlanEntry `eaten`; Chad liking +; Elsie status recorded; recency updated. One utterance, three writes.
- **NL-2** — "This was perfect, everyone liked it, we should eat curry more often" → all members' liking + on curry AND frequency target raised. Compound feedback in one shot.
- **NL-3** — Brain-dump: "my white chicken chili: chicken thighs, white beans, green chiles, cumin, that GF broth" → Loose recipe, 5 items, no amounts, broth marked GF-verified only if it names a verified pantry item.
- **NL-4** — "Swap Thursday for something low-effort" → Thursday re-filled with effort ≤ simple, hard constraints intact.
- **NL-5** — "What's iron-heavy that everyone likes?" → query returns meals ranked by iron-fit + household liking; no writes.
- **NL-6** — Ambiguity guard: "make it more often" with no meal in context → the app asks which meal; it never guesses a write target.
- **NL-7** — Payload minimization: a shopping-list parse request contains no health-profile fields (verify request construction).
- **NL-8** — API failure/offline → the action queues or degrades to manual entry; no data loss, no crash.

## §17 HomePod / App Intents
- **HP-1** — "What's for dinner?" returns tonight's meal by voice with no app open.
- **HP-2** — "Add milk to the midweek run" creates a ShoppingItem routed midweek.
- **HP-3** — "We're having leftovers instead" sets tonight's entry to swapped/leftovers.
- **HP-4** — "Log that we tossed the spinach" creates a WasteEvent.
- **HP-5** — Each intent accepts ≥3 natural phrasings (no magic words).

## §18 Waste → learning
- **WST-1** — One-sentence log ("tossed half the spinach again") creates a WasteEvent linked to the spinach ingredient.
- **WST-2** — Three spinach WasteEvents in 3 weeks → weekly reflection surfaces it with options: smaller quantity / frozen swap / midweek routing / stop auto-adding.
- **WST-3** — Accepting "buy less" reduces future list quantities for that ingredient.
- **WST-4** — Accepting "route fresher" moves it to midweek runs.
- **WST-5** — Waste surfacing copy contains no guilt framing (copy-review test, human-checked).

## §19 Occasions & all-time favorites
- **OCC-1** — Caddie's birthday on the calendar → planning prompt ~3 weeks ahead.
- **OCC-2** — An occasion menu's special ingredients route onto runs early enough for the date (lead-time beats cadence).
- **OCC-3** — Last Thanksgiving's saved menu loads as this year's starting draft.
- **OCC-4** — Occasion planning NEVER proposes an `isEatingOut` meal (eating out is nuclear; special occasions don't plan for it).
- **OCC-5** — `isEatingOut` meals never appear in auto-schedule or "just decide"; they surface only in manual/emergency swap flows.
- **ATF-1** — An all-time favorite can NEVER enter cooldown — "sick of this" on it requires explicit confirmation and downgrade first.
- **ATF-2** — The scheduler's recency/frequency penalties never suppress an all-timer suggested for its occasion.
- **ATF-3** — "What are Chad's all-timers?" returns his core-memory meals with their notes.
- **ATF-4** — Occasion suggestion surfaces the right member's all-timers (Elsie's first-day-of-school dinner appears when school start nears).
- **ATF-5** — Signature floor: a meal marked Signature recurs ≥ `signatureFloorPerQuarter` per quarter; if the horizon fill misses it, a patch pass adds it on a suitable (calm-enough) night.
- **ATF-6** — Legacy transfer: a Signature can be paired with a kid's cook-night ("Caddie makes the white chili WITH mom"); paired sessions log toward that kid's likesToCook and the meal's memory reps.
- **ATF-7** — Joy-cooking invite: fires only on high-capacity + calm-day signals, draws from the user's deep-dive list, uses invitation register, and a decline produces zero follow-up that week and zero streak effect.

## §19b Local sales (Phase 2)
- **SALE-1** — A sale on an item matching a household food-need tag (e.g. GF pasta, ground beef for iron) → proposed list add or meal swap, with the need named ("iron-friendly + on sale").
- **SALE-2** — Sales on items matching NO household need are never surfaced (no coupon spam).
- **SALE-3** — Sale proposals respect the guarantee + routing (a perishable deal only lands on a run that can use it in time).

## §19c Streaks (bend, don't break)
- **STRK-1** — "Dinner happened" counts swaps, fallbacks, leftovers, and emergency takeout equally — purity is not the metric, feeding is.
- **STRK-2** — A missed day within the 48h grace window is repairable by logging; the streak continues unbroken.
- **STRK-3** — Past grace with no token: streak PAUSES; UI shows "best: N · rebuilding: day X" — the string "0" never renders for a streak count.
- **STRK-4** — Resuming after a pause fires a comeback celebration ≥ the intensity of a milestone celebration.
- **STRK-5** — ⚠️ No streak can be created that tracks any individual member's food intake/quantity — the type system/creation flow forbids it (eating-pressure guard).
- **STRK-6** — "Shopped per plan" streak increments on completed planned runs and is unaffected by a snoozed escalation (GT-9 interplay); an emergency store run pauses it with the standard no-shame framing.
- **STRK-7** — Streak celebrations are generated (no repeated copy within 60 days) and pass the NT-11 shame-audit.
- **STRK-8** — Freeze tokens: earned by real activity (logging, check-ins), capped at max, spent automatically with a friendly note — never silently.

## §19d Reward menu (bidirectional dopamine)
- **RWD-1** — Initiation pairing: a queued heavy task (Costco run) may arrive framed with a menu reward as anticipation; the reward named comes from the user's menu, correct tier.
- **RWD-2** — Comeback messages carry the strongest reward pairing ("back on the wagon" + suggestion) — restart > continuation in reward weight.
- **RWD-3** — ⚠️ Suggestions draw ONLY from user-authored RewardItems: generated copy never names a brand/product/purchase absent from the menu (zero injected commerce).
- **RWD-4** — Triumph register: milestone celebrations may go full swagger when voiceRegister permits; shame-audit still passes; a MISS never receives sass.
- **RWD-5** — Rate limit: no reward suggestion within `rewardSuggestionCooldownHours` of the last; suggestions never exceed ~1 in 4 celebratory messages.
- **RWD-6** — Tier match: daily wins draw small-tier; comebacks/milestones draw medium/special; special-tier items surface ≤1×/month.

## §19e Loves Corpus
- **LOV-1** — Generated celebratory/slump content references corpus items when available; with an empty corpus it degrades to warm-generic gracefully (never invents false personal knowledge).
- **LOV-2** — Conversational capture: "I love Project Hail Mary" in any NL input → an add-to-loves offer; nothing is added without a yes.
- **LOV-3** — Observed resonance requires consent: engagement-pattern additions are always proposed, never silent; declining is remembered.
- **LOV-4** — The corpus page shows every item + its source; deleting removes it from all future generation immediately.
- **LOV-5** — Rotation: no corpus item appears in generated output twice within its cooldown; a resting love ("Gosling era on pause") never surfaces until it returns.
- **LOV-6** — ⚠️ Never weaponized: reward/anticipation framing may use loves; conditional-threat framing ("no X unless…") fails the audit and is never sent.

- **LOV-7** — Favorite colors drive visual treatment: accents/celebration styling sample the user's declared palette; with none declared, defaults apply.
- **LOV-8** — Place-loves flow both ways: a favorite shop can appear in reward framing AND as a preferred store for run planning; GF-strong store notes attach to place items.

## §19f Stressor profile
- **STRS-1** — A calendar day matching a declared stressor ("two+ kid events") preemptively: caps effort at simple, boosts safe foods + satisfied leftover-consumers, and switches notifications to quiet/warm — WITHOUT waiting for a check-in. *(D-43 2026-07-09, refined: a stressor match — or a sudden calendar-load spike — prompts EXTRA ASSISTANCE: one concrete, reasoned, plan-preserving suggestion (named stakes, one-tap accept, free to ignore); it does NOT preemptively cap effort, rewrite the plan, auto-switch notifications, or ever apply the suggestion itself.)*
- **STRS-2** — Declared beats inferred: if inference says "fine" but a declared stressor matches, the stressor adaptation wins. *(D-43: precedence dissolves — declared patterns supply context/flexibility; behavioral signals (ignored notifications, time-since-open) are the primary state detector.)*
- **STRS-3** — Severity scales response: severity 3 also suppresses optional asks (no pool-health prompts, no reward pairings) that day. *(D-43: folds into the EQ engine's judgment (M5-3), not a standalone rule.)*
- **STRS-4** — Reflection-proposed stressors require explicit acceptance; declining is remembered and not re-proposed for 60 days.
- **STRS-5** — Stressor page is fully visible/editable; deleting one stops its adaptations immediately.

## §21 Pressure-test findings (cross-system collisions)
- **PT-1** — Cold start: with all scores at 0, the scheduler runs the reduced mode (frequency+effort+hard constraints), labels it, and never presents tie-breaking as optimization.
- **PT-2** — Fairness floor: Elsie at −2 on a meal the other four rate +2 → it appears ≤ `dislikeFloorPerWeek`/week and never on consecutive days; Σ-liking alone can't bury one member. *(D-17 2026-07-09: floor is now per-tier — a −2 meal ≤ once/14 days, a −1 meal ≤ once/7 days, per person; consecutive-day ban stands.)*
- **PT-3** — Notification pre-generation: content is generated ≤60 min before send using current state; a capacity flip after generation but before send triggers regeneration.
- **PT-4** — Offline: with no network at send time, the fallback bank supplies corpus-flavored, novelty-tracked content — never a visible template string.
- **PT-5** — Photo privacy: an image containing a detected person is never uploaded; the user is prompted to retake/crop; the crop is what ships.
- **PT-6** — EventKit drift: moving a Moody event in the Calendar app re-runs guarantee + capacity checks for the new date; deleting one prompts skip-vs-reschedule; content edits are reconciled back to app truth.
- **PT-7** — Cross-source dedup: garbanzo beans required by a meal + staples floor + snack cadence in the same window → ONE line item, summed, strictest need-by.
- **PT-8** — DST/day boundaries: streak days, plan dates, and "tonight" resolve correctly across DST transitions and late-night logging (a 12:30am "we ate" log counts for the evening just ended, not tomorrow).
- **PT-9** — Cook-night × stressor: severity ≤2 keeps the kid's cook-night; severity 3 yields to a low-effort fill; either way the kid's streak is unaffected (no-fault pause). *(D-18 2026-07-09: auto hold/yield RETIRED — collisions stay manual with one-tap swap; the no-fault streak pause stands.)*
- **PT-10** — Leftover chain × attendance: a producer cooked at reduced attendance yields a smaller leftover belief; if it can't cover the consumer's portions, the consumer is flagged before its day, not discovered at the stove.

## §19g The Vent
- **VNT-1** — Reception register: responses are brief, warm, validating; contain no advice (unless asked), no analysis, no diagnosis-adjacent language, and never dispute or minimize the stated feeling (automated register audit).
- **VNT-2** — ⚠️ Isolation: vent content appears in ZERO other generated outputs — notifications, celebrations, reflections, persona/group messages — verified by cross-corpus scan over a 60-day simulation.
- **VNT-3** — Data covenant: vents are excluded from the Loves Corpus and tone-learning; individually deletable; local-only mode results in no vent text in any API payload (payload inspection test).
- **VNT-4** — One consented follow-up max: post-vent, at most one gentle stressor/adjustment proposal; a decline is remembered and that theme isn't re-proposed for 60 days.
- **VNT-5** — Never punitive: vent activity never increases escalation, never pauses streaks, never triggers additional asks — venting is consequence-free by construction.
- **VNT-6** — Access: one-tap/voice entry from anywhere; during a suspected slump the Noticer's touch may include the offer; the offer itself carries no ask beyond the door being open.

## §20 Calendar (EventKit)
- **CAL-1** — Confirming a plan creates events on the dedicated Moody calendar only.
- **CAL-2** — Editing/deleting a PlanEntry updates/removes its event; no orphans.
- **CAL-3** — Calendar permission denied → app fully functional internally, sync features visibly disabled with a clear explanation.
- **CAL-4** — Shop-time suggestion proposes windows that do not overlap existing calendar events.

---
### Review notes for Ria
- ⚠️ sections (§1, §10) are the halt-the-line ones. Everything else is fix-in-order.
- DM-4 and NL-6 intentionally force decisions — reviewing them IS answering design questions.
- §14/§15/§18 include behavior that's partly subjective (tone, quiet-down thresholds, guilt-free copy); those get human review gates, not pure automation.
