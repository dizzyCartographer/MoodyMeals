# Moody — Build Spec (companion to requirements doc)
### For execution by Claude Code — v0.1 draft

This is the buildable translation of `moody-meal-app-requirements.md`. That doc is the north star; this one resolves decisions, pins the data model, specifies the scheduler, and orders the work.

---

## 1. Resolved decisions

| Decision | Resolution | Notes |
|---|---|---|
| AI engine | **Cloud — Anthropic Claude API** (user-approved; not Grok/Gemini) | One engine for NL parsing, planning conversation, and photo-inventory vision (Claude is multimodal). Revisit on-device later if privacy posture changes. |
| Recipe types | **Loose** and **Precise** | "Favorite" dropped to avoid collision with favorites/all-timers. |
| Nutrition source | **USDA FoodData Central (free)** for v1 | Paid API only if match quality disappoints. Phase 2. |
| Persistence | **SwiftData**, local-first, no accounts | Export/import as markdown for portability. |
| Meal slots v1 | **Dinner + Breakfast** | Lunch out of scope for now. |
| Calendar/Reminders | **EventKit** | One dedicated "Moody" calendar; app owns its events. |
| Voice on device | **Speech framework** in-app; **App Intents** for Siri/HomePod quick-hits | Open-ended convo stays in-app. |
| Shopping integration | **Instacart API** (Phase 2); markdown/Reminders export (Phase 1) | |
| Min target | iOS 18+, SwiftUI, single device | Sync/sharing later. |

---

## 2. Data model (SwiftData)

Conventions: all models get `id: UUID`, `createdAt`, `updatedAt`. Enums stored as raw strings. Relationships noted inline.

```swift
// ── People & needs ────────────────────────────────────────────

@Model final class FamilyMember {
    var name: String
    var isAdult: Bool
    // Hard dietary requirements — scheduler MUST never violate.
    // e.g. [.glutenFree] for Caddie
    var hardRequirements: [DietaryRequirement]
    // Soft goals the scheduler optimizes toward.
    // e.g. Ria: [.hemeIron, .antiInflammatory]; Chad: [.highCalorie]
    var softGoals: [FoodNeedGoal]
    var notes: String            // "meat-averse; needs protein+veg+starch"
    var currentBreakfast: Meal?  // the set-and-forget daily default
    var appetiteBase: Double     // servings multiplier (Chad ≈ 1.5; others 1.0)
    var appetiteFavoriteBoost: Double // extra when liking == +2 (Chad → up to 2.0). D-5
    var methodAffinity: [String: Int] // D-28: CookMethod → -2…+2. Ria: grill +2, oven -2.
                                      // Not a mild preference — a 7:1 revealed law. Weighted hard.
    @Relationship(deleteRule: .cascade, inverse: \MemberMealScore.member)
    var mealScores: [MemberMealScore]
    @Relationship(inverse: \Snack.favoriteOf)
    var favoriteSnacks: [Snack]
}

enum DietaryRequirement: String, Codable {   // HARD constraints
    case glutenFree, dairyFree, nutFree, vegetarian /* extensible */
}

enum FoodNeedGoal: String, Codable {          // SOFT optimization targets
    case hemeIron, antiInflammatory, highCalorie, highProtein
    case proteinVegStarch  /* Elsie's plate rule */ /* extensible */
}

// ── Per-member relationship to a meal (the two axes + safety) ─

@Model final class MemberMealScore {
    var member: FamilyMember
    var meal: Meal
    var liking: Int      // -2 (dislike) ... +2 (big hit), 0 default
    var fit: Int         // -2 ... +2 : how good it is FOR THEM (auto-suggested from goals+nutrition, user-overridable)
    var isSafeFood: Bool // per-member denotation — never household-wide
    var notTodayUntil: Date?  // per-person temporary hide
    var likesToCook: Bool     // D-6: kid cook-nights — likes to MAKE it, not just eat it
}

// ── Food objects ──────────────────────────────────────────────

@Model final class Ingredient {
    var name: String
    var perishability: Perishability
    var preferredRunTier: RunTier?    // override; else inferred from perishability
    var fdcID: Int?                   // USDA FoodData Central match (Phase 2)
    var isGlutenFreeVerified: Bool?   // label-verification flag (celiac rule: nil = unverified, treat as unsafe for GF)
}

enum Perishability: String, Codable { case pantry, freezer, refrigeratedLong, freshShort } // freshShort = milk/produce/fish

@Model final class Recipe {
    var title: String
    var kind: RecipeKind              // .loose or .precise
    var steps: [String]               // may be empty for loose
    var sourceURL: URL?
    @Relationship(deleteRule: .cascade) var items: [RecipeItem]
}

enum RecipeKind: String, Codable { case loose, precise }

@Model final class RecipeItem {       // join: recipe ↔ ingredient
    var ingredient: Ingredient
    var amount: Double?               // nil is VALID (loose recipes)
    var unit: String?
}

// ── Meal: the atomic plannable unit ───────────────────────────

@Model final class Meal {
    var title: String
    var freeformNotes: String         // "Snack plate dinner", "Chipotle takeout"
    var recipes: [Recipe]             // zero or more
    @Relationship(deleteRule: .cascade) var directItems: [RecipeItem] // ingredients not via a recipe
    var effort: EffortLevel
    var themeTags: [String]           // "mexican", "italian", "sheet-pan"
    var slots: [SlotKind]             // multi-slot (D-1): breakfast-for-dinner is real
    var requiresCalmDay: Bool         // D-1: only schedulable on peaceful/clean-kitchen days
    // Scheduling knobs
    var frequencyTarget: FrequencyTarget?   // nil = no target, scheduler free
    var rotationState: RotationState
    var cooldownUntil: Date?          // set by "everybody's sick of this"
    var lastEatenAt: Date?
    var lastScheduledAt: Date?
    // Canon
    // Leftover chains (D-4): intentional overproduction feeding later meals
    var producesComponents: [String]  // e.g. ["cooked rice"] — cook extra on purpose
    var requiresComponents: [String]  // e.g. ["cooked rice"] — leftover-DEPENDENT meal
    var componentFreshnessDays: Int   // consumer must run within N days of producer (default 2)
    var moodTags: [String]            // "cozy", "griddle-day", "celebration" (D-8)
    var methods: [CookMethod]         // D-28: how it's made — grill, stovetop, oven, etc.
    var isEatingOut: Bool             // D-7: NEVER auto-scheduled; emergency/manual only
    var isAllTimeFavorite: Bool       // exempt from ALL fatigue mechanics
    var coreMemoryNote: String?       // "Elsie's first-day-of-school dinner"
    var coreMemoryOwner: FamilyMember?
    // Occasions
    var occasionTag: String?          // "thanksgiving", "caddie-birthday"
}

enum EffortLevel: Int, Codable { case noCook = 0, assembly, simple, involved }
enum CookMethod: String, Codable { case grill, griddle, stovetop, oven, airFryer, slowCooker, instantPot, microwave, noCook, smoker }
enum SlotKind: String, Codable { case dinner, breakfast }
enum FrequencyTarget: String, Codable { case weekly, biweekly, monthly, quarterly, occasionally }
enum RotationState: String, Codable { case active, resting /* cooldown */, retired /* rare */ }

// ── Planning ─────────────────────────────────────────────────

@Model final class PlanEntry {
    var date: Date                    // day-granularity
    var slot: SlotKind
    var meal: Meal
    var isLocked: Bool                // user pinned; scheduler won't move
    var eventKitID: String?           // synced calendar event
    var status: PlanStatus            // planned / eaten / swapped / skipped
    var attendees: [FamilyMember]     // default: everyone. Hard constraints apply to ATTENDEES only
    var assignedCook: FamilyMember?   // kid cook-nights (D-6); nil = default cook
}

enum PlanStatus: String, Codable { case planned, eaten, swapped, skipped }

@Model final class ThemeAnchor {      // "Taco Tuesday"
    var weekday: Int                  // 1–7
    var slot: SlotKind
    var themeTag: String              // meals matching this tag fill the anchor
    var varietyPeriodWeeks: Int       // rotate the specific meal every N weeks (default 3)
    var isActive: Bool
}

// ── Shopping ─────────────────────────────────────────────────

enum RunTier: String, Codable { case bulk /* Costco */, weekly, midweek }

@Model final class ShoppingRun {
    var tier: RunTier
    var plannedDate: Date
    var status: RunStatus             // proposed / confirmed / done / skipped
    var eventKitID: String?
    @Relationship(deleteRule: .cascade, inverse: \ShoppingItem.run)
    var items: [ShoppingItem]
}

enum RunStatus: String, Codable { case proposed, confirmed, done, skipped }

@Model final class ShoppingItem {
    var run: ShoppingRun?
    var ingredient: Ingredient?
    var freeText: String?             // manual items
    var amount: Double?; var unit: String?
    var neededBy: Date?               // date of the meal that needs it — drives routing + guarantee check
    var source: ItemSource            // meal / snackCadence / manual / breakfastStaple
    var isPurchased: Bool
}

enum ItemSource: String, Codable { case meal, snackCadence, manual, breakfastStaple }

// ── Snacks & purchase history ────────────────────────────────

@Model final class Snack {
    var name: String
    var favoriteOf: [FamilyMember]
    var cadenceDays: Double?          // nil until inferred or set
    var cadenceIsInferred: Bool
    var lastPurchasedAt: Date?
}

@Model final class PurchaseRecord {
    var itemName: String
    var ingredient: Ingredient?
    var snack: Snack?
    var purchasedAt: Date
    var sourceRun: ShoppingRun?
}

// ── Inventory (belief, not ledger) ───────────────────────────

@Model final class InventoryItem {
    var ingredient: Ingredient?
    var label: String                 // what we think it is
    var location: StorageLocation
    var confidence: Double            // 0–1; photos + convo raise it, time decays it
    var estimatedQuantity: String?    // "half a bag" — human-fuzzy on purpose
    var lastConfirmedAt: Date         // last photo/convo/purchase touch
    var flaggedUnclear: Bool          // queued for the reconciliation convo
}

enum StorageLocation: String, Codable { case fridge, freezer, pantry, door, unknown }

@Model final class WasteEvent {
    var itemName: String
    var ingredient: Ingredient?
    var loggedAt: Date
    var note: String?                 // "tossed half the spinach again"
}

// ── Read the room ────────────────────────────────────────────

@Model final class CheckIn {
    var date: Date
    var capacity: Capacity?           // nil = skipped (a signal in itself)
    var moodNote: String?
    var modality: CheckInModality     // which style was used (novelty rotation)
    var wasAnswered: Bool
}

enum Capacity: Int, Codable { case low = 0, medium, high }
enum CheckInModality: String, Codable { case oneTap, textStyle, voiceConversational }

@Model final class WeeklyReflection {
    var weekStart: Date
    var summary: String               // Claude-generated, user-edited
    var adjustments: [String]         // human-readable log of what got tuned
}

// ── Household config ─────────────────────────────────────────

@Model final class StapleItem {       // D-6b: Elsie's fallback + similar — ALWAYS on hand
    var name: String                  // "sandwich bread (GF-verified)", "garbanzo beans"
    var ingredient: Ingredient?
    var forMember: FamilyMember?      // whose lifeline this is
    var minOnHand: String             // human-fuzzy: "2 cans"
}

@Model final class FridgeSpec {
    var modelNumber: String?
    var widthCM: Double?; var heightCM: Double?; var depthCM: Double?
    var shelfNotes: String?           // freeform geometry notes / zone layout
}
```

**Deliberate modeling choices to poke at:**
1. `MemberMealScore` carries liking, fit, safe-for, and per-person "not today" in one join object — one row per (member, meal).
2. Inventory is a *belief* with `confidence` and decay, not a strict ledger — matches "best-effort, never blocking."
3. `currentBreakfast` lives on the member (a default), not as 365 PlanEntries. Breakfast burnout = swap the reference + set cooldown on the old meal.
4. Occasion menus are just meals with `occasionTag` + a saved grouping (v0.2 may add an `OccasionMenu` collection object).
5. GF safety: `isGlutenFreeVerified` is tri-state — `nil` means unverified, and unverified = **unsafe** for any GF member (celiac label-verification rule encoded in the type).

---

## 3. Scheduler specification

Runs on demand ("plan my next N weeks") and maintains a 12-month horizon of provisional entries (only near-term synced to calendar; far entries stay app-internal).

**Step 1 — Hard filter (never violated):**
- Exclude meals violating any *attending* member's `hardRequirements` (GF check uses verified-GF rule above).
- Exclude `rotationState != .active` (resting until `cooldownUntil`, retired always).
- Exclude meals with an active `notTodayUntil` for an attending member.
- All-time favorites are schedulable but **never auto-cooled or frequency-suppressed**.

**Step 1b — Condition gate:** meals with `requiresCalmDay` are only eligible when the day qualifies as calm: inferred capacity ≥ medium AND calendar density low AND (when kitchen-state tracking exists) kitchen not flagged messy. Wednesday ships as a seeded, default-off breakfast-for-dinner anchor.

**Step 1c — Attendance & away-unlocks (refined by D-29, corrected by D-30):** hard constraints evaluate against `attendees` only. Household reality: **packaged gluten items are normal here** — regular crackers, regular bread and buns for sandwiches and hot dogs coexist fine with careful habits, and they're legitimate shopping-list items (tagged not-Caddie-safe so they never count toward HER meal coverage). The one true house ban is **from-scratch wheat baking / raw wheat-flour work**, for TWO reasons that both matter: (1) *physics* — flour aerosolizes and contaminates the kitchen; (2) *kindness* — baking something super delicious that Caddie isn't allowed to have fills the house with an aroma of her exclusion. Home never advertises what she can't share. So no surface of the app (scheduler, joy invitations, discovery, personas, occasions) ever suggests it — and more broadly, any *special/celebratory* home-cooked deliciousness the app proposes should be Caddie-inclusive; mundane contained gluten (a sandwich, a bun) is fine, tantalizing theater she's shut out of is not. GF baking is alive and well via mixes (King Arthur GF is the house standard — "a mean mix for pretty much everything") and is fully suggestible, including as joy-cooking and Signature bakes.

**Step 1d — Leftover chains:** a meal with `requiresComponents` is only placeable if a producer of every component is scheduled within `componentFreshnessDays` before it. The scheduler may *pull in* a producer to enable a desired consumer (extra rice Tuesday → fried rice Wednesday). Producers write a leftover InventoryItem (kind: leftover, useBy date) when marked eaten.

**Step 1e — Eating out is nuclear:** `isEatingOut` meals are NEVER auto-scheduled and occasions never propose them; they exist only as manual/emergency swaps.

**Step 2 — Anchor fill:** for each `ThemeAnchor`, choose among meals with the matching `themeTag`, rotating the specific meal every `varietyPeriodWeeks`.

**Step 3 — Score remaining open slots.** For each candidate meal `m` on date `d`:

```
score(m, d) =
    wL * Σ liking(member, m)                     // household liking
  + wF * Σ fit(member, m)                        // household fit
  + wFreq * frequencyPressure(m, d)              // + if overdue vs target, − if ahead
  + wRecency * recencyPenalty(m, d)              // − if eaten recently (decays over ~21 days)
  + wCap * capacityMatch(effort(m), capacity(d)) // low-capacity day → low-effort bonus
  + wNovel * noveltyBonus(m)                     // dial: comfort ↔ adventurous
  + wMethod * methodAffinity(assignedCook, m)    // D-28: the cook's method love/avoid, weighted HARD
Defaults: wL=1.0, wF=1.0 (user-weightable), wFreq=0.8, wRecency=1.2, wCap=1.5, wNovel=0.5, wMethod=1.5
Method rule: a LOVED method (+2) is never blocked by weather or season — the app may cheerfully note the 102° ("grill warrior 🔥") but NEVER removes or nannies a loved-method meal. Avoided methods (−2) surface only when nothing else satisfies constraints, and the app says why.
capacity(d): today/tomorrow from check-ins; farther out inferred from calendar density; default medium.
```

**Step 4 — Guardrails after greedy fill:** no meal twice within its recency window; weekly Fit coverage check (e.g. ≥2 iron-forward dinners/wk, ≥N calorie-dense options with Chad home) — patch by swapping lowest-margin slots; respect locked entries.

**Step 4a2 — Leftover consumers are busy-night heroes (D-11):** meals with `requiresComponents` are typically EASY (fried rice = simple) — the producer night did the work. On dense/low-capacity days, satisfied leftover-consumers get a placement bonus: the payoff lands exactly when capacity is lowest.

**Step 4b — Calendar-inferred conditions (D-8):** the calm-day gate reads the calendar for signals, e.g. a cleaner visit → kitchen-gorgeous that evening → griddle/`requiresCalmDay` meals (breakfast-for-dinner) favored; ≥2 kid events in one day → effort capped at `simple` AND a healthy-leaning bias. Signal→rule mappings are user-editable, not hardcoded.

**Step 4c — Cook nights:** an optional anchor assigns each kid one night/week, filling it from meals where that kid's `likesToCook == true` (and that are safe for all attendees). Servings math: portions = Σ attendees' `appetiteBase`, plus `appetiteFavoriteBoost` for members whose liking on tonight's meal is +2 — shopping amounts scale accordingly.

**Step 4d — Fairness floor (pressure-test finding):** summed household Liking can systematically sacrifice one person (a meal at −2 for Elsie but +2 for everyone else wins on the sum every time). Guardrail: no attendee may face a meal they rate −2 more than `dislikeFloorPerWeek` (default 1) times/week, and consecutive-day repeats of anyone's −2 are forbidden. The staples lifeline is a safety net, not a lifestyle.

**Step 4e — Cook-night × stressor collision:** if a kid cook-night lands on a declared stressor day, default = the cook-night HOLDS at severity 1–2 (a kid cooking can be the relief) and yields at severity 3 (supervision cost). Tunable per household; flagged in the digest for Ria.

**Step 4f — Cold start (pressure-test finding):** day one has zero Liking/Fit data — the optimizer would be choosing among ties. Onboarding includes a fast per-member swipe pass over the seed meals ("love / fine / nope," ~3 min each, skippable); until enough signal exists the scheduler runs frequency+effort+hard-constraints only and says so, rather than faking optimization.

**Step 4g — Signature meals get memory reps (D-27):** all-time favorites were already exempt from fatigue; now they also get a gentle **frequency floor** — a designated "Signature" meal (the ones the kids will miss from college) is guaranteed to recur often enough to become memory (default `signatureFloorPerQuarter = 2`, per meal, tunable). The legacy isn't left to chance; it accrues on schedule. Signatures pair naturally with kid cook-nights — the kids don't just eat mom's meals, they *learn* them, which is how those five meals actually make it into a dorm kitchen someday.

**Step 4h — Joy-cooking invitations (D-27):** high capacity isn't just permission for effort — it's an opening for the cook who loves this. On calm, high-capacity days (check-in + calendar + kitchen-gorgeous signals), the app may offer the deep dive: "You've got a clear Saturday and a clean kitchen — want to do the thing where you cook for real?" Sourced from a user-kept "someday/deep-dive" list (that braise, that bake, the bread project). Invitation register only — declining costs nothing, is never mentioned again that week, and never dents any streak. The scaffolding on hard days exists to PROTECT capacity for exactly these days.

**Step 5 — Reactivity:** "sick of this" → rest + immediate re-fill of affected future slots; check-in/calendar changes re-score only today+tomorrow (stability beats churn).

Weights live in a config object — tuned by the weekly reflection loop later, hand-tuned in v0.1.

---

## 4. Shopping guarantee algorithm

1. Nightly + on any plan/run change: gather every `PlanEntry` between now and the next *confirmed* run of each tier.
2. Explode meals → required items (amounts where precise, presence where loose).
3. Subtract inventory beliefs **only at confidence ≥ 0.7**; below that, buy it anyway (belief, not ledger).
4. Route uncovered items to runs: `freshShort` → nearest weekly/midweek run before `neededBy`; `pantry/freezer` → any run before `neededBy`, preferring bulk when >2 weeks out.
5. **If an item can't make it onto any run before its `neededBy`: guarantee violation** → propose meal swap or an added mini-run.
6. Run skipped/delayed → re-run check → escalation path ("for real, go shopping") with named at-risk meals, via the notification-novelty system.

---

## 5. Claude API integration

One thin service layer (`MoodyBrain`) with tool-use; the app defines tools that map to local operations:

- `logMealFeedback(meal, perMemberLiking, frequencyDelta)` — "this was perfect, curry more often"
- `createRecipe(loose|precise, items, steps?)` — brain-dump parsing
- `adjustPlan(date, action)` — swaps, "low-effort Thursday"
- `queryMeals(criteria)` — "what's iron-heavy that everyone likes?"
- `reconcileInventory(photoAnalysis, answers)` — the fridge-photo conversation
- `logWaste(item, note)`

Photo inventory: send image → Claude vision returns structured item list + `flaggedUnclear` questions → conversational reconciliation → inventory updates with confidence.

Privacy guardrail: send only what the task needs (no health notes in a shopping-list parse). Log every payload category in a visible "what leaves the device" setting.

---

## 6. Milestones (thin vertical slices)

- **M0 — Skeleton:** SwiftData models, seed data (the 5 family members incl. per-member hard requirements), basic CRUD UI for meals/recipes.
- **M1 — Plan + see:** manual planning UI, EventKit sync (Moody calendar), Tonight view. *Usable value: the family calendar shows dinner.*
- **M2 — Shopping core:** meal→list explosion, tiered runs, routing, guarantee check v1 (no inventory yet — assume nothing on hand), markdown/Reminders export.
- **M3 — Brain, part 1:** Claude service + NL capture (brain-dump→recipe, log-by-talking, compound feedback), daily check-in (one-tap), capacity-aware Tonight suggestions with "just decide."
- **M4 — Scheduler v1:** scoring engine, anchors, cooldowns, frequency targets, 12-month horizon; "sick of this" flow.
- **M5 — Notifications:** novelty-rotating tonight reminders + check-in prompts; escalation path.
- **M6 — Inventory + photos:** photo→Claude vision→reconciliation convo; guarantee check v2 (inventory-aware); waste logging.
- **M7 — Breakfast + snacks:** per-member breakfast default + burnout swap; snack cadence inference from PurchaseRecords.
- **M8 — Occasions, all-timers, HomePod:** occasion menus from calendar; core-memory tier; App Intents quick-hits.
- **Phase 2 (post-M8):** nutrition (USDA) + auto-Fit suggestions, Instacart, fridge-spec container recs, weekly-reflection-driven weight tuning, read-the-room behavioral signals, **local sales awareness** — when foods aligned with household needs (iron-rich, GF staples, calorie-dense, Elsie's staples) go on sale nearby, propose list adds or meal swaps. Needs-aligned deals only; never coupon spam. Integration path to verify: Kroger developer API (Harris Teeter is a Kroger banner — confirm coverage + deals endpoint), Instacart sale pricing, weekly-ad aggregation as fallback.

Each milestone ships something usable. M0–M2 need no AI at all — real utility before the fancy parts.

---

## 7. Open questions for Ria

1. Can one meal serve both slots (breakfast-for-dinner)? v0.1 says single `slotKind`; is that acceptable short-term?
2. Attendance: model "who's home tonight" per PlanEntry in v0.1 (adds UI cost), or defer to Phase 2? Affects portioning + Chad-volume checks.
3. Liking/Fit as −2…+2 integers — enough resolution, or want finer?
4. Default cooldown length for "sick of this" — 6 weeks? 3 months? Per-meal ask?
5. Escalation ceiling: how loud may "for real, go shopping" get? (Time-sensitive notification? Repeat daily?)

---

## 7b. Generative notification engine — "the neurodivergent-first manager"

Notifications are NOT templates. Every outbound message is **generated fresh** (Claude API) by an engine whose mental model is a great manager at a company that intentionally hires neurodivergent people. Before every send it decides, from read-the-room state:

1. **What does she need right now?** Soft encouragement, a kick in the pants, a good laugh, or just plain information.
2. **Channel & format:** standard notification / meme follow-up (user pack) / casual text-style / one-tap ask / voice invite — **jumping channels, genres, and vibes regularly**, and MORE aggressively when a slump is suspected (skipped check-ins, ignored alerts, swaps-to-lowest-effort, silence).
3. **Grounding rules** (from ADHD motivation research — ADDitude, ADHD coaching literature; the prompt corpus should draw on these + ADHD.love-style peer content):
   - Frame around **reward anticipation**, never threat — anticipated negative outcomes generate no dopamine and no action.
   - **Never shame.** Unmotivation usually means expected failure, not laziness; notice effort, not just outcome.
   - **Novelty is neurologically load-bearing** — ADHD brains respond to novelty far more strongly, so repetition is decay by design.
   - Offer **one tiny concrete next step**, not the whole mountain.
   - Gentle manufactured urgency only via **real, named stakes** ("Thursday's cod dies tomorrow"), never vague pressure.
   - Act as warm **external accountability** (body-double energy), not surveillance.
4. **Slump mode:** when suspected, raise emotional intelligence AND novelty together — funnier, warmer, more surprising, asking less.
5. **Corpus-targeted references:** meme and reference selection is DRIVEN by the Loves Corpus (media/fandom/humor items) — the corpus is how the engine knows which references will actually land for this person. Nothing is hardcoded to any one meme or celebrity; the Gosling-astronaut example works for Ria because Project Hail Mary is in HER corpus, not because it's in the app.
6. Generated output is checked against notification history (no repeats), the shame-audit rule, and the snooze state before sending.

## 7c. Streaks — "bend, don't break"

Gamified streaks, designed so a miss can never trigger the ADHD abandon-spiral. Core rules:

- **Track process, never perfection or consumption.** Streaks count things within our control: "dinner happened" (ANY dinner — a swap, a safe-food fallback, leftovers, even the nuclear option counts; feeding the humans is the win), "shopped per plan" (no emergency Food Lion runs between planned runs — the guarantee, gamified), weekly check-in answered, kid cook-nights ("Caddie's 4th Tuesday running!"). **HARD RULE: no streak may ever track an individual's food intake or quantity eaten** (looking at Chad) — that's eating-pressure, not motivation. Process only.
- **Misses dim, never shatter.** A missed day enters a grace window (repair by logging what actually happened, ~48h) or spends a freeze token (earned by activity). Past grace, the streak *pauses* — the UI NEVER shows zero. Display is always "best: 23 · rebuilding: day 2."
- **Comebacks are celebrated harder than continuations.** Returning after a gap is the genuinely hard part for an ADHD brain; the resumption celebration ("THE RETURN 🔥") should outshine day-30 confetti.
- **Celebrations are generated** by the EQ engine (§7b) — novel every time, vibe-matched, never the same badge twice in a row.
- Per-streak opt-in; all windows/tokens/thresholds in TuningConfig (`streakGraceHours=48`, `freezeTokenEarnRate`, etc.).

### 7c2. The Reward Menu (personal dopamenu) — rewards fire in BOTH directions

A user-curated module of things Ria (and each member) genuinely loves — a ThriftBooks order, a bubble bath, a specific treat, an episode of the comfort show — tiered small / medium / special. The EQ engine deploys them at the two moments ADHD rewards actually work:

1. **Initiation — "let's do this":** pre-task anticipation pairing. "Knock out the Costco run and that ThriftBooks cart is yours." (Anticipation IS the dopamine — §7b rule 1, weaponized.)
2. **Triumph — "look what I did, bitch!!!":** post-completion hype that MATCHES the user's energy. Milestones and finished runs earn swagger-register celebration + a claim-your-reward suggestion. Sass is a feature; the shame-audit still applies (sass ≠ shame, and it never punches down at a miss).
3. **Restart gold:** comeback moments (§7c) get the strongest reward pairing of all — "look who's back on the wagon! I know someone who deserves a little ThriftBooks order." Rewarding the RESTART is the whole point.

Rules: suggestions draw ONLY from the user-authored menu — the app never invents brands, products, or purchases (her list saying ThriftBooks is why ThriftBooks appears; zero injected commerce). Tier matches the win (daily win → small; comeback/milestone → medium/special). Rate-limited so they stay special (`rewardSuggestionCooldownHours`). Redemption tracking is optional and celebratory, never homework.

```swift
@Model final class RewardItem {
    var title: String                 // "ThriftBooks order", "long bath, door locked"
    var owner: FamilyMember?          // nil = household
    var tier: RewardTier              // small / medium / special
    var notes: String?
    var lastSuggestedAt: Date?        // powers rate-limiting + novelty
}
enum RewardTier: String, Codable { case small, medium, special }
```

### 7b2. The Presentation Envelope — every message is a unique ARTIFACT (D-20)

"Generated" means the WHOLE message, not just the words. Every outbound touch generates a full envelope — and no two consecutive messages may feel like they came from the same place:

- **Persona / sender-voice — a stable recurring CAST (D-21):** 3–5 named characters, **co-created with the user at onboarding**. **The 2+2 grounding rule (D-26):** onboarding suggests the cast be based on **at least two real people from her actual life and two fictional people she wishes she were friends with** — real anchors keep the voices emotionally true (she can *hear* them), fictional aspirational friends add delight without weight. Real-person personas are **homage, not impersonation**: they borrow vibe, relationship, and energy — a character *inspired by* the friend, not a simulation of them (stylized avatars recommended over real photos; the user decides). Fictional-inspired personas are likewise homage in spirit — the app never ships canned characters; the user authors her own. The suggestion is a default, freely overridable — it's a grounding device, not a rule.
  Built as built as relationally plausible people who'd actually text her — e.g. *the professional chef from high school* (old-friend register, real cooking tips), *the neighbor*, *the friend from church*, *someone from band boosters*. The cast is STABLE so familiarity and affection build ("oh, it's the chef"), while rotation between them + envelope variance supplies the novelty. Personas cycle like everything else in this app: one can go quiet for a stretch and return ("the chef's been traveling") — rest-and-return, never a firehose of strangers. Each persona has a consistent voice, avatar, and relationship to the user; content stays corpus-informed. **Personas also have LIVES — rituals and specialties (D-22):** each carries 1–2 characteristic content beats tied to a fictional routine, e.g. *the chef texts cool meal ideas in the AM window "while she's at the docks buying fish"*; *the band-boosters guy drops his favorite super-quick meal mid-afternoon around pickup time*. Ritual windows are stable **character traits** (like Taco Tuesday — an anchor with variety inside): the exact minute jitters, the days vary, and no persona texts daily, so a ritual never collapses into a fixed daily slot. Rituals coexist with the Habituation Horizon because the *stream* still rotates — the chef's dock-run morning is familiar precisely because it doesn't happen every morning.

  **Persona ROLES — the re-entry choreography (D-23):** cast members carry emotional-function assignments (one special role per persona, set at co-creation):
  - **The Noticer** — usually the FIRST to sense a slump. Their touch is warm and zero-ask ("thinking of you" energy, maybe a funny nothing) — never "you've been quiet" accusatory, never a task. The Noticer fires before any escalation logic.
  - **The Never-Left** — when she comes back into the swing, this persona is **gap-blind by hard rule**: their messages may NEVER reference the absence, the pause, the streak, or time passed. No "welcome back," no "been a while," no "missed you." They simply continue mid-relationship, as if she never left — because to them, she didn't.
  - **The Hype** — carries the comeback celebrations and reward pairings (§7c/7c2).
  - **The Kindred (D-24)** — one cast member canonically ALSO has ADHD. They send iykyk messages (affectionate ADHD-recognition humor — never mocking; shame-audit applies), text at chaotic hours (organic minutes doing extra work), and **sometimes disappear too** — vanishing from rotation for a stretch as character behavior, then returning gap-blind about *themselves* ("been in a hyperfocus hole for six days, ANYWAY — found this at 2am"). When Ria returns from her own slump, the Kindred may reveal they'd been gone too ("oh thank god, I wasn't the only one who fell off"). Reciprocal imperfection: the system is no longer the flawless one watching the flaky human.

  **Group-thread mode (D-24):** the cast can interact with EACH OTHER — a light group-chat texture rendered via iOS communication notifications as a named group conversation. The chef drops a dock-fresh idea; the booster replies "too fancy, frozen nuggets night"; the Kindred surfaces hours later with "wait what did I miss." Rules:
  - **Ambient, lurkable, zero response debt:** most group chatter carries no ask; reading without replying is a valid (and tracked) engagement signal. Content can reach her as *overheard* conversation ("the booster asked the chef for a 10-minute version…") — lower pressure than direct address.
  - **Budgeted:** a group burst counts as ONE notification touch (delivered grouped, e.g. "3 in Dinner Crew"); group chatter respects quiet mode, snoozes, and stressor days; the thread is mutable like any real group chat.
  - **⚠️ The group NEVER discusses her absence.** Gap-blindness extends to group content — no "anyone heard from Ria?", ever. Slump touches remain 1:1 from the Noticer only. A group that talks about you while you're gone is surveillance wearing a friendship costume; banned at the audit level.

  **Choreography:** slump suspected → Noticer's gentle touch → she returns → Never-Left resumes ordinary chatter with zero ceremony (lowest-pressure re-entry) → once genuinely re-engaged, the Hype delivers the comeback celebration + restart reward. This resolves D-13's "celebrate comebacks harder" with the need for shame-free re-entry: the celebration still happens — it just never comes first, and never from the Never-Left. Implemented with iOS **communication-style notifications** (sender name + avatar via intent donation) so a message renders like a text *from someone*, not an app ping.
- **Channel/surface:** standard notification · communication-style notification · notification with attached image (UNNotificationAttachment) · widget/Live Activity change · in-app moment — rotated so the delivery surface itself varies.
- **Visual kit:** attached imagery, avatar, and palette sampled from the user's favorite-color loves — the look changes per message.
- **Sound:** a bundled sound set, rotated; silence is also a choice.
- **Timing:** jittered within the window ("sorta scheduled" — the schedule exists, the moment surprises). **HARD RULE — never on the quarter hour (D-22):** no envelope is ever delivered at :00, :15, :30, or :45; minute selection is biased toward organic, non-round minutes (9:17, 3:22 — never 10:00, never 4:15). Round-minute delivery reads as *app*; off-kilter reads as *person*. This is both aesthetics and anti-habituation.

**Uniqueness constraint:** novelty is enforced on the {persona, channel, visual, sound, copy} tuple — not copy alone. Envelope history persists; near-duplicate envelopes within the window are rejected and regenerated.

**The Habituation Horizon (D-21):** the user-named failure mode — "the same notification at 10am every day becomes invisible somewhere between day 4 and 21." Encoded as a hard rotation policy: **no envelope dimension may hold constant for more than `dimensionConstancyMaxDays` (default 3)** — not the persona, not the timeslot, not the channel, not the visual family — and no full envelope-pattern (same persona + same timeslot + same channel) may recur within `habituationHorizonDays` (default 7, range 4–21). Vibes are cyclical, not disposable: patterns rest past the horizon and RETURN — the chef texting at 10am comes back, just never often enough to become wallpaper.

**Honest limit:** the app cannot impersonate other apps' actual chrome (no fake Instagram UI — iOS forbids it). Personas + communication-style rendering + imagery + sound + surface rotation deliver the *felt* variety of "different corners of my life" within what iOS allows.

**Timing architecture (iOS constraint):** local notifications must be scheduled with content in advance, so envelopes are **pre-generated just-in-time** — a background task builds tonight's artifact 15–60 min before the window from fresh read-the-room state, and regenerates if state shifts. **Offline fallback:** a pre-built envelope bank (corpus-flavored, novelty-tracked, refreshed when online) — never a visible template.

### 7c3. The Vent — a place to bitch about the slump (D-25)

Food is personal, and it carries mom guilt like almost nothing else. The Vent is a zero-friction dump space — voice-first, always one tap away, gently offered by the Noticer during/after slumps ("want to just dump it somewhere?") — for saying WHY the slump happened, in whatever words it comes out in.

**Reception register — a listener, not a therapist:**
- Response is brief, warm, validating. No fixing, no analysis, no advice unless explicitly asked, no silver-lining her feelings away, and no clinical language ever. It can hold the app's one quiet conviction — *fed is the win; slumps are capacity events, not character verdicts* — as warmth, never as a lecture, and never by arguing with how she feels.
- Default receiver is a quiet dedicated space (the app itself). Venting TO a persona is opt-in only — heavy emotional processing is not the cast's default job.

**Hard rules (the sensitive-data covenant):**
- ⚠️ Vent content is NEVER quoted, referenced, or echoed in any other generated output — no notification, celebration, reflection, or persona message may draw on it. "Last time you said you felt like a failure…" must be impossible by construction.
- Vents never enter the Loves Corpus, never train tone, and are never mined — with ONE exception: after a vent, the app may make at most one gentle, consented proposal ("band-week keeps coming up — want me to mark it as a stressor?"). Declining is remembered.
- Every vent is deletable; a **local-only mode** keeps vent text entirely on-device (no cloud round-trip — reception falls back to on-device warmth). Payloads elsewhere in the app never include vent content.
- The Vent never feeds escalation, streak, or guarantee logic. Bitching about the slump can never make the app push harder.

## 7d. The Loves Corpus — the layer that keeps generation genuine

The unifying substrate under §7b/7c/7c2: a **curated, per-member corpus of things this person genuinely loves** — fandoms (Project Hail Mary), people-as-vibes (Gosling memes), treats and rituals (ThriftBooks, the locked-door bath), humor styles, shows, aesthetics, comfort media. Every generative context draws from it: notification flavor, meme selection + captions, streak celebrations, reward pairings, check-in phrasing, slump-mode material, even meal framing ("very cozy-baking-show energy tonight"). This is what keeps output **genuine, delightful, effective, and useful** instead of generic-AI wallpaper — the difference between "great job!" and "look who's back on the wagon, someone deserves a ThriftBooks order."

**How it grows:**
1. **Explicit curation** — a simple editable list per member.
2. **Conversational capture** — "I love Project Hail Mary" anywhere in NL input → offer to add.
3. **Observed resonance, WITH consent** — the engine notices which generated messages actually land (responses, reactions, acted-on nudges) and asks: "you always answer the space memes — add that to your loves?" It proposes; it never silently profiles.

**Rules:**
- **Fully visible and user-owned.** The corpus is a page the user can read, edit, and delete from — never a shadow profile.
- **Loves wear out too.** The novelty engine rotates corpus material like everything else; a love can be rested ("cooldown for the Gosling era") and cycles back. Overuse kills delight.
- **Never weaponized.** Corpus items are for delight and reward framing only — never leverage, guilt, or pressure ("you won't get your ThriftBooks order if…" is banned framing; anticipation yes, threat never).
- **No commerce injection** (extends RWD-3 corpus-wide): brands appear only because the user put them there.

```swift
@Model final class LoveItem {
    var owner: FamilyMember?          // nil = household-wide
    var kind: LoveKind                // fandom, memeVibe, treat, ritual, humorStyle, media, aesthetic
    var label: String                 // "Project Hail Mary", "Gosling 'hey girl' memes"
    var notes: String?
    var source: LoveSource            // explicit / conversational / observedConsented
    var restingUntil: Date?           // loves cool down too
    var lastUsedAt: Date?             // rotation + novelty
}
enum LoveKind: String, Codable { case fandom, memeVibe, treat, ritual, humorStyle, media, aesthetic, color, book, show, place }
// color: favorite colors feed the app's OWN visual treatment — accent colors, celebration
//   confetti, notification styling draw from HER palette, not a designer's default.
// place: where she likes to shop — doubles into run planning (preferred stores per tier,
//   GF-strong stores) and reward framing (ThriftBooks is a place-love with treat energy).
enum LoveSource: String, Codable { case explicit, conversational, observedConsented }
```

**Onboarding & ongoing capture:** a short conversational "get to know you" interview (voice-friendly, skippable, resumable) seeds the corpus — favorite colors, books, shows, shops — and the stressor profile below. After that, conversational capture and consented observation keep it growing.

### 7e. Stressor profile — declared, not just inferred

"What sorts of days stress me the most" is not a love — it's the other half of read-the-room. Each member (primarily Ria) can declare **day-pattern stressors**: "two+ kid events," "appointment-heavy days," "early-morning starts," "days after bad sleep." Declared patterns are treated as *stronger signal than inference*: when a stressor day is detected on the calendar, the system preemptively lowers effort caps, favors safe foods and leftover-consumers, quiets and warms notifications, and skips optional asks — before any check-in confirms it.

```swift
@Model final class StressorPattern {
    var owner: FamilyMember?
    var label: String                 // "two+ kid events in one day"
    var calendarSignal: String?       // matchable rule, user-editable ("events.kidTagged >= 2")
    var severity: Int                 // 1–3: how hard to adapt
    var notes: String?
}
```

Stressors are visible/editable like the corpus, and the weekly reflection may propose new ones from observed patterns ("dense Wednesdays keep going sideways — mark as a stressor?") — proposed, never silent.

(RewardItems and the meme pack become facets of this corpus — rewards are `treat`-kind loves with tiers; the meme pack is `memeVibe` loves with attached images.)

## 8. Tunables — every magic number is a user-adjustable setting

No behavioral constant may be hardcoded. All of the following live in a persisted `TuningConfig` (SwiftData singleton) with the defaults below, surfaced in a Settings → "Fine-tuning" screen (sliders/steppers, plain-language labels, per-item "reset to default"). Ship with these values; Ria tunes by living with the app.

| Key | Default | What it controls |
|---|---|---|
| `recencyWindowDays` | 21 | How long before a meal can naturally repeat |
| `cooldownDefaultDays` | 42 | "Sick of this" rest length (D-2: min 42, max 180, per-meal override in range) |
| `inventoryConfidenceThreshold` | 0.7 | Belief level at which inventory offsets the shopping list |
| `inventoryDecayHalfLifeDays` | 10 | How fast unconfirmed inventory confidence fades |
| `wL / wF / wFreq / wRecency / wCap / wNovel` | 1.0/1.0/0.8/1.2/1.5/0.5 | Scheduler weights (Liking, Fit, frequency, recency, capacity, novelty) |
| `ironCoveragePerWeek` | 2 | Min iron-forward dinners/week (Ria) |
| `calorieDenseCoveragePerWeek` | 3 | Min calorie-dense meals/week with Chad home |
| `anchorVarietyPeriodWeeks` | 3 | How often the Taco-Tuesday-style specific meal rotates |
| `poolHealthMinimum` | 5 | Active meals per watched category before a prompt |
| `snackInferenceMinPoints` | 3 | Purchases required before cadence inference |
| `reminderWindowStart/End` | 15:30 / 17:30 | Tonight-reminder time band (time varies within it) |
| `quietDownAfterSkips` | 2 | Consecutive skipped check-ins before the app quiets |
| `escalationMaxLevel` | 2 | "For real, go shopping" may yell — time-sensitive, novelty-rotated (D-3) |
| `escalationSnoozeMaxDays` | 7 | "For real, shut up" snooze auto-expires; escalation always returns (D-3) |
| `guaranteeLookaheadRuns` | 1 | How many confirmed runs ahead the guarantee covers |
| `componentFreshnessDefaultDays` | 2 | Producer→consumer leftover window |
| `chadAppetiteBase / FavoriteBoost` | 1.5 / +0.5 | Servings multiplier (per-member, all adjustable) |
| `memeFollowUpDelayHours` | 3 | Non-response before the friendly meme follow-up fires |
| `streakGraceHours` | 48 | Repair window after a missed streak day |
| `rewardSuggestionCooldownHours` | 36 | Keeps reward pairings special, not wallpaper |
| `voiceRegister` | mirror | EQ engine tone: mirror user's language ↔ mild ↔ full-sass |
| `dislikeFloorPerWeek` | 1 | Max times/week anyone faces a −2 meal (fairness floor) |
| `habituationHorizonDays` | 7 | Full envelope-pattern repeat spacing (user range 4–21) |
| `dimensionConstancyMaxDays` | 3 | Max days any single envelope dimension stays constant |
| `personaCastSize` | 4 | Stable recurring characters (range 3–5) |
| `personaRitualFreqPerWeek` | 1–3 | How often a persona's characteristic beat fires (varied, never daily) |
| `signatureFloorPerQuarter` | 2 | Minimum recurrences per Signature meal (the memory reps) |
| `wMethod` | 1.5 | Cook's method-affinity weight (grill-in-102° energy) |
| `cookNightStressorYieldSeverity` | 3 | Stressor severity at which a kid cook-night yields |
| `freezeTokensMax` | 3 | Bankable streak freezes, earned by activity |

Rules: tests reference `TuningConfig` values, never literals (except boundary tests that vary them). The weekly reflection may *propose* tunable changes; it never applies them without approval.
