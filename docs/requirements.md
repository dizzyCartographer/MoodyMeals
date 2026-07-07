# Moody — Meal Planning App
### Requirements (draft v2)

**Working name:** Moody
**Platform:** Native Swift / SwiftUI (iOS first)
**One-liner:** A mood- and capacity-aware meal planner that eliminates decision fatigue, leaves room for creativity, manages novelty, and plans around each family member's real food needs.

**The mission, in the user's own words:** *"I don't need one meal. I need all the meals, and I need them to be from me."* Friends can bring a casserole; they can't bring capacity. This app exists to answer "can you just make me better at this shit?" — not by replacing the cook, but by making the cook harder to knock over. Every feature should be tested against that sentence.

---

## Design principles (the reason this exists)

Built around how an AuDHD brain actually works. These are the constraints everything else serves:

1. **Kill decision fatigue.** The app answers "what's for dinner" *for* me most of the time — small curated choices, strong defaults, one-tap "just decide."
2. **Leave room for creativity.** Structure is scaffolding, not a cage. I can deviate, improvise, or swap without breaking the plan.
3. **Manage novelty deliberately — and cyclically.** Balance safe/comfort meals against new ones on a dial I control, including *how the app talks to me*. Nothing retires for good: things we're sick of **rest and cycle back later**. And we like anchored routines (e.g. Taco Tuesday) with a little variety every few weeks — ironically, that periodic novelty is what keeps us *on* the routine instead of burning out and abandoning it.
4. **Read the room ("moody").** The app senses the household's state — check-ins, calendar density, in-app behavior, even silence — and adapts what it suggests and how it talks to us. It meets us where we are; it doesn't try to manage anyone's mood.
5. **Respect object permanence.** If I can't see it, it doesn't exist — what's planned, what's on hand, what's for tonight must be visible.
6. **Plan around each eater.** Every family member has defined food needs, likes, and dislikes that the system actually uses.
7. **Curate what we love — and use it everywhere.** The app maintains a visible, user-owned corpus of each person's genuine delights (fandoms, memes, treats, humor, rituals) and draws on it in every generative context. That's what keeps it genuine, delightful, effective, and useful instead of generic.
8. **Lower the activation barrier.** Capturing and planning should work by *talking or dumping messy input* — no forms-first friction. Natural language is a primary way in, not a novelty.

---

## Core concepts / data model

- **Family Member** — a person with a **Food-Needs profile**: dietary requirements (e.g. Caddie: gluten-free/celiac), constraints (Elsie: meat-averse, needs protein+veg+starch), goals (Ria: heme iron, anti-inflammatory; Chad: high-calorie / appetite support), and per-item likes/dislikes.

- **Ingredient** — a food item. Amount is **optional** (see recipe types). Optionally carries nutrition data for calculation.

- **Recipe** — rolls up into meals. **Two types:**
  - **Loose / "Favorite"** — just a list of ingredients, no amounts, steps optional. Captures a meal I make from memory.
  - **Precise** — measured ingredients + steps. Enables accurate shopping quantities and nutrition math.
  - *(Naming note: "Favorite" collides with the Meal concept — suggest "Loose" vs "Precise." Your call.)*

- **Meal** — the atomic plannable unit. **Composed of any mix of:** zero or more recipes, and/or direct ingredients, and/or freeform text. A meal never *requires* a recipe (e.g. "Snack plate dinner," "Chipotle takeout," "Leftovers").
  - **Frequency target** per meal (e.g. weekly, biweekly, monthly, a few times a year) — drives auto-scheduling.
  - **Two-axis score per family member:** **Liking** (how much they enjoy it) and **Fit** (how good it is for *their* needs). Both feed the scheduler.
  - **Rotation state:** active / "not today" (temporary hide) / **"everybody's sick of this" → rest (cooldown)**. Sick-of-it meals aren't deleted; they go on a cooldown and **automatically become eligible again** after it passes. (Permanent retire exists but is the rare exception.)
  - **Tags:** effort level, theme/cuisine, dietary, and **"uniquely good for [food need]"** (e.g. iron-rich → good for Ria; calorie-dense → good for Chad).
  - **Safe food — denoted per family member.** Safe isn't a household-wide property: a meal is marked safe *for specific people* (safe for Chad, not for Elsie). Used for low-capacity days, appetite-suppressed stretches, and picky-moment fallbacks — the app can answer "what's safe for Chad tonight?"
  - **Recency:** last-scheduled/last-eaten date, for novelty management.

- **Plan entry** — date + slot + meal. Distributes onto the app calendar and syncs to my device calendar.

- **Snack** — a favorite item (not menu-scheduled) with per-member favorite flags and a **purchase cadence** (how often to rebuy). Cadence can be set manually or **inferred from purchase history**. Feeds the shopping list on its own rhythm.

- **Purchase history** — a running log of what was bought and when, used to infer snack/staple purchase frequency and flag likely run-outs.

---

## Functional requirements

### Natural language & voice — *high priority*
The primary, lowest-friction way to interact. It's a decision-fatigue and task-initiation accommodation, not a gimmick.
- **Conversational planning:** "plan me an easy iron-heavy week, kids all home" → drafts a plan I can accept/tweak.
- **Brain-dump → structure:** dictate or paste a messy meal idea and it parses into a Loose or Precise recipe (ingredients, optional steps).
- **Log by talking:** "we had tacos tonight, Chad loved it, Elsie skipped" → updates the meal, per-member ratings, and recency in one shot.
- **Compound feedback in one breath:** "this meal was perfect, everyone liked it, we should eat curry more often" → bumps every member's Liking *and* raises that meal's frequency target — no menus to dig through.
- **Quick edits & queries:** "swap Thursday for something low-effort," "what's iron-heavy that everyone likes?"
- **Voice capture** everywhere text entry exists (hands-busy / low-executive-function moments).
- **HomePod, EASILY.** Kitchen-voice is a primary surface, not an afterthought: "Hey Siri, what's for dinner?", "add milk to the midweek run," "we're having leftovers instead," "tossed the spinach" — all from across the kitchen with zero phone-fetching. If invoking it requires remembering awkward phrasing, it fails the activation-barrier test.

### Family & food-needs profiles
- Define a profile per family member: dietary requirements, restrictions, goals, likes, dislikes.
- Profiles drive suggestion filtering, constraint-checking, and the "uniquely good for X" tagging.

### Meal & recipe library
- Create meals from **any mix of recipes and/or loose ingredients and/or freeform notes**.
- Two recipe types (Loose vs Precise) as above; amounts optional in Loose.
- Tag meals: effort, theme, dietary, food-need fit, and **safe-food status per family member** (safe *for whom*, not just "safe").
- **Score each meal per member on two axes — Liking and Fit** (see scheduler). Fast to set, and updatable by voice ("Chad loved it").
- Mark a meal **"not today"** (temporary hide) for when a safe food flips to a no — per person or household-wide.
- Mark a meal **"everybody's sick of this"** → goes on cooldown (out of rotation, auto-replaced) and **cycles back in automatically** once rested. Permanent retire is available but rarely needed.

### Shopping list
- **Both meals and recipes flow into the shopping list** — not recipes only. Loose meals/ingredients contribute items (no amount is fine); Precise recipes contribute quantities.
- Consolidate + deduplicate across a date range; sum amounts where present, list plain where not.
- **Integrate with shopping apps** (export/handoff; Instacart is the priority target given its API — see technical notes).

### The shopping guarantee & tiered runs
**The promise: if I shop per the app, I ALWAYS have the ingredients for tonight's meal.** No last-minute Food Lion runs. This is the core contract of the shopping system — every planned meal between now and the next scheduled run must be fully covered by the list, and the app should sanity-check this ("Thursday's meal needs fresh cod — flagging it for the midweek run, or want to swap Thursday?").
- **Tiered run cadence** (user-configurable, these are the defaults):
  - **Costco** — every 1–2 months: bulk staples, freezer stock.
  - **Standard grocery** — weekly: the bulk of the plan's ingredients.
  - **Midweek mini-run** — milk + produce top-up (short list by design).
- The app **routes each item to the right run** based on perishability, need-by date (which meal it's for), and store type — fresh fish never rides the Costco run, milk lands midweek.
- **Calendar-aware shop scheduling:** the app reads my calendar and **suggests when to shop** — proposing realistic windows around commitments, adapting when a week gets dense, and adding the run to the calendar/reminders once confirmed.
- If a run is skipped or delayed, the app re-checks the guarantee and flags exactly which upcoming meals are at risk, offering swaps to what's on hand.

### Photo-based inventory (zero-upkeep by design)
Manual inventory management is dead on arrival — I will never keep it up. The only viable version is nearly effortless:
- **Snap a photo of the fridge / pantry / freezer** → the app identifies what it can see and updates the inventory.
- **Then just have a conversation about what wasn't clear:** "is that container on the second shelf leftovers or sauce?" / "I see two milks — is one almost empty?" Quick voice-or-text back-and-forth, not forms.
- Inventory also updates passively from shopping runs (bought = added) and cooked meals (used = decremented), so photos are a periodic *true-up*, not a chore.
- Inventory is **best-effort, never blocking** — the app treats it as a helpful belief about the kitchen, flags uncertainty honestly, and asks rather than assumes.
- Feeds everything else: "cook what I have," the shopping-guarantee check, and run-out warnings. Also serves object permanence — the app becomes the *visible* answer to "what do we actually have?"

### Fridge-aware storage optimization
- Tell the app my fridge model (or dimensions) → it pulls the specs and knows the real interior geometry: shelf heights, door bins, drawers.
- **Recommends specific storage containers that maximize both space and visibility** — clear, stackable, sized to my actual shelves — directly serving the object-permanence rule (clear containers, front-and-visible).
- Can suggest a zone layout ("leftovers front-and-center at eye level, produce in clear bins, Chad's grab-and-go on the door") and, paired with inventory photos, flag when things drift to the invisible back.

### Waste logging → learning our real habits
- **Dead-simple logging when produce (or anything) gets thrown out** — one tap or one sentence ("tossed half the spinach again").
- The app treats waste as ground truth about the gap between planned and actual eating, and adapts: buy smaller quantities, route that item to the midweek run so it's fresher, schedule meals that use it sooner after purchase, or stop auto-adding it.
- Waste patterns surface gently in the weekly reflection ("spinach has been tossed 3 weeks running — swap to frozen, buy less, or drop it?"). No guilt framing, ever — it's data, not judgment.

### "For real, go shopping" escalation
The app knows the difference between my *planned* shopping and my *intuitive last-minute* shopping — and calls it.
- When skipped/postponed runs plus low inventory put the meal-plan guarantee at risk, escalate past a normal reminder: **"For real — you need to do your actual shopping, not just grab-and-dash. Here's what breaks this week if you don't."**
- Concrete stakes, not nagging: name the meals at risk and the days they fall on.
- Uses the notification-novelty system so the escalation actually lands instead of blending into ignored pings.

### Snacks & replenishment
- Manage **each family member's favorite snacks** as a tracked list.
- **Intelligent history search:** infer purchase frequency per snack/staple from purchase history ("we go through Cojack sticks about every 5 days"), and auto-add them to the shopping list on that cadence.
- Prompt when something's likely running low based on inferred frequency; cadence is always user-overridable.
- Purchase data can come from in-app logging and, where available, shopping-app order history (e.g. Instacart).

### Auto-scheduling
- Auto-populate the calendar **out to 12 months**.
- Respect each meal's **frequency target** and recency so the mix stays balanced.
- **Themed anchors:** support recurring theme slots (e.g. Taco Tuesday) that stay fixed for routine, while the **specific meal within the theme varies every few weeks** — structure plus enough novelty to keep us actually sticking to it.
- **Cycle rested meals back in** once their cooldown passes, so old favorites return on their own.
- **Optimize for two objectives at once: maximize total Liking *and* total Fit across the family.** User can weight which matters more.
- **Hard constraints vs soft optimization:** dietary *requirements* are hard and never violated (Caddie never gets gluten); Fit scores (e.g. iron for Ria, calories for Chad) are soft targets the scheduler pushes toward.
- Weight by capacity and calendar load: busy nights → low-effort meals; birthdays/holidays → special meals.
- Skip meals flagged "everybody's sick of this" and fill the gap with a fresh pick.
- Always editable — accept, tweak, shuffle, or lock individual entries.

### Coverage / pool health
- Monitor the meal pool by category (e.g. a food-need like iron-rich, an effort tier, a cuisine, or "meals Elsie likes").
- **When a category runs low, prompt me to search for/add meals meeting that criteria** — keeps the rotation from thinning out or getting stale, and works with natural-language search.

### Occasions — holiday & birthday menus
- Plan **special menus for holidays and birthdays** as first-class events, distinct from the daily rotation.
- Reads celebrations from the calendar and prompts ahead of time ("Caddie's birthday is in 3 weeks — plan her menu?"), with lead-time reminders for prep and shopping (special ingredients get routed onto runs early enough).
- Saved occasion menus are reusable and evolvable — last Thanksgiving's menu is next Thanksgiving's starting point.

### All-time favorites & core-memory meals
- A protected tier above ordinary "hits": **all-time favorites tied to key core-memory moments** — the birthday dinner someone always asks for, the meal that means snow days, the dish that *is* Christmas Eve.
- Save each with **who it belongs to and what moment it marks** (a name/note like "Elsie's first-day-of-school dinner"), so the meaning travels with the meal.
- **Exempt from fatigue mechanics** — never cooled down, retired, or "optimized" away by the scheduler. These aren't in the rotation; they're the family canon.
- Surfaced at the right moments: suggested for their occasion, findable by person ("what are Chad's all-timers?"), and available to the occasion planner.

### Breakfast — the opposite pattern
Breakfast doesn't behave like dinner. As a household we're **bad at eating breakfast**, and we each latch onto **one thing we eat every single day** — until we suddenly hate it and need to switch. So breakfast is *monotony-seeking until burnout*, the inverse of dinner's variety.
- **Per-person "current breakfast"** — a set-and-forget daily default, not a rotation. No daily decision.
- **Burnout swap** — one tap / "I'm sick of this breakfast" → the app offers a few alternatives and sets the new default. The old one **rests and cycles back later** (we always come back to things). (Reuses the cooldown mechanic, scoped to one person's breakfast.)
- **Keep it stocked** — the current breakfast's staples ride the snack/replenishment cadence so there's never a "nothing to grab" gap that turns into a skipped meal.
- **Dead-simple, grab-and-go** defaults, since adherence — not variety — is the actual problem here. Optional gentle nudge, never nagging.

### Calendar sync (EventKit)
- Read device-calendar events to inform scheduling (busy nights, celebrations).
- Write planned meals back to the device calendar; keep in sync on edits.

### "Tonight's menu" reminders — novelty-managed
- A daily reminder of what's on the menu tonight.
- **Deliberately varied to fight notification blindness:** rotating message copy, varied emoji/icon, varied color treatment, and **varying time of day**, so ADHD novelty-seeking doesn't tune it out.
- *(iOS caveat in technical notes: message/emoji/time/sound vary freely; true per-notification icon+color is limited by iOS — richest visual variety lives in the in-app Today card.)*

### Mood / capacity-aware suggestions ("moody")
- One-tap capacity setting (Low / Med / High).
- Returns a **small set (~3)** filtered by capacity, dietary needs, and recency — plus a "just decide for me" pick.

### "Read the room" — daily + weekly feedback loop
The engine behind "moody": the app's job is to **sense the household's state and adapt itself** — not to manage anyone's mood. It reads the room, then meets us where we are.
- **Signals it reads:** the daily check-in (mood/energy/capacity), calendar density, my behavior in the app (skipped plans, swaps to low-effort, ignored notifications, silence), and the weekly reflection. Behavioral signals matter because on the worst days I won't answer a check-in — *not responding is itself information*.
- **Daily:** tune tonight's suggestion, reminder tone/timing, and how much it asks of me. Rough day → fallback meal offered first, fewer questions, quieter.
- **Weekly reflection:** a short "how did the week run" that tunes frequencies, the novelty dial, and next week's plan.
- **Closed loop:** it learns which adaptations actually helped (e.g. low-effort picks on dense days improved follow-through) and gets better at reading us over time.
- **Notification novelty is mandatory here, not decorative — the loop fails without it.** Rotate the *modality and style* of the check-in: sometimes "talk to me" (voice/conversational), sometimes a casual text-style message, sometimes a single tap — plus varied timing, tone, and phrasing. A predictable daily ping gets tuned out within a week and the whole loop dies.
- Low-pressure by design: skipping is always fine; it never nags — it just reads the skip and adjusts.

### Novelty management
- Recency down-ranks recently-eaten meals automatically.
- A **comfort ↔ adventurous dial** controls how often something new/underused surfaces.

### Nutrition & needs-matching
- Calculate nutritional info per meal (best-effort; accurate only where amounts exist — Precise recipes).
- Auto-flag meals that are **uniquely good for a specific member's food need** (e.g. high heme iron → Ria, high calorie → Chad), on top of manual tagging.

---

## Platform / technical notes

- Native **Swift / SwiftUI**, iOS first; local-first store (**SwiftData** or Core Data), no account required.
- **EventKit** for Calendar + Reminders.
- **Varied reminders** via local notifications (**UNUserNotificationCenter**): freely vary text, emoji, sound, interruption level, and schedule time. Per-notification custom icon/tint is **not** natively supported — plan the strong visual novelty in the in-app Today view; treat notification-level color/icon as a stretch.
- **Nutrition** needs an ingredient nutrition source (e.g. USDA FoodData Central API, or a paid API like Edamam/Spoonacular). This is a real external dependency — phase accordingly.
- **Natural language / voice:** dictation via the **Speech** framework; parsing/planning via an LLM. Real fork — **on-device** (Apple Foundation Models / a local model: private, no network, but lighter capability) vs **cloud** (Claude/OpenAI: more capable, but family/health-adjacent text leaves the device). Given the data, on-device or a privacy-scoped hybrid is worth serious consideration.
- **Photo inventory** needs vision: on-device recognition (Vision framework / local VLM) is private but weaker at cluttered-fridge scenes; a cloud multimodal model is much better at "what's in this photo + converse about it" but sends kitchen photos off-device. Same fork as the language engine — likely the same decision.
- **HomePod / Siri:** built on **App Intents** — the framework that exposes app actions to Siri (and Shortcuts/widgets). Realistic expectations: well-defined intents ("what's for dinner," "add X to the list," "log that we tossed Y") work great hands-free; fully open-ended conversation through HomePod is constrained by what Siri passes through, so deep conversational work stays in-app while kitchen quick-hits live on the HomePod. Design intent phrasings around natural speech — no magic words.
- **Fridge specs:** model-number lookup against manufacturer specs where findable; manual dimensions as the fallback.
- **Shopping integration:** Instacart has a usable API (priority). Others (e.g. AnyList) lack one — fall back to markdown/plain-text export or Reminders.
- **Data portability:** export/import recipes and plans as **markdown / plain text** to avoid lock-in.
- Low-friction UI: few taps, large targets, minimal cognitive load — the interface itself is an accommodation.
- Privacy: family/health-adjacent data stays on device.

---

## Suggested phasing (to keep it buildable)

**Phase 1 (core):** natural-language + voice capture (planning, brain-dump-to-recipe, log-by-talking); family + food-needs profiles; meal/recipe library (both recipe types); meals → shopping list with export; manual + auto-scheduling with per-meal frequency out to 12 months; calendar sync; capacity suggestions + novelty dial; per-member ratings; tonight reminders with varied message/emoji/time.

**Phase 2:** nutrition calculation + auto "uniquely good for X" tagging (needs nutrition data source); deep Instacart integration; richer notification visual novelty if feasible.

---

## Open questions

- Recipe type naming — keep "Favorite," or switch to "Loose" to avoid collision with "Meal"?
- **Natural-language engine — on-device (private) vs cloud (more capable) vs hybrid?** Shapes a lot downstream.
- Capacity is set via the daily check-in — should it *also* infer from calendar busyness as a fallback when I skip the check-in?
- Meal slots for v1: dinner (varied rotation) + breakfast (per-person daily default) confirmed — is lunch in scope too, or mostly self-packed/skip?
- Nutrition data source — free (USDA) vs paid (Edamam/Spoonacular) — any budget preference?
- Shopping target beyond Instacart worth supporting at launch?
- Any need to share/sync with Chuck, or strictly single-device for now?
