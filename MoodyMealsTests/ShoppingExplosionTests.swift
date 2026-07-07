import XCTest
import SwiftData
@testable import MoodyMeals

/// M2-1 acceptance: TC-SL-1..5.
final class ShoppingExplosionTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    private func plan(_ meal: Meal, daysAhead: Int, ria: FamilyMember,
                      in context: ModelContext) throws -> PlanEntry {
        let date = Calendar.current.date(byAdding: .day, value: daysAhead, to: .now)!
        return try WeekPlan.assign(meal, on: date, slot: .dinner,
                                   attendees: [ria], in: context)
    }

    @MainActor
    func test_SL1_preciseAmountsSum_acrossRecipes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let onions = Ingredient(name: "onions", perishability: .refrigeratedLong)
        context.insert(ria)
        context.insert(onions)

        let soup = Recipe(title: "soup", kind: .precise)
        let stirFry = Recipe(title: "stir fry", kind: .precise)
        context.insert(soup)
        context.insert(stirFry)
        soup.items = [RecipeItem(ingredient: onions, amount: 1, unit: nil)]
        stirFry.items = [RecipeItem(ingredient: onions, amount: 2, unit: nil)]

        let mealA = Meal(title: "Soup night")
        let mealB = Meal(title: "Stir-fry night")
        context.insert(mealA)
        context.insert(mealB)
        mealA.recipes = [soup]
        mealB.recipes = [stirFry]
        let e1 = try plan(mealA, daysAhead: 1, ria: ria, in: context)
        let e2 = try plan(mealB, daysAhead: 2, ria: ria, in: context)

        let lines = ShoppingExplosion.explode([e1, e2])
        XCTAssertEqual(lines.count, 1, "one line, not two (SL-1)")
        XCTAssertEqual(lines.first?.amounts, [ExplodedAmount(amount: 3, unit: nil)],
                       "1 + 2 = onions ×3")
        XCTAssertEqual(lines.first?.plusExtra, false)
    }

    @MainActor
    func test_SL2_looseMergesWithPrecise_plusExtraMarker() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let cilantro = Ingredient(name: "cilantro", perishability: .freshShort)
        context.insert(ria)
        context.insert(cilantro)

        let salsa = Recipe(title: "salsa", kind: .precise)
        let looseTacos = Recipe(title: "tacos from memory", kind: .loose)
        context.insert(salsa)
        context.insert(looseTacos)
        salsa.items = [RecipeItem(ingredient: cilantro, amount: 1, unit: "bunch")]
        looseTacos.items = [RecipeItem(ingredient: cilantro)] // "some cilantro"

        let mealA = Meal(title: "Salsa night")
        let mealB = Meal(title: "Taco night")
        context.insert(mealA)
        context.insert(mealB)
        mealA.recipes = [salsa]
        mealB.recipes = [looseTacos]
        let e1 = try plan(mealA, daysAhead: 1, ria: ria, in: context)
        let e2 = try plan(mealB, daysAhead: 2, ria: ria, in: context)

        let lines = ShoppingExplosion.explode([e1, e2])
        XCTAssertEqual(lines.count, 1, "dedup without losing intent (SL-2)")
        let line = try XCTUnwrap(lines.first)
        XCTAssertEqual(line.amounts, [ExplodedAmount(amount: 1, unit: "bunch")])
        XCTAssertTrue(line.plusExtra, "the loose 'some cilantro' survives as plus-extra")
    }

    @MainActor
    func test_SL3_freeformMealsContributeNothing_unlessDirectItems() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let takeout = Meal(title: "Chipotle takeout",
                           freeformNotes: "everyone orders their own")
        context.insert(takeout)
        let e1 = try plan(takeout, daysAhead: 1, ria: ria, in: context)
        XCTAssertTrue(ShoppingExplosion.explode([e1]).isEmpty,
                      "freeform-only meals add nothing (SL-3)")

        // …but direct items DO contribute.
        let chips = Ingredient(name: "GF tortilla chips", perishability: .pantry,
                               isGlutenFreeVerified: true)
        context.insert(chips)
        takeout.directItems = [RecipeItem(ingredient: chips)]
        try context.save()
        let lines = ShoppingExplosion.explode([e1])
        XCTAssertEqual(lines.map(\.ingredientName), ["GF tortilla chips"])
        XCTAssertEqual(lines.first?.isGlutenFreeVerified, true,
                       "GF qualifier rides along for export (RT-6 groundwork)")
    }

    @MainActor
    func test_SL4_pantryStaplesExcluded_unlessFlaggedOut() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let salt = Ingredient(name: "Salt", perishability: .pantry) // case-insensitive
        let chicken = Ingredient(name: "chicken thighs", perishability: .freshShort)
        context.insert(ria)
        context.insert(salt)
        context.insert(chicken)

        let meal = Meal(title: "Roast chicken")
        context.insert(meal)
        meal.directItems = [RecipeItem(ingredient: salt),
                            RecipeItem(ingredient: chicken, amount: 2, unit: "lb")]
        let entry = try plan(meal, daysAhead: 1, ria: ria, in: context)

        let normal = ShoppingExplosion.explode([entry])
        XCTAssertEqual(normal.map(\.ingredientName), ["chicken thighs"],
                       "salt is assumed on hand (SL-4)")

        let saltOut = ShoppingExplosion.explode([entry], outOfStock: ["salt"])
        XCTAssertEqual(saltOut.map(\.ingredientName), ["chicken thighs", "Salt"],
                       "…unless flagged out, then it's bought (SL-4)")
    }

    @MainActor
    func test_SL5_rangeCoversExactlyEntriesInRange() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let beef = Ingredient(name: "ground beef", perishability: .freshShort)
        context.insert(ria)
        context.insert(beef)

        func mealWithBeef(_ title: String) -> Meal {
            let meal = Meal(title: title)
            context.insert(meal)
            meal.directItems = [RecipeItem(ingredient: beef, amount: 1, unit: "lb")]
            return meal
        }
        _ = try plan(mealWithBeef("Inside A"), daysAhead: 1, ria: ria, in: context)
        _ = try plan(mealWithBeef("Inside B"), daysAhead: 3, ria: ria, in: context)
        _ = try plan(mealWithBeef("NEXT WEEK — must not leak"), daysAhead: 9,
                     ria: ria, in: context)
        let skipped = try plan(mealWithBeef("Skipped"), daysAhead: 2, ria: ria, in: context)
        skipped.status = .skipped
        try context.save()

        let from = Date.now
        let to = Calendar.current.date(byAdding: .day, value: 7, to: from)!
        let entries = try ShoppingExplosion.entries(from: from, to: to, in: context)

        XCTAssertEqual(entries.count, 2, "exactly the in-range, cookable entries (SL-5)")
        let lines = ShoppingExplosion.explode(entries)
        XCTAssertEqual(lines.first?.amounts, [ExplodedAmount(amount: 2, unit: "lb")],
                       "adjacent-week meals must not leak into the sum")
    }
}
