# Moody seed workbook — the information that makes it *yours*

> **⚡ UPDATE 2026-07-09:** Your other Claude session already answered a big chunk of this (see `UNIFICATION_PLAN.md`). **Now answered:** item 1 (roster + needs), item 2 (Chad = 1.5×, up to 2× on favorites — tunable math, not flat double), the lunch half of item 5 (lunch IS in scope, per-person defaults), most of item 16's substance (the flour line: from-scratch wheat baking is the ban, packaged gluten is fine tagged unsafe; King Arthur GF = house standard), items 23–24 substantially (18 real meals with ingredients + GF status seeded, incl. a leftover chain), and the tuning numbers behind item 7's tank mapping. **Withdrawn:** item 22 (taste grid) — canon says scores must NOT be pre-seeded (the onboarding swipe pass creates them honestly). **Still genuinely yours to answer:** items 3, 4, 6, 8–15, 17 (Elsie's list — the seed has her *lifeline*, not her safe-foods list), 18–21, 25–27, plus three open decisions in the other build's DECISIONS.md (D-39, D-17, D-18) and the Wednesday question (Chad-ramen vs breakfast-for-dinner — which is real?).

Everything the app currently fakes with demo data, turned into gatherable pieces. Compiled from what the code actually consumes (every item maps to a real model field or a Wave-1 screen).

**This workbook obeys the app's own laws.** Fill things in any order. Blanks are fine — nothing blocks on anything else. Every item says how long it takes and who has the answer. Items marked **🤝 I draft, you edit** mean Claude Code does the writing and you just correct it. When something's filled in, drop it in `seed_data/` in any format — filled-in copy of this file, CSV, a Notes export, a photo of a paper list. I'll turn whatever lands there into app seed data.

**Start anywhere. The single highest-value 10 minutes is Part 1, item 7 (the effort rubric) — everything about meals gets rated against it.**

---

## Part 1 — Ten-minute solo passes ☕

Each of these is one coffee. Just you.

1. **Household roster.** Confirm the cast: names, spelling, anyone missing (regular dinner guests count if they affect portions). Who has a recurring cook night?
   `→ per person: name · dietary need (celiac / safe-foods-only / ×2 / none) · cook night`

2. **Chad's ×2 rule, precisely.** True double batch every meal? Protein-only? Meals where 1× is fine? This drives shopping quantities, not just the badge.
   `→ one paragraph + exceptions`

3. **Cook nights & the joy-cook truth.** Does Chad actually cook Wednesdays (is ramen real)? Is Saturday genuinely your love-to-cook slot, or demo fiction? Any other standing assignments?
   `→ per weekday: cook (if any) · slot type (kid-cook / joy-cook / normal)`

4. **Attendance baseline.** A typical week: who's home which nights (practices, clubs, work-late patterns). The solver plans around this; demo says "everyone home" 7 days, which is nobody's real life.
   `→ per weekday: who's present + recurring exceptions`

5. **Breakfast defaults + the lunch decision.** Each person's default weekday breakfast (the AM strip). And decide: are school lunches in Moody's scope, or dinners only?
   `→ per person: default breakfast · lunch in/out`

6. **Your actual palette.** 3–5 favorite colors — names or hexes, doesn't matter. **🤝 I draft, you edit**: I'll do the tint math and contrast validation (each color needs a readable dark companion — the math is my job, the taste is yours).
   `→ 3-5 colors, ordered by love`

7. **⭐ Your effort rubric.** What do 1/2/3 effort dots mean *for you*? Suggested axes: mid-cook decisions, ACTIVE-attention minutes (a passive 3-hour braise can be a 1; constant-stir risotto is a 3), pan/cleanup count, sensory load, interruptibility. Also confirm the tank mapping feels right: Fumes → only effort-1, Steady → up to 2, Full → anything.
   `→ three short definitions + tank-cap yes/no`

8. **Pinned traditions & honest rest days.** Is Taco Tuesday real? Other pinned nights? Which nights are *standing* planned skips (takeout Friday, leftovers Sunday) that should count as rest days — guilt-free by design, decided in advance?
   `→ per weekday: pinned tradition · standing rest-day flag`

9. **The real always-stocked shelf.** Walk the pantry: the 7–15 things your kitchen genuinely never runs out of. Each needs a GF-safety note (safe / has-GF-variant-note). Then pick THE fallback meal — cookable entirely from that shelf, forever. (Cross-checking every fallback ingredient against the shelf is my job.)
   `→ staples list + one fallback meal pick`

10. **Shopping reality.** Which store is the quick top-up? Weekly run: which day, which store? Bulk: actually Costco? Who shops, who does pickup?
    `→ per tier: store · usual day · who · pickup/in-store`

11. **Dinner time & duties.** Real eat time (varies by weekday?). Standing cook-mode duties — who chops, who sets, what's per-night vs. permanent.
    `→ eat time(s) + duty defaults`

12. **Streak seed — the honest version.** Fresh start, or do you have a real remembered best-run of home dinners? Seed only an honest number; the UI already handles "no PB yet" gracefully. Freeze tokens start at 0 and get earned.
    `→ "fresh" or {personal best: N}`

13. **Sass calibration.** Your 0–10 (demo default is 6). Per-persona overrides if someone should be gentler. And the no-go list: topics the cast must never joke about.
    `→ global number · overrides · no-go topics`

14. **Notification boundaries.** Daily check-in time (before the 4:30 wall — when exactly?), quiet hours, which check-in formats you tolerate (one-tap / casual text / voice), and whether personas may appear as lock-screen "texts" with their avatars.
    `→ time · quiet hours · allowed formats · persona-texts yes/no`

15. **Vent rules.** Confirm 24h self-shred. What should "make tonight zero-effort" ask before touching the plan? Are kept vents wanted at all? And the household data stance: this app holds a child's medical constraint — export/erase expectations, sync on/off.
    `→ short policy: shred window · consent wording · keep yes/no · data stance`

## Part 2 — One evening each, with the right person 🌙

16. **🔒 Caddie's celiac rule sheet** *(safety-critical — everything else can be wrong and fixed later; this one can't)*. The diagnosis in operational terms: strictness level, cross-contamination rules (shared toaster? colander? butter tub?), trusted GF certifications/brands, oat tolerance, co-occurring restrictions. This is what turns "Caddie GF ✓" from decoration into a guarantee.
    `→ hard rules (never) · conditional rules (ok if certified) · trusted brands · kitchen protocol`

17. **Elsie's safe-foods list — co-authored with Elsie.** ~10–20 items, each with its prep rule ("nothing touching", brand-specific, temperature). Always-yes vs. sometimes. Plus the hard-no textures/smells so the solver never proposes near-misses. Doing this *with* her is data-gathering and buy-in at once.
    `→ food · prep rule · brand · always/sometimes + a hard-no list`

18. **Who are Hannah, Cat, and Julie — really?** Keep them, rename them, or invent your own found-family (1–5 personas, any size works). Per persona: name, one-line role, a backstory hook ("met at my sister's 40th"), voice register, and who notices slumps vs. comebacks. **🤝 I draft, you edit**: give me the people; I'll write their message banks (sticky notes, nudges, celebrations, chef tips) for you to redline.
    `→ per persona: name · role · hook · voice · duty`

19. **The stressor interview — on yourself.** What makes 4:30pm hard, specifically: decision fatigue? sensory load? executive-function walls? interruptions? Which stressors should map to which accommodations (what should Fumes *actually do* for you)? **🤝 I draft, you edit**: I'll write the question set (~6–10, one per screen); you answer it.
    `→ answers + "when X, the app should Y" rules`

20. **Pantry baseline.** One walk-through beyond the staples: what's in pantry/fridge/freezer as have/low/out (the app shows confidence *softly*, never percentages), plus current leftovers with use-by. Also: how do you want to tell the app "we're actually out of tortillas"?
    `→ item: have/low/out · leftovers with dates`

## Part 3 — Family dinner-table games 🎲 (10 min each, everyone)

21. **Blob draft night.** Everyone picks their blob shape + color from the rendered variants in the app. (I'll put a picker screen or a printable sheet together when you're ready.)
    `→ per person: variant · color`

22. **The taste grid.** Meals × family members, 4-point scale (emoji works: 😍 🙂 😐 🚫). This is exactly what the future swipe-rating screens collect — hand-seeding it makes decide-for-me feel smart on day one. Also catches non-safety aversions (Caddie hating mushrooms is preference data, not celiac data).
    `→ grid, plus per-person ingredient vetoes`

## Part 4 — The meal spreadsheet 📋 (the big one: one evening, ~8–10 min × 15 meals)

23. **Shortlist first: 15 meals, cap 20.** Only meals the family ALREADY eats on repeat — no aspirational recipes. "Caddie already eats this safely" is pre-verification you can't get any other way. Memory prompts: camera roll, grocery receipts. 15 = two repeat-free weeks and keeps the swap math honest.

24. **Then fill the MVP columns** — template at [seed_data/meals-template.csv](seed_data/meals-template.csv):

    | column | what it is |
    |---|---|
    | name + keyword | "Build-your-own tacos" · "tacos" (keyword shows on week magnets) |
    | effort | one digit, rated against YOUR rubric (item 7) |
    | GF safe-because | one sentence + the specific swaps ("corn tortillas not flour, tamari not soy") |
    | Elsie plain option | exact components ("plain tortilla + cheese, nothing touching") — or honestly "none" |
    | ×2 note | what doubles + physical constraints ("needs 2nd sheet pan, +10 min") |
    | ingredients | store-speak names, each tagged produce/dairy/meat/grains/pantry/frozen + staple? flag |
    | kid-cookable | yes/no + supervision note (which steps stay adult-owned for GF safety) |
    | rotation tags | 2–4 tags + repeat tolerance ("fine weekly" / "max every 2 weeks") |
    | fallback | flag on exactly one meal (must cook from the staples shelf) |

25. **GF-verified brands sheet** *(ongoing, never finishes)*. One table, not per-meal: ambiguous categories (tortillas, pasta, oats, soy-sauce sub, broth, sausage) → known-safe brands → "re-check label every purchase?" flag. Per-meal safety notes point here.

## Part 5 — Lazy capture 📸 (never do these at a desk)

26. **Cook-mode step scripts.** 3–5 chunks per meal (prep/chop/sizzle/eat), each with rough minutes and who can own it. Capture by voice memo *the first time you cook each meal through the app* — never write these cold.
27. **Meal photos.** Your phone, the real table, next time each meal happens. Warm and homey, never stocky. Placeholder tiles in your palette until then — photos never block seeding.

---

## Handing it back

Drop anything into `seed_data/` — partial is welcome. What happens next per item is my job: palette → validated tokens; roster/rules/staples → typed seed data replacing `DemoSeed`; meal CSV → the real candidate pool; message banks → the persona layer; policies → defaults on the settings/notification screens as they get built.

**Priority order if you want one:** 7 (rubric) → 16 (Caddie sheet) → 23–24 (meal spreadsheet) → 17 (Elsie's list) → everything else whenever.
