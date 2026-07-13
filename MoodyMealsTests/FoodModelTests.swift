import XCTest
import SwiftData
@testable import MoodyEngine

/// M0-3 acceptance (HC-6-as-written retired by D-57 2026-07-13 — band
/// successors live in FoodRuleBandTests; ledger in RUNLOG): loose recipe with nil amounts persists; TC-HC-6 passes.
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
        XCTAssertEqual(MealBand.band(for: fetched), .safe,
                       "all-verified direct items with no recipes read the safe band")
    }

    @MainActor
    func test_recipeLevel_zeroItemRecipe_neverReadsSafe() throws {
        // Fail-safe standalone (D-57 HC-1 spirit): zero items = unknown.
        let container = try makeContainer()
        let context = container.mainContext
        let recipe = Recipe(title: "grandma's casserole (from memory)", kind: .loose)
        context.insert(recipe)
        try context.save()
        XCTAssertEqual(MealBand.band(for: recipe), .notCheckedYet,
                       "an itemless recipe must never read safe")
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
