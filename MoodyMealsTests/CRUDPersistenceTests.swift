import XCTest
import SwiftData
@testable import MoodyEngine

/// M0-7 acceptance: creates/edits persist — exercising the same model
/// operations the CRUD screens perform, verified through a fresh context.
final class CRUDPersistenceTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    func test_createThenEditMeal_persists() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Create (what the + button does).
        let meal = Meal(title: "")
        context.insert(meal)
        try context.save()

        // Edit (what the edit form does).
        meal.title = "Sheet-less pan chicken"
        meal.freeformNotes = "kids like extra crispy"
        meal.effort = .involved
        meal.slots = [.dinner]
        meal.themeTags = ["cozy"]
        meal.frequencyTarget = .monthly
        meal.isAllTimeFavorite = true
        meal.updatedAt = .now
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertEqual(fetched.title, "Sheet-less pan chicken")
        XCTAssertEqual(fetched.freeformNotes, "kids like extra crispy")
        XCTAssertEqual(fetched.effort, .involved)
        XCTAssertEqual(fetched.themeTags, ["cozy"])
        XCTAssertEqual(fetched.frequencyTarget, .monthly)
        XCTAssertTrue(fetched.isAllTimeFavorite)
        XCTAssertGreaterThan(fetched.updatedAt, fetched.createdAt,
                             "edits must advance updatedAt (F15 interim)")
    }

    @MainActor
    func test_createThenEditRecipe_withNewUnverifiedIngredient_persists() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Create.
        let recipe = Recipe(title: "", kind: .loose)
        context.insert(recipe)
        try context.save()

        // Edit: title, kind flip, new ingredient (HC-7: enters UNVERIFIED),
        // a step, a D-36 mixed amount.
        recipe.title = "Beer-battered fish"
        recipe.kind = .precise
        let flour = Ingredient(name: "wheat flour", perishability: .pantry,
                               isGlutenFreeVerified: nil) // never silently verified
        context.insert(flour)
        let item = RecipeItem(ingredient: flour, amount: 2, unit: "cups")
        context.insert(item)
        recipe.items.append(item)
        recipe.steps = ["make the batter"]
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Recipe>()).first)
        XCTAssertEqual(fetched.title, "Beer-battered fish")
        XCTAssertEqual(fetched.kind, .precise)
        XCTAssertEqual(fetched.steps, ["make the batter"])
        let fetchedItem = try XCTUnwrap(fetched.items.first)
        XCTAssertNil(fetchedItem.ingredient.isGlutenFreeVerified,
                     "HC-7: a new ingredient is unverified until label-checked")
        XCTAssertEqual(fetchedItem.amount, 2)
    }

    @MainActor
    func test_deleteMealFromList_isSafeEndToEnd() throws {
        // The list's swipe-delete path over a fully-connected meal:
        // scored, planned, and someone's breakfast — nothing crashes, D-37 holds.
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false)
        let meal = Meal(title: "Oatmeal", slots: [.breakfast])
        context.insert(chad)
        context.insert(meal)
        chad.currentBreakfast = meal
        context.insert(MemberMealScore(member: chad, meal: meal, liking: 2))
        context.insert(PlanEntry(date: .now, slot: .breakfast, meal: meal,
                                 attendees: [chad]))
        try context.save()

        context.delete(meal)
        try context.save()

        let fresh = ModelContext(container)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<MemberMealScore>()).count, 0)
        let member = try XCTUnwrap(try fresh.fetch(FetchDescriptor<FamilyMember>()).first)
        XCTAssertNil(member.currentBreakfast)
        let entry = try XCTUnwrap(try fresh.fetch(FetchDescriptor<PlanEntry>()).first)
        XCTAssertNil(entry.meal, "flagged for refill, not vanished")
    }
}
