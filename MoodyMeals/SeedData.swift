import Foundation
import SwiftData

/// M0-6 — the five household members + ~16 starter meals, per the
/// requirements doc and canon decisions. Idempotent: a second load is a no-op.
///
/// Deliberately NOT seeded (canon):
/// - MemberMealScores — cold-start rule (PT-1/Step 4f): day one has zero
///   Liking/Fit data; onboarding's swipe pass creates it, not the seed.
/// - No "sheet-pan" tags anywhere (D-4: that framing stresses Ria).
enum SeedData {

    private static let rulesBackfillKey = "foodRulesBackfilled.v1"

    @MainActor
    static func loadIfNeeded(into context: ModelContext) throws {
        // Idempotency: members are the sentinel — any present means seeded.
        let existing = try context.fetchCount(FetchDescriptor<FamilyMember>())
        guard existing == 0 else {
            // FR-1 arrived after some stores were seeded — backfill once.
            try backfillFoodRulesIfNeeded(into: context)
            return
        }

        // ── The five (requirements doc) ─────────────────────────
        let ria = FamilyMember(
            name: "Ria", isAdult: true,
            softGoals: [.hemeIron, .antiInflammatory],
            notes: "loves to cook; decision-fatigued at 4:30",
            methodAffinity: [CookMethod.grill.rawValue: 2,
                             CookMethod.oven.rawValue: -2] // D-28: a 7:1 revealed law
        )
        let chuck = FamilyMember(name: "Chuck", isAdult: true)
        let caddie = FamilyMember(
            name: "Caddie", isAdult: false,
            hardRequirements: [.glutenFree], // celiac — §1 hard constraint
            notes: "celiac; unverified = unsafe (HC-3)"
        )
        let elsie = FamilyMember(
            name: "Elsie", isAdult: false,
            softGoals: [.proteinVegStarch], // D-35: full-plate nudge stays;
            notes: "meat-averse; sandwich basics + garbanzo beans always stocked (D-6)"
        )
        let chad = FamilyMember(
            name: "Chad", isAdult: false,
            softGoals: [.highCalorie],
            notes: "14; appetite support",
            appetiteBase: 1.5, appetiteFavoriteBoost: 0.5 // §8 defaults (per-member data, D-35)
        )
        [ria, chuck, caddie, elsie, chad].forEach { context.insert($0) }

        try Self.insertSeedRules(ria: ria, chuck: chuck, chad: chad, into: context)


        // ── Ingredients (verified / unverified / explicitly-gluten mix) ──
        let gfShells = Ingredient(name: "GF taco shells", perishability: .pantry,
                                  isGlutenFreeVerified: true)
        let groundBeef = Ingredient(name: "ground beef", perishability: .freshShort,
                                    isGlutenFreeVerified: true)
        let chickenThighs = Ingredient(name: "chicken thighs", perishability: .freshShort,
                                       isGlutenFreeVerified: true)
        let whiteBeans = Ingredient(name: "white beans", perishability: .pantry,
                                    isGlutenFreeVerified: true)
        let greenChiles = Ingredient(name: "green chiles", perishability: .pantry,
                                     isGlutenFreeVerified: true)
        let cumin = Ingredient(name: "cumin", perishability: .pantry,
                               isGlutenFreeVerified: true)
        let gfBroth = Ingredient(name: "GF chicken broth", perishability: .pantry,
                                 isGlutenFreeVerified: true) // NL-3's "that GF broth"
        let burgerPatties = Ingredient(name: "burger patties", perishability: .freshShort,
                                       isGlutenFreeVerified: true)
        let regularBuns = Ingredient(name: "burger buns (regular)", perishability: .pantry,
                                     isGlutenFreeVerified: false) // D-30: normal purchase, not-Caddie-safe
        let rice = Ingredient(name: "rice", perishability: .pantry,
                              isGlutenFreeVerified: true)
        let eggs = Ingredient(name: "eggs", perishability: .refrigeratedLong,
                              isGlutenFreeVerified: true)
        let gfTamari = Ingredient(name: "GF tamari", perishability: .pantry,
                                  isGlutenFreeVerified: true)
        let regularSoySauce = Ingredient(name: "regular soy sauce", perishability: .pantry,
                                         isGlutenFreeVerified: false) // HC-2's example
        let gfPancakeMix = Ingredient(name: "King Arthur GF pancake mix", perishability: .pantry,
                                      isGlutenFreeVerified: true) // D-30 house standard
        let gfMacAndCheese = Ingredient(name: "GF mac & cheese box", perishability: .pantry,
                                        isGlutenFreeVerified: true)
        let spaghetti = Ingredient(name: "spaghetti (regular)", perishability: .pantry,
                                   isGlutenFreeVerified: false) // D-30: contained gluten, fine
        let marinara = Ingredient(name: "marinara", perishability: .pantry,
                                  isGlutenFreeVerified: true)
        let salmon = Ingredient(name: "salmon", perishability: .freshShort,
                                isGlutenFreeVerified: true)
        let broccoli = Ingredient(name: "broccoli", perishability: .freshShort,
                                  isGlutenFreeVerified: true)
        let gfTenders = Ingredient(name: "gluten free chicken tenders frozen", perishability: .freezer,
                                   isGlutenFreeVerified: true) // RT-6's export-text example
        let crispyFries = Ingredient(name: "crispy frozen fries", perishability: .freezer,
                                     isGlutenFreeVerified: nil) // HC-4: UNVERIFIED on purpose
        let flankSteak = Ingredient(name: "flank steak", perishability: .freshShort,
                                    isGlutenFreeVerified: true)
        let gfBananaMix = Ingredient(name: "King Arthur GF banana bread mix", perishability: .pantry,
                                     isGlutenFreeVerified: true)
        let oats = Ingredient(name: "rolled oats (GF)", perishability: .pantry,
                              isGlutenFreeVerified: true)
        [gfShells, groundBeef, chickenThighs, whiteBeans, greenChiles, cumin, gfBroth,
         burgerPatties, regularBuns, rice, eggs, gfTamari, regularSoySauce, gfPancakeMix,
         gfMacAndCheese, spaghetti, marinara, salmon, broccoli, gfTenders, crispyFries,
         flankSteak, gfBananaMix, oats].forEach { context.insert($0) }

        // ── Helpers ─────────────────────────────────────────────
        func looseRecipe(_ title: String, _ ingredients: [Ingredient]) -> Recipe {
            let r = Recipe(title: title, kind: .loose)
            context.insert(r)
            r.items = ingredients.map { RecipeItem(ingredient: $0) }
            return r
        }

        // ── ~16 starter meals ───────────────────────────────────
        // 1. The Taco-Tuesday-tagged meal (AC requirement)
        let tacos = Meal(title: "Tacos (GF shells)", effort: .simple,
                         themeTags: ["mexican"], frequencyTarget: .weekly,
                         methods: [.stovetop])
        context.insert(tacos)
        tacos.recipes = [looseRecipe("Weeknight tacos", [gfShells, groundBeef])]

        // 2. The all-time favorite (AC requirement) — NL-3's white chicken chili
        let chili = Meal(title: "White chicken chili", effort: .involved,
                         themeTags: ["cozy"], methods: [.stovetop],
                         isAllTimeFavorite: true,
                         coreMemoryNote: "Elsie's first-day-of-school dinner",
                         coreMemoryOwner: elsie)
        context.insert(chili)
        chili.recipes = [looseRecipe("Mom's white chicken chili",
                                     [chickenThighs, whiteBeans, greenChiles, cumin, gfBroth])]

        // 3. Burgers — Chad's volume meal (SCH-15's shape); buns not-Caddie-safe (D-30)
        let burgers = Meal(title: "Burgers", effort: .simple, methods: [.grill])
        context.insert(burgers)
        burgers.directItems = [RecipeItem(ingredient: burgerPatties),
                               RecipeItem(ingredient: regularBuns)]

        // 4–5. The leftover chain (D-4): producer → consumer
        let chickenRice = Meal(title: "Chicken & rice", effort: .simple,
                               producesComponents: ["cooked rice"], // cook extra on purpose
                               methods: [.stovetop])
        context.insert(chickenRice)
        chickenRice.directItems = [RecipeItem(ingredient: chickenThighs),
                                   RecipeItem(ingredient: rice)]
        let friedRice = Meal(title: "Fried rice", effort: .simple,
                             requiresComponents: ["cooked rice"], // busy-night hero (D-11)
                             methods: [.stovetop])
        context.insert(friedRice)
        friedRice.directItems = [RecipeItem(ingredient: eggs),
                                 RecipeItem(ingredient: gfTamari)]
        // D-47 (Ria): fried rice is THE chain example — assigned to a kid (D-6).
        // liking/fit stay 0: a cook-night tag is not taste signal (PT-1 intent holds).
        context.insert(MemberMealScore(member: chad, meal: friedRice, likesToCook: true))

        // 6. Breakfast-for-dinner (D-1: calm-day gated, multi-slot)
        let pancakes = Meal(title: "Pancake night", effort: .simple,
                            slots: [.breakfast, .dinner], requiresCalmDay: true,
                            methods: [.griddle])
        context.insert(pancakes)
        pancakes.directItems = [RecipeItem(ingredient: gfPancakeMix),
                                RecipeItem(ingredient: eggs)]

        // 7. Eating out — nuclear option (D-7), freeform-only (DM-3)
        let chipotle = Meal(title: "Chipotle takeout",
                            freeformNotes: "everyone orders their own",
                            effort: .noCook, isEatingOut: true)
        context.insert(chipotle)

        // 8. GF mac & cheese — classic safe-food candidate
        let gfMac = Meal(title: "GF mac & cheese", effort: .assembly,
                         methods: [.stovetop])
        context.insert(gfMac)
        gfMac.directItems = [RecipeItem(ingredient: gfMacAndCheese)]

        // 9. Spaghetti — contained gluten, normal purchase, not-Caddie-safe (D-30)
        let spaghettiNight = Meal(title: "Spaghetti (regular pasta)", effort: .simple,
                                  themeTags: ["italian"], methods: [.stovetop])
        context.insert(spaghettiNight)
        spaghettiNight.directItems = [RecipeItem(ingredient: spaghetti),
                                      RecipeItem(ingredient: marinara)]

        // 10. Grilled salmon — Ria's iron/anti-inflammatory fit, loved method
        let salmonNight = Meal(title: "Grilled salmon & broccoli", effort: .simple,
                               methods: [.grill])
        context.insert(salmonNight)
        salmonNight.directItems = [RecipeItem(ingredient: salmon),
                                   RecipeItem(ingredient: broccoli)]

        // 11. Beef stir-fry — HC-2's shape if regular soy sauce is used
        let stirFry = Meal(title: "Beef stir-fry (regular soy)", effort: .simple,
                           methods: [.stovetop])
        context.insert(stirFry)
        stirFry.directItems = [RecipeItem(ingredient: flankSteak),
                               RecipeItem(ingredient: regularSoySauce)]

        // 12. Snack plate dinner — legit meal, zero cooking
        let snackPlate = Meal(title: "Snack plate dinner",
                              freeformNotes: "cheese, fruit, crackers, whatever's around",
                              effort: .noCook)
        context.insert(snackPlate)

        // 13. GF tenders & fries — the fries are HC-4's unverified flag case
        let tenders = Meal(title: "GF tenders & crispy fries", effort: .assembly,
                           methods: [.airFryer])
        context.insert(tenders)
        tenders.directItems = [RecipeItem(ingredient: gfTenders),
                               RecipeItem(ingredient: crispyFries)]

        // 14. Leftovers night
        let leftovers = Meal(title: "Leftovers night",
                             freeformNotes: "fridge cleanout", effort: .noCook)
        context.insert(leftovers)

        // 15. GF banana bread — GF-mix baking is alive and well (D-30)
        let bananaBread = Meal(title: "GF banana bread (King Arthur mix)",
                               effort: .involved, themeTags: ["baking"],
                               methods: [.oven])
        context.insert(bananaBread)
        bananaBread.directItems = [RecipeItem(ingredient: gfBananaMix),
                                   RecipeItem(ingredient: eggs)]

        // 16. Oatmeal — a breakfast-slot default candidate (BF-1)
        let oatmeal = Meal(title: "Oatmeal", effort: .assembly,
                           slots: [.breakfast], methods: [.stovetop])
        context.insert(oatmeal)
        oatmeal.directItems = [RecipeItem(ingredient: oats)]

        // 17–18. Lunch candidates (D-40: lunch is in scope, breakfast pattern)
        let sandwiches = Meal(title: "Sandwiches", effort: .assembly,
                              slots: [.lunch], methods: [.noCook])
        context.insert(sandwiches)
        let leftoverLunch = Meal(title: "Leftovers lunch",
                                 freeformNotes: "whatever the fridge offers",
                                 effort: .noCook, slots: [.lunch])
        context.insert(leftoverLunch)

        // ── Anchors ─────────────────────────────────────────────
        // D-1: Wednesday breakfast-for-dinner anchor ships seeded but OFF.
        context.insert(ThemeAnchor(weekday: 4, slot: .dinner,
                                   themeTag: "breakfast-for-dinner",
                                   isActive: false))

        // ── Elsie's lifeline (D-6): ALWAYS on hand, under the guarantee ──
        let sandwichBread = Ingredient(name: "sandwich bread", perishability: .pantry,
                                       isGlutenFreeVerified: false) // D-30: normal purchase
        let garbanzos = Ingredient(name: "garbanzo beans", perishability: .pantry,
                                   isGlutenFreeVerified: true)
        context.insert(sandwichBread)
        context.insert(garbanzos)
        context.insert(StapleItem(name: "sandwich bread", minOnHand: "1 loaf",
                                  ingredient: sandwichBread, forMember: elsie))
        context.insert(StapleItem(name: "garbanzo beans", minOnHand: "2 cans",
                                  ingredient: garbanzos, forMember: elsie))

        // ── Snacks (SN-1's example; cadence stays nil until inferred, SN-5) ──
        let cojack = Snack(name: "Cojack sticks")
        context.insert(cojack)
        cojack.favoriteOf = [chad, elsie]

        try context.save()
    }

    /// The five D-42 rules, inserted with the seed AND by the backfill.
    @MainActor
    private static func insertSeedRules(ria: FamilyMember?, chuck: FamilyMember?,
                                        chad: FamilyMember?,
                                        into context: ModelContext) throws {
        // Caddie: NO rule row — the D-44 band model carries her protection.
        // Elsie: NO rule — dinners are the objective, staples the net (D-35).
        var rules: [FoodRule] = []
        if let chuck {
            rules.append(FoodRule(member: chuck, direction: .limit,
                                  subject: "red meat & pork",
                                  reason: "high cholesterol",
                                  frequencyWindowDays: 7))
        }
        if let ria {
            rules.append(FoodRule(member: ria, direction: .boost,
                                  subject: "iron-rich foods", reason: "low iron"))
            rules.append(FoodRule(member: ria, direction: .boost,
                                  subject: "fiber", reason: "general health"))
            rules.append(FoodRule(member: ria, direction: .boost,
                                  subject: "anti-inflammatory foods",
                                  reason: "inflammation"))
        }
        if let chad {
            rules.append(FoodRule(member: chad, direction: .boost,
                                  subject: "calorie-dense meals",
                                  reason: "14 and growing"))
        }
        rules.forEach { context.insert($0) }
        context.insert(AppInfo(key: rulesBackfillKey, value: "1"))
        try context.save()
    }

    /// FR-1 migration: stores seeded before FoodRule existed get the same
    /// five rules ONCE (AppInfo marker — deliberately deleting rules later
    /// never resurrects them). Members matched by seed name; a renamed
    /// member simply doesn't backfill — the rules editor is their path.
    @MainActor
    static func backfillFoodRulesIfNeeded(into context: ModelContext) throws {
        let marked = try context.fetch(FetchDescriptor<AppInfo>())
            .contains { $0.key == rulesBackfillKey }
        guard !marked else { return }
        let members = try context.fetch(FetchDescriptor<FamilyMember>())
        func member(_ name: String) -> FamilyMember? {
            members.first { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }
        }
        try insertSeedRules(ria: member("Ria"), chuck: member("Chuck"),
                            chad: member("Chad"), into: context)
    }
}
