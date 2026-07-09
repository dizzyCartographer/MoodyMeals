import XCTest
import SwiftData
@testable import MoodyEngine

/// M0-2 acceptance: round-trip persistence for the People models and
/// TC §1 model-level invariants compiling against the real model API.
///
/// Round-trip discipline: every test saves via the main context, then fetches
/// through a FRESH ModelContext — same-context fetches return identity-mapped
/// live instances and would pass even if store encoding silently failed.
final class PeopleModelTests: XCTestCase {

    /// Returns the container, NOT a bare context: ModelContext does not retain
    /// its ModelContainer, so a context whose container deallocates traps inside
    /// SwiftData on first use. Tests must hold the container for their lifetime.
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Round-trip persistence

    @MainActor
    func test_familyMemberRoundTrip_allFields() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(
            name: "Ria",
            isAdult: true,
            hardRequirements: [],
            softGoals: [.hemeIron, .antiInflammatory],
            notes: "loves to cook; decision-fatigued at 4:30",
            appetiteBase: 1.0,
            appetiteFavoriteBoost: 0.25,
            methodAffinity: ["grill": 2, "oven": -2] // D-28
        )
        let riaID = ria.id
        context.insert(ria)
        try context.save()

        // Decode-from-store: fresh context, no identity-map shortcut.
        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(
            try fresh.fetch(FetchDescriptor<FamilyMember>()).first
        )
        XCTAssertEqual(fetched.id, riaID)
        XCTAssertEqual(fetched.name, "Ria")
        XCTAssertTrue(fetched.isAdult)
        XCTAssertEqual(fetched.hardRequirements, [])
        XCTAssertEqual(fetched.softGoals, [.hemeIron, .antiInflammatory])
        XCTAssertEqual(fetched.notes, "loves to cook; decision-fatigued at 4:30")
        XCTAssertEqual(fetched.methodAffinity["grill"], 2)
        XCTAssertEqual(fetched.methodAffinity["oven"], -2)
        XCTAssertEqual(fetched.appetiteBase, 1.0)
        XCTAssertEqual(fetched.appetiteFavoriteBoost, 0.25)
        XCTAssertNotNil(fetched.createdAt)
        XCTAssertNotNil(fetched.updatedAt)
        XCTAssertNil(fetched.currentBreakfast)
    }

    @MainActor
    func test_HC_modelInvariant_hardAndSoftNeedsStayDistinct() throws {
        // §1 model-level invariant: hard requirements are representable,
        // persistent, and distinct from soft goals (HC-1/HC-2 build on this).
        let container = try makeContainer()
        let context = container.mainContext

        let caddie = FamilyMember(
            name: "Caddie",
            isAdult: false,
            hardRequirements: [.glutenFree],
            softGoals: [.highProtein] // distinct value: proves no cross-bleed
        )
        context.insert(caddie)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(
            try fresh.fetch(FetchDescriptor<FamilyMember>()).first
        )
        XCTAssertEqual(fetched.hardRequirements, [.glutenFree],
                       "hard requirements must survive the store untouched")
        XCTAssertEqual(fetched.softGoals, [.highProtein],
                       "soft goals must survive independently — never blurred with hard")
    }

    @MainActor
    func test_memberMealScoreRoundTrip_twoAxesAndSafety() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false,
                                softGoals: [.highCalorie],
                                appetiteBase: 1.5, appetiteFavoriteBoost: 0.5)
        let meal = Meal(title: "GF mac & cheese")
        context.insert(chad)
        context.insert(meal)

        let until = Date(timeIntervalSinceNow: 86_400)
        let score = MemberMealScore(member: chad, meal: meal,
                                    liking: 2, fit: 1,
                                    isSafeFood: true,
                                    notTodayUntil: until,
                                    likesToCook: true)
        context.insert(score)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(
            try fresh.fetch(FetchDescriptor<MemberMealScore>()).first
        )
        XCTAssertEqual(fetched.liking, 2)
        XCTAssertEqual(fetched.fit, 1)
        XCTAssertTrue(fetched.isSafeFood)
        XCTAssertEqual(fetched.notTodayUntil?.timeIntervalSince1970 ?? 0,
                       until.timeIntervalSince1970, accuracy: 1)
        XCTAssertTrue(fetched.likesToCook)
        XCTAssertEqual(fetched.member.name, "Chad")
        XCTAssertEqual(fetched.member.appetiteFavoriteBoost, 0.5)
        XCTAssertEqual(fetched.meal.title, "GF mac & cheese")
    }

    @MainActor
    func test_SF1_modelLevel_safeFoodIsPerMember_neverHouseholdWide() throws {
        // SF-1 groundwork: the same meal is safe for Chad and NOT for Elsie —
        // safety lives on the (member, meal) join, never on the meal.
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false)
        let elsie = FamilyMember(name: "Elsie", isAdult: false)
        let meal = Meal(title: "GF mac & cheese")
        context.insert(chad)
        context.insert(elsie)
        context.insert(meal)
        context.insert(MemberMealScore(member: chad, meal: meal, isSafeFood: true))
        context.insert(MemberMealScore(member: elsie, meal: meal, isSafeFood: false))
        try context.save()

        let fresh = ModelContext(container)
        let scores = try fresh.fetch(FetchDescriptor<MemberMealScore>())
        let chadScore = try XCTUnwrap(scores.first { $0.member.name == "Chad" })
        let elsieScore = try XCTUnwrap(scores.first { $0.member.name == "Elsie" })
        XCTAssertTrue(chadScore.isSafeFood)
        XCTAssertFalse(elsieScore.isSafeFood)
    }

    @MainActor
    func test_SF3_modelLevel_notTodayWindowPersistsPerMemberAndLapses() throws {
        // SF-3 groundwork: "not today" is a per-member window that lapses.
        // Caddie carries a (lapsed) window on tacos; Elsie has none — contrast
        // proves the hide is per-member, not on the meal.
        let container = try makeContainer()
        let context = container.mainContext

        let caddie = FamilyMember(name: "Caddie", isAdult: false,
                                  hardRequirements: [.glutenFree])
        let elsie = FamilyMember(name: "Elsie", isAdult: false)
        let tacos = Meal(title: "Tacos (GF shells)")
        context.insert(caddie)
        context.insert(elsie)
        context.insert(tacos)

        let lapsed = Date(timeIntervalSinceNow: -3_600) // already past
        context.insert(MemberMealScore(member: caddie, meal: tacos,
                                       notTodayUntil: lapsed))
        context.insert(MemberMealScore(member: elsie, meal: tacos))
        try context.save()

        let fresh = ModelContext(container)
        let scores = try fresh.fetch(FetchDescriptor<MemberMealScore>())
        let caddieScore = try XCTUnwrap(scores.first { $0.member.name == "Caddie" })
        let elsieScore = try XCTUnwrap(scores.first { $0.member.name == "Elsie" })

        // The window value itself must survive the store (a nil here must FAIL).
        let persisted = try XCTUnwrap(caddieScore.notTodayUntil)
        XCTAssertEqual(persisted.timeIntervalSince1970,
                       lapsed.timeIntervalSince1970, accuracy: 1)
        XCTAssertNil(elsieScore.notTodayUntil, "the hide is Caddie's alone")

        let active = persisted > .now
        XCTAssertFalse(active, "a lapsed notTodayUntil must not read as active")
    }

    @MainActor
    func test_deletingMemberCascadesTheirScores() throws {
        // FamilyMember.mealScores carries deleteRule .cascade.
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false)
        let meal = Meal(title: "Burgers")
        context.insert(chad)
        context.insert(meal)
        context.insert(MemberMealScore(member: chad, meal: meal, liking: 2))
        try context.save()

        context.delete(chad)
        try context.save()

        let fresh = ModelContext(container)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<MemberMealScore>()).count, 0,
                       "scores must not orphan when their member is deleted")
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<Meal>()).count, 1,
                       "the meal itself must survive (only the join dies)")
        // The reverse direction — deleting a MEAL that has scores — is pinned
        // by test_DM5_deletingMealCascadesScores_sharedDataSurvives (D-37).
    }

    @MainActor
    func test_favoriteSnacks_manyToMany_roundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false)
        let elsie = FamilyMember(name: "Elsie", isAdult: false)
        let cojack = Snack(name: "Cojack sticks")
        context.insert(chad)
        context.insert(elsie)
        context.insert(cojack)

        cojack.favoriteOf = [chad, elsie]
        try context.save()

        let fresh = ModelContext(container)
        let fetchedSnack = try XCTUnwrap(
            try fresh.fetch(FetchDescriptor<Snack>()).first
        )
        XCTAssertEqual(Set(fetchedSnack.favoriteOf.map(\.name)), ["Chad", "Elsie"])

        let fetchedChad = try XCTUnwrap(
            try fresh.fetch(FetchDescriptor<FamilyMember>())
                .first { $0.name == "Chad" }
        )
        XCTAssertEqual(fetchedChad.favoriteSnacks.map(\.name), ["Cojack sticks"])
    }

    @MainActor
    func test_currentBreakfastReference_persists() throws {
        // Groundwork for BF-1: the daily default is a reference on the member.
        // (DM-6 graceful degradation is pinned by
        // test_DM6_deletedBreakfastDefault_degradesToNil — D-37.)
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false)
        let bagel = Meal(title: "Everything bagel + cream cheese")
        context.insert(chad)
        context.insert(bagel)
        chad.currentBreakfast = bagel
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(
            try fresh.fetch(FetchDescriptor<FamilyMember>()).first
        )
        XCTAssertEqual(fetched.currentBreakfast?.title,
                       "Everything bagel + cream cheese")

        // F17 regression: a breakfast default must never stamp core-memory
        // ownership on the meal (false implicit-inverse pairing).
        let fetchedBagel = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertNil(fetchedBagel.coreMemoryOwner)
    }
}
