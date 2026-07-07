import XCTest
import SwiftData
@testable import MoodyMeals

/// M0-3 acceptance: loose recipe with nil amounts persists; TC-HC-6 passes.
/// Same round-trip discipline as PeopleModelTests: save on mainContext,
/// assert through a FRESH ModelContext so decode-from-store is exercised.
final class FoodModelTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Ingredient

    @MainActor
    func test_ingredientRoundTrip_triStateGFSurvivesTheStore() throws {
        // The celiac rule lives in this tri-state: nil must come back nil,
        // never coerced to false (and vice versa).
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(Ingredient(name: "GF broth", perishability: .pantry,
                                  isGlutenFreeVerified: true))
        context.insert(Ingredient(name: "soy sauce", perishability: .pantry,
                                  isGlutenFreeVerified: false))
        context.insert(Ingredient(name: "crispy fries", perishability: .freezer,
                                  preferredRunTier: .bulk,
                                  isGlutenFreeVerified: nil)) // unverified (HC-4 shape)
        try context.save()

        let fresh = ModelContext(container)
        let all = try fresh.fetch(FetchDescriptor<Ingredient>())
        let broth = try XCTUnwrap(all.first { $0.name == "GF broth" })
        let soy = try XCTUnwrap(all.first { $0.name == "soy sauce" })
        let fries = try XCTUnwrap(all.first { $0.name == "crispy fries" })

        XCTAssertEqual(broth.isGlutenFreeVerified, true)
        XCTAssertEqual(soy.isGlutenFreeVerified, false)
        XCTAssertNil(fries.isGlutenFreeVerified,
                     "nil must survive as nil — unverified is a distinct state")
        XCTAssertEqual(fries.preferredRunTier, .bulk) // RT-5 groundwork
        XCTAssertEqual(fries.perishability, .freezer)
    }

    // MARK: - Loose recipes (DM-2 persistence half)

    @MainActor
    func test_DM2_looseRecipeWithNilAmounts_persists() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let chicken = Ingredient(name: "chicken thighs", perishability: .freshShort)
        let beans = Ingredient(name: "white beans", perishability: .pantry)
        let recipe = Recipe(title: "white chicken chili", kind: .loose)
        context.insert(chicken)
        context.insert(beans)
        context.insert(recipe)
        recipe.items = [RecipeItem(ingredient: chicken), RecipeItem(ingredient: beans)]
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Recipe>()).first)
        XCTAssertEqual(fetched.kind, .loose)
        XCTAssertEqual(fetched.items.count, 2)
        XCTAssertTrue(fetched.items.allSatisfy { $0.amount == nil },
                      "loose recipes carry no amounts — nil is valid, not an error")
        XCTAssertTrue(fetched.steps.isEmpty)
    }

    // MARK: - Mixed precision (DM-4 as resolved by D-36)

    @MainActor
    func test_DM4_D36_preciseRecipeWithAmountlessItem_isValidMixed() throws {
        // D-36 (Ria, option c): measured items keep amounts, seasoning rides
        // along by taste. Never rejected, never downgraded to loose.
        let container = try makeContainer()
        let context = container.mainContext

        let chicken = Ingredient(name: "chicken thighs", perishability: .freshShort)
        let cumin = Ingredient(name: "cumin", perishability: .pantry)
        let recipe = Recipe(title: "white chicken chili", kind: .precise,
                            steps: ["brown the thighs", "simmer everything"])
        context.insert(chicken)
        context.insert(cumin)
        context.insert(recipe)
        recipe.items = [
            RecipeItem(ingredient: chicken, amount: 2, unit: "lb"),
            RecipeItem(ingredient: cumin), // by taste — amount-less on purpose
        ]
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Recipe>()).first)
        XCTAssertEqual(fetched.kind, .precise,
                       "mixed precision must NOT downgrade the recipe")
        let amounts = fetched.items.map(\.amount)
        XCTAssertTrue(amounts.contains(2), "measured amounts survive")
        XCTAssertTrue(amounts.contains(nil), "amount-less items survive alongside")
    }

    // MARK: - HC-6 ⚠️ (safety-critical)

    @MainActor
    func test_HC6_unverifiedIngredientPropagatesToMeal_amountsIrrelevant() throws {
        // Given a Loose recipe with nil amounts including one unverified
        // ingredient → unverified status propagates to the MEAL.
        let container = try makeContainer()
        let context = container.mainContext

        let brothGF = Ingredient(name: "GF broth", perishability: .pantry,
                                 isGlutenFreeVerified: true)
        let beansGF = Ingredient(name: "white beans", perishability: .pantry,
                                 isGlutenFreeVerified: true)
        let mysteryBroth = Ingredient(name: "that broth", perishability: .pantry,
                                      isGlutenFreeVerified: nil) // unverified

        let recipe = Recipe(title: "white chicken chili", kind: .loose)
        let meal = Meal(title: "Chili night")
        context.insert(brothGF)
        context.insert(beansGF)
        context.insert(mysteryBroth)
        context.insert(recipe)
        context.insert(meal)
        recipe.items = [
            RecipeItem(ingredient: beansGF),
            RecipeItem(ingredient: mysteryBroth), // one unverified poisons all
        ]
        meal.recipes = [recipe]
        meal.directItems = [RecipeItem(ingredient: brothGF)]
        try context.save()

        let fresh = ModelContext(container)
        let fetchedMeal = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertFalse(fetchedMeal.isGFVerifiedForCeliac,
                       "one unverified ingredient must make the whole meal unsafe")

        // Control: verify the SAME meal flips safe once every item is verified.
        let fetchedMystery = try XCTUnwrap(
            try fresh.fetch(FetchDescriptor<Ingredient>())
                .first { $0.name == "that broth" }
        )
        fetchedMystery.isGlutenFreeVerified = true
        try fresh.save()
        XCTAssertTrue(fetchedMeal.isGFVerifiedForCeliac,
                      "all-verified composition must read safe (control)")
    }

    @MainActor
    func test_HC6_falseVerification_isAsUnsafeAsNil() throws {
        // Explicitly-gluten (false) and unverified (nil) must both read unsafe.
        let container = try makeContainer()
        let context = container.mainContext

        let soySauce = Ingredient(name: "regular soy sauce", perishability: .pantry,
                                  isGlutenFreeVerified: false)
        let meal = Meal(title: "Stir-fry")
        context.insert(soySauce)
        context.insert(meal)
        meal.directItems = [RecipeItem(ingredient: soySauce, amount: 2, unit: "tbsp")]
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertFalse(fetched.isGFVerifiedForCeliac)
    }

    @MainActor
    func test_HC6b_freeformOnlyMeal_readsUnverified_conservative() throws {
        // F16 conservative default (flagged for Ria): unknown composition is
        // treated as unverified — "Chipotle takeout" is not silently
        // Caddie-safe just because we listed no ingredients.
        let container = try makeContainer()
        let context = container.mainContext

        let takeout = Meal(title: "Chipotle takeout",
                           freeformNotes: "everyone orders their own")
        context.insert(takeout)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertFalse(fetched.isGFVerifiedForCeliac,
                       "no known ingredients ⇒ NOT verified (fail-safe, F16)")
    }

    @MainActor
    func test_HC6c_emptyRecipeChunk_poisonsOtherwiseVerifiedMeal() throws {
        // A recipe with zero listed items is an UNKNOWN chunk: it must not be
        // vacuously safe even when everything else in the meal is verified.
        let container = try makeContainer()
        let context = container.mainContext

        let brothGF = Ingredient(name: "GF broth", perishability: .pantry,
                                 isGlutenFreeVerified: true)
        let mystery = Recipe(title: "grandma's casserole (from memory)", kind: .loose)
        let meal = Meal(title: "Casserole night")
        context.insert(brothGF)
        context.insert(mystery)
        context.insert(meal)
        meal.recipes = [mystery] // no items listed — composition unknown
        meal.directItems = [RecipeItem(ingredient: brothGF)]
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertFalse(fetched.isGFVerifiedForCeliac,
                       "an itemless recipe is unknown composition — never vacuously safe")
    }

    @MainActor
    func test_HC6d_freeformNotesPlusVerifiedItems_staysUnverified() throws {
        // F16b conservative default (flagged for Ria): notes are an unknown
        // chunk — "Chipotle takeout" + verified GF chips must NOT read safe
        // because of the chips.
        let container = try makeContainer()
        let context = container.mainContext

        let chipsGF = Ingredient(name: "GF tortilla chips", perishability: .pantry,
                                 isGlutenFreeVerified: true)
        let meal = Meal(title: "Takeout night",
                        freeformNotes: "Chipotle, everyone orders their own")
        context.insert(chipsGF)
        context.insert(meal)
        meal.directItems = [RecipeItem(ingredient: chipsGF)]
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertFalse(fetched.isGFVerifiedForCeliac,
                       "one verified side item must not vouch for an unknown chunk")
    }

    @MainActor
    func test_HC6e_nilUnverifiedDirectItem_poisonsVerifiedRecipeMeal() throws {
        // Mutation-review catch: nil-unverified must poison via the
        // DIRECT-ITEMS path too, not just through recipes — this is exactly
        // where quick-adds land (new Ingredients default to nil, HC-7 shape).
        let container = try makeContainer()
        let context = container.mainContext

        let beansGF = Ingredient(name: "white beans", perishability: .pantry,
                                 isGlutenFreeVerified: true)
        let mysteryGarnish = Ingredient(name: "crispy topping", perishability: .pantry,
                                        isGlutenFreeVerified: nil) // unverified
        let recipe = Recipe(title: "verified chili base", kind: .loose)
        let meal = Meal(title: "Chili night")
        context.insert(beansGF)
        context.insert(mysteryGarnish)
        context.insert(recipe)
        context.insert(meal)
        recipe.items = [RecipeItem(ingredient: beansGF)]
        meal.recipes = [recipe]
        meal.directItems = [RecipeItem(ingredient: mysteryGarnish)]
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertFalse(fetched.isGFVerifiedForCeliac,
                       "nil on a direct item must poison the meal exactly like nil in a recipe")
    }

    @MainActor
    func test_directItemsOnlyMeal_allVerified_readsVerified() throws {
        // Positive control: a recipe-less meal built from verified direct
        // items must read verified — over-conservatism would lock Caddie out
        // of legitimately verified simple meals.
        let container = try makeContainer()
        let context = container.mainContext

        let gfPasta = Ingredient(name: "GF pasta", perishability: .pantry,
                                 isGlutenFreeVerified: true)
        let sauce = Ingredient(name: "marinara (verified)", perishability: .pantry,
                               isGlutenFreeVerified: true)
        let meal = Meal(title: "Pasta night")
        context.insert(gfPasta)
        context.insert(sauce)
        context.insert(meal)
        meal.directItems = [
            RecipeItem(ingredient: gfPasta, amount: 1, unit: "box"),
            RecipeItem(ingredient: sauce),
        ]
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertTrue(fetched.isGFVerifiedForCeliac,
                      "all-verified direct items with no recipes must read safe")
    }

    @MainActor
    func test_recipeLevel_zeroItemRecipe_neverReadsVerified() throws {
        // The per-recipe API must be fail-safe standalone (future HC-1/HC-2
        // filters call it directly): zero items = unknown = not verified.
        let recipe = Recipe(title: "grandma's casserole (from memory)", kind: .loose)
        XCTAssertFalse(recipe.allIngredientsGFVerified,
                       "an itemless recipe must never read verified, even unpersisted")
    }

    // MARK: - Cascade hygiene

    @MainActor
    func test_deletingRecipeCascadesItems_neverSharedIngredients() throws {
        // DM-5's spirit at recipe level: the join rows die with the recipe,
        // the shared Ingredient catalog never does.
        let container = try makeContainer()
        let context = container.mainContext

        let onions = Ingredient(name: "onions", perishability: .refrigeratedLong)
        let recipe = Recipe(title: "sofrito", kind: .loose)
        context.insert(onions)
        context.insert(recipe)
        recipe.items = [RecipeItem(ingredient: onions)]
        try context.save()

        context.delete(recipe)
        try context.save()

        let fresh = ModelContext(container)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<RecipeItem>()).count, 0,
                       "recipe items must cascade with their recipe")
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<Ingredient>()).count, 1,
                       "shared ingredients must survive recipe deletion")
    }
}
