import XCTest
import SwiftData
@testable import MoodyEngine

/// M0-6 acceptance: seed loads idempotently; used by all later tests.
final class SeedDataTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    func test_seedLoads_theFiveMembers_withHardAndSoftNeeds() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.loadIfNeeded(into: context)

        let fresh = ModelContext(container)
        let members = try fresh.fetch(FetchDescriptor<FamilyMember>())
        XCTAssertEqual(Set(members.map(\.name)),
                       ["Ria", "Chuck", "Caddie", "Elsie", "Chad"])

        let caddie = try XCTUnwrap(members.first { $0.name == "Caddie" })
        XCTAssertEqual(caddie.hardRequirements, [.glutenFree],
                       "celiac safety starts in the seed (§1)")

        let ria = try XCTUnwrap(members.first { $0.name == "Ria" })
        XCTAssertEqual(Set(ria.softGoals), [.hemeIron, .antiInflammatory])
        XCTAssertEqual(ria.methodAffinity[CookMethod.grill.rawValue], 2)  // D-28
        XCTAssertEqual(ria.methodAffinity[CookMethod.oven.rawValue], -2)

        let elsie = try XCTUnwrap(members.first { $0.name == "Elsie" })
        XCTAssertEqual(elsie.softGoals, [.proteinVegStarch],
                       "D-35: the full-plate nudge stays on Elsie's profile")

        let chad = try XCTUnwrap(members.first { $0.name == "Chad" })
        XCTAssertEqual(chad.softGoals, [.highCalorie])
        XCTAssertEqual(chad.appetiteBase, 1.5)
        XCTAssertEqual(chad.appetiteFavoriteBoost, 0.5)
    }

    @MainActor
    func test_seedMeals_coverTheACRequiredShapes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.loadIfNeeded(into: context)

        let fresh = ModelContext(container)
        let meals = try fresh.fetch(FetchDescriptor<Meal>())
        XCTAssertGreaterThanOrEqual(meals.count, 15, "~15 seed meals required")

        // One all-time favorite, with its core memory attached.
        let allTimers = meals.filter(\.isAllTimeFavorite)
        XCTAssertEqual(allTimers.count, 1)
        XCTAssertEqual(allTimers.first?.coreMemoryOwner?.name, "Elsie")

        // One Taco-Tuesday-tagged meal.
        XCTAssertTrue(meals.contains { $0.themeTags.contains("mexican") })

        // GF-verified and unverified items both present.
        let ingredients = try fresh.fetch(FetchDescriptor<Ingredient>())
        XCTAssertTrue(ingredients.contains { $0.isGlutenFreeVerified == true })
        XCTAssertTrue(ingredients.contains { $0.isGlutenFreeVerified == nil },
                      "an unverified item must exist (HC-4's flag case)")
        XCTAssertTrue(ingredients.contains { $0.isGlutenFreeVerified == false },
                      "contained gluten is a normal purchase (D-30)")

        // The leftover chain exists end-to-end (D-4).
        XCTAssertTrue(meals.contains { $0.producesComponents.contains("cooked rice") })
        XCTAssertTrue(meals.contains { $0.requiresComponents.contains("cooked rice") })

        // Eating out is present and flagged nuclear (D-7).
        XCTAssertTrue(meals.contains { $0.isEatingOut })

        // Safety spot-check: the GF-shells taco meal reads verified-safe,
        // the regular-soy stir-fry doesn't.
        let tacoMeal = try XCTUnwrap(meals.first { $0.title.contains("Tacos") })
        XCTAssertEqual(MealBand.band(for: tacoMeal), .safe)
        let stirFry = try XCTUnwrap(meals.first { $0.title.contains("stir-fry") })
        XCTAssertEqual(MealBand.band(for: stirFry), .awaitingSubstitution)   // D-57: carrier = calm question
    }

    @MainActor
    func test_seedHonorsCanon_noScores_noSheetPan_wednesdayAnchorOff() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.loadIfNeeded(into: context)

        let fresh = ModelContext(container)
        // Cold-start rule (PT-1): the seed creates ZERO Liking/Fit signal.
        // (D-47 allows likesToCook-only rows — a cook-night tag is not taste data.)
        let scores = try fresh.fetch(FetchDescriptor<MemberMealScore>())
        XCTAssertTrue(scores.allSatisfy { $0.liking == 0 && $0.fit == 0 && !$0.isSafeFood },
                      "seeded scores would fake optimization signal (Step 4f)")
        // D-47 + D-6: the leftover-chain consumer is a kid's likes-to-MAKE meal.
        XCTAssertTrue(scores.contains { $0.meal.title == "Fried rice" && $0.likesToCook && !$0.member.isAdult },
                      "fried rice is the canonical chain example, assigned to a kid")

        // D-4: no sheet-pan framing anywhere.
        let meals = try fresh.fetch(FetchDescriptor<Meal>())
        XCTAssertFalse(meals.contains { $0.themeTags.contains("sheet-pan") })

        // D-1: Wednesday breakfast-for-dinner anchor exists, seeded OFF.
        let anchors = try fresh.fetch(FetchDescriptor<ThemeAnchor>())
        let b4d = try XCTUnwrap(anchors.first { $0.themeTag == "breakfast-for-dinner" })
        XCTAssertEqual(b4d.weekday, 4)
        XCTAssertFalse(b4d.isActive, "one tap to enable — never on by default")
    }

    @MainActor
    func test_seedElsiesLifeline_andSnack_D6() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.loadIfNeeded(into: context)

        let fresh = ModelContext(container)
        let staples = try fresh.fetch(FetchDescriptor<StapleItem>())
        XCTAssertEqual(staples.count, 2)
        XCTAssertEqual(Set(staples.map(\.name)), ["sandwich bread", "garbanzo beans"])
        XCTAssertTrue(staples.allSatisfy { $0.forMember?.name == "Elsie" },
                      "the lifeline is Elsie's (D-6)")
        XCTAssertTrue(staples.allSatisfy { $0.ingredient != nil },
                      "staples link to catalog ingredients for guarantee routing")

        let cojack = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Snack>()).first)
        XCTAssertEqual(cojack.name, "Cojack sticks")
        XCTAssertEqual(Set(cojack.favoriteOf.map(\.name)), ["Chad", "Elsie"])
        XCTAssertNil(cojack.cadenceDays, "no phantom cadence in the seed (SN-5)")
    }

    @MainActor
    func test_seedIsIdempotent_doubleLoadChangesNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.loadIfNeeded(into: context)

        let fresh1 = ModelContext(container)
        let memberCount = try fresh1.fetch(FetchDescriptor<FamilyMember>()).count
        let mealCount = try fresh1.fetch(FetchDescriptor<Meal>()).count
        let ingredientCount = try fresh1.fetch(FetchDescriptor<Ingredient>()).count
        let stapleCount = try fresh1.fetch(FetchDescriptor<StapleItem>()).count
        let snackCount = try fresh1.fetch(FetchDescriptor<Snack>()).count

        try SeedData.loadIfNeeded(into: context) // second load — must be a no-op

        let fresh2 = ModelContext(container)
        XCTAssertEqual(try fresh2.fetch(FetchDescriptor<FamilyMember>()).count, memberCount)
        XCTAssertEqual(try fresh2.fetch(FetchDescriptor<Meal>()).count, mealCount)
        XCTAssertEqual(try fresh2.fetch(FetchDescriptor<Ingredient>()).count, ingredientCount)
        XCTAssertEqual(try fresh2.fetch(FetchDescriptor<StapleItem>()).count, stapleCount)
        XCTAssertEqual(try fresh2.fetch(FetchDescriptor<Snack>()).count, snackCount)
    }
}
