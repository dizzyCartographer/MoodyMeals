import XCTest
import SwiftData
@testable import MoodyEngine

/// M1-3 acceptance: TC-SF-1..3 against the Tonight service.
final class TonightTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    func test_SF1_safeListIsPerMember_notHousehold() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false)
        let elsie = FamilyMember(name: "Elsie", isAdult: false)
        let gfMac = Meal(title: "GF mac & cheese")
        let tacos = Meal(title: "Tacos")
        context.insert(chad)
        context.insert(elsie)
        context.insert(gfMac)
        context.insert(tacos)
        context.insert(MemberMealScore(member: chad, meal: gfMac, isSafeFood: true))
        context.insert(MemberMealScore(member: elsie, meal: gfMac, isSafeFood: false))
        context.insert(MemberMealScore(member: chad, meal: tacos, isSafeFood: false))
        try context.save()

        let chadSafe = try Tonight.safeMeals(for: chad, in: context)
        XCTAssertEqual(chadSafe.map(\.title), ["GF mac & cheese"],
                       "Chad's list is Chad's — not a household list (SF-1)")
        let elsieSafe = try Tonight.safeMeals(for: elsie, in: context)
        XCTAssertTrue(elsieSafe.isEmpty)
    }

    @MainActor
    func test_SF2_badgesArePerPerson_andHardConstraintOutranksFlag() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false)
        let elsie = FamilyMember(name: "Elsie", isAdult: false)
        let caddie = FamilyMember(name: "Caddie", isAdult: false,
                                  hardRequirements: [.glutenFree])
        let unverified = Ingredient(name: "mystery pasta", perishability: .pantry,
                                    isGlutenFreeVerified: nil)
        let mac = Meal(title: "Mac & cheese")
        context.insert(chad)
        context.insert(elsie)
        context.insert(caddie)
        context.insert(unverified)
        context.insert(mac)
        mac.directItems = [RecipeItem(ingredient: unverified)]
        context.insert(MemberMealScore(member: chad, meal: mac, isSafeFood: true))
        context.insert(MemberMealScore(member: elsie, meal: mac, isSafeFood: false))
        context.insert(MemberMealScore(member: caddie, meal: mac, isSafeFood: true))
        try context.save()

        XCTAssertTrue(Tonight.isSafe(mac, for: chad), "safe for Chad (SF-2)")
        XCTAssertFalse(Tonight.isSafe(mac, for: elsie), "not for Elsie (SF-2)")
        XCTAssertFalse(Tonight.isSafe(mac, for: caddie),
                       "an unverified meal is NEVER safe for a GF-hard member, flag or no flag (§1)")
    }

    @MainActor
    func test_SF3_notToday_hidesWhileActive_returnsWhenLapsed() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let caddie = FamilyMember(name: "Caddie", isAdult: false,
                                  hardRequirements: [.glutenFree])
        let shells = Ingredient(name: "GF shells", perishability: .pantry,
                                isGlutenFreeVerified: true)
        let tacos = Meal(title: "Tacos (GF)")
        context.insert(caddie)
        context.insert(shells)
        context.insert(tacos)
        tacos.directItems = [RecipeItem(ingredient: shells)]
        let score = MemberMealScore(member: caddie, meal: tacos, isSafeFood: true)
        context.insert(score)
        try context.save()

        // Active hide: excluded from her safe list.
        score.notTodayUntil = Date(timeIntervalSinceNow: 7 * 86_400)
        try context.save()
        XCTAssertTrue(try Tonight.safeMeals(for: caddie, in: context).isEmpty,
                      "an active notTodayUntil hides the meal (SF-3)")

        // Lapsed: available again, no user action needed.
        score.notTodayUntil = Date(timeIntervalSinceNow: -3_600)
        try context.save()
        XCTAssertEqual(try Tonight.safeMeals(for: caddie, in: context).map(\.title),
                       ["Tacos (GF)"],
                       "a lapsed hide restores availability automatically (SF-3)")
    }

    @MainActor
    func test_swapTonight_changesMealAndRecordsSwap() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let tacos = Meal(title: "Tacos")
        let leftovers = Meal(title: "Leftovers night")
        context.insert(ria)
        context.insert(tacos)
        context.insert(leftovers)
        let entry = try WeekPlan.assign(tacos, on: .now, slot: .dinner,
                                        attendees: [ria], in: context)

        try Tonight.swap(entry, to: leftovers, in: context)

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<PlanEntry>()).first)
        XCTAssertEqual(fetched.meal?.title, "Leftovers night")
        XCTAssertEqual(fetched.status, .swapped, "swaps are recorded, not silent")
    }
}
