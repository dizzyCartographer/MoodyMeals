import XCTest
import SwiftData
@testable import MoodyEngine

/// M0-4 acceptance: meal with zero recipes + freeform text is valid (TC-DM-3),
/// plus round-trips for the full Meal shape, PlanEntry, and ThemeAnchor.
/// Same discipline as the other suites: assert through a FRESH context.
final class PlanningModelTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - DM-3 (the acceptance test)

    @MainActor
    func test_DM3_freeformOnlyMeal_isValidAndPlannable() throws {
        // "Chipotle takeout": zero recipes, zero direct items, freeform text —
        // a first-class, plannable meal. (Its zero-contribution to shopping
        // lists is asserted at M2-1 with the explosion logic, per TC-DM-3.)
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let takeout = Meal(title: "Chipotle takeout",
                           freeformNotes: "everyone orders their own",
                           effort: .noCook,
                           isEatingOut: true) // D-7: manual/emergency only
        context.insert(ria)
        context.insert(takeout)
        context.insert(PlanEntry(date: .now, slot: .dinner, meal: takeout,
                                 attendees: [ria], status: .swapped))
        try context.save()

        let fresh = ModelContext(container)
        let entry = try XCTUnwrap(try fresh.fetch(FetchDescriptor<PlanEntry>()).first)
        let entryMeal = try XCTUnwrap(entry.meal)
        XCTAssertEqual(entryMeal.title, "Chipotle takeout")
        XCTAssertTrue(entryMeal.recipes.isEmpty)
        XCTAssertTrue(entryMeal.directItems.isEmpty)
        XCTAssertEqual(entryMeal.freeformNotes, "everyone orders their own")
        XCTAssertTrue(entryMeal.isEatingOut)
        XCTAssertEqual(entryMeal.effort, .noCook) // non-default: pins effort wiring
        XCTAssertEqual(entry.slot, .dinner)
        XCTAssertEqual(entry.status, .swapped)
    }

    // MARK: - Full Meal shape

    @MainActor
    func test_mealFullShape_roundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let elsie = FamilyMember(name: "Elsie", isAdult: false)
        context.insert(elsie)

        let eaten = Date(timeIntervalSinceNow: -3 * 86_400)
        let scheduled = Date(timeIntervalSinceNow: 4 * 86_400)
        let friedRice = Meal(
            title: "Fried rice",
            effort: .involved, // non-default on purpose: pins wiring, not fallback
            themeTags: ["asian", "wok"],
            slots: [.dinner],
            frequencyTarget: .biweekly,
            producesComponents: ["fried rice leftovers"], // producer half (D-4)
            requiresComponents: ["cooked rice"],          // leftover-DEPENDENT (D-4)
            moodTags: ["cozy"],
            methods: [.stovetop],
            isAllTimeFavorite: true,
            coreMemoryNote: "Elsie's first-day-of-school dinner",
            coreMemoryOwner: elsie,
            occasionTag: "first-day-of-school"
        )
        friedRice.lastEatenAt = eaten
        friedRice.lastScheduledAt = scheduled
        context.insert(friedRice)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertEqual(fetched.effort, .involved)
        XCTAssertEqual(fetched.themeTags, ["asian", "wok"])
        XCTAssertEqual(fetched.slots, [.dinner])
        XCTAssertEqual(fetched.frequencyTarget, .biweekly)
        XCTAssertEqual(fetched.rotationState, .active)
        XCTAssertEqual(fetched.producesComponents, ["fried rice leftovers"])
        XCTAssertEqual(fetched.requiresComponents, ["cooked rice"])
        XCTAssertEqual(fetched.componentFreshnessDays,
                       TuningDefaults.componentFreshnessDays)
        XCTAssertEqual(fetched.moodTags, ["cozy"])
        XCTAssertEqual(fetched.methods, [.stovetop])
        XCTAssertFalse(fetched.isEatingOut)
        XCTAssertTrue(fetched.isAllTimeFavorite)
        XCTAssertEqual(fetched.coreMemoryNote, "Elsie's first-day-of-school dinner")
        XCTAssertEqual(fetched.coreMemoryOwner?.name, "Elsie")
        XCTAssertEqual(fetched.occasionTag, "first-day-of-school")
        XCTAssertEqual(fetched.lastEatenAt?.timeIntervalSince1970 ?? 0,
                       eaten.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(fetched.lastScheduledAt?.timeIntervalSince1970 ?? 0,
                       scheduled.timeIntervalSince1970, accuracy: 1)
        XCTAssertNil(fetched.cooldownUntil)

        // F17 regression: marking a core memory must NOT hijack the owner's
        // breakfast default (SwiftData's implicit-inverse corruption).
        let fetchedElsie = try XCTUnwrap(
            try fresh.fetch(FetchDescriptor<FamilyMember>()).first { $0.name == "Elsie" }
        )
        XCTAssertNil(fetchedElsie.currentBreakfast,
                     "coreMemoryOwner must never write into currentBreakfast")
    }

    @MainActor
    func test_F17_breakfastAndCoreMemory_areIndependent_andShareable() throws {
        // Regression suite for the false implicit-inverse pairing:
        // (1) two members CAN share one breakfast default (BF-3 premise);
        // (2) setting a breakfast never stamps core-memory ownership.
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false)
        let elsie = FamilyMember(name: "Elsie", isAdult: false)
        let oatmeal = Meal(title: "Oatmeal", slots: [.breakfast])
        context.insert(chad)
        context.insert(elsie)
        context.insert(oatmeal)
        chad.currentBreakfast = oatmeal
        elsie.currentBreakfast = oatmeal
        try context.save()

        let fresh = ModelContext(container)
        let members = try fresh.fetch(FetchDescriptor<FamilyMember>())
        let freshChad = try XCTUnwrap(members.first { $0.name == "Chad" })
        let freshElsie = try XCTUnwrap(members.first { $0.name == "Elsie" })
        XCTAssertEqual(freshChad.currentBreakfast?.title, "Oatmeal")
        XCTAssertEqual(freshElsie.currentBreakfast?.title, "Oatmeal",
                       "a shared breakfast default must not be stolen member-to-member")

        let freshOatmeal = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertNil(freshOatmeal.coreMemoryOwner,
                     "a breakfast default must never stamp core-memory ownership")
    }

    @MainActor
    func test_D1_multiSlotMeal_persists() throws {
        // Q1/D-1 canon: breakfast-for-dinner is real — slots is an array.
        let container = try makeContainer()
        let context = container.mainContext

        let b4d = Meal(title: "Pancake night",
                       slots: [.breakfast, .dinner],
                       requiresCalmDay: true) // D-1: peaceful/clean-kitchen gate
        context.insert(b4d)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertEqual(Set(fetched.slots), [.breakfast, .dinner])
        XCTAssertTrue(fetched.requiresCalmDay)
    }

    @MainActor
    func test_rotationStateAndCooldown_roundTrip() throws {
        // CD-1 groundwork: "sick of this" = resting + cooldownUntil.
        let container = try makeContainer()
        let context = container.mainContext

        let tacos = Meal(title: "Tacos")
        context.insert(tacos)
        let restUntil = Date(timeIntervalSinceNow:
            Double(TuningDefaults.cooldownDefaultDays) * 86_400) // §8, never a literal
        tacos.rotationState = .resting
        tacos.cooldownUntil = restUntil
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertEqual(fetched.rotationState, .resting)
        XCTAssertEqual(fetched.cooldownUntil?.timeIntervalSince1970 ?? 0,
                       restUntil.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: - PlanEntry

    @MainActor
    func test_planEntry_attendeesLockCookStatus_roundTrip() throws {
        // D-5 groundwork (SCH-14 later): attendance is a subset, per entry.
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let chad = FamilyMember(name: "Chad", isAdult: false)
        let caddie = FamilyMember(name: "Caddie", isAdult: false,
                                  hardRequirements: [.glutenFree])
        let pizza = Meal(title: "All-the-gluten pizza night")
        context.insert(ria)
        context.insert(chad)
        context.insert(caddie)
        context.insert(pizza)

        // Caddie is away (marching band) — she is NOT an attendee.
        let plannedFor = Date(timeIntervalSinceNow: 2 * 86_400)
        let entry = PlanEntry(date: plannedFor, slot: .dinner, meal: pizza,
                              attendees: [ria, chad],
                              isLocked: true,
                              assignedCook: chad)
        context.insert(entry)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<PlanEntry>()).first)
        XCTAssertEqual(fetched.date.timeIntervalSince1970,
                       plannedFor.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(fetched.slot, .dinner)
        XCTAssertEqual(Set(fetched.attendees.map(\.name)), ["Ria", "Chad"])
        XCTAssertFalse(fetched.attendees.contains { $0.name == "Caddie" },
                       "attendance must be a real subset — D-5 depends on it")
        XCTAssertTrue(fetched.isLocked)
        XCTAssertEqual(fetched.assignedCook?.name, "Chad")
        XCTAssertEqual(fetched.status, .planned)
        XCTAssertNil(fetched.eventKitID)
    }

    // MARK: - ThemeAnchor

    @MainActor
    func test_themeAnchor_roundTrip_defaultVarietyFromTuning() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tacoTuesday = ThemeAnchor(weekday: 3, slot: .dinner, themeTag: "mexican")
        context.insert(tacoTuesday)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<ThemeAnchor>()).first)
        XCTAssertEqual(fetched.weekday, 3)
        XCTAssertEqual(fetched.slot, .dinner)
        XCTAssertEqual(fetched.themeTag, "mexican")
        XCTAssertEqual(fetched.varietyPeriodWeeks,
                       TuningDefaults.anchorVarietyPeriodWeeks)
        XCTAssertTrue(fetched.isActive)
    }

    // MARK: - D-37 delete rules (canon 2026-07-07)

    @MainActor
    func test_DM5_deletingMealCascadesScores_sharedDataSurvives() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false)
        let onions = Ingredient(name: "onions", perishability: .refrigeratedLong)
        let burgers = Meal(title: "Burgers")
        context.insert(chad)
        context.insert(onions)
        context.insert(burgers)
        burgers.directItems = [RecipeItem(ingredient: onions)]
        context.insert(MemberMealScore(member: chad, meal: burgers, liking: 2))
        try context.save()

        context.delete(burgers)
        try context.save()

        let fresh = ModelContext(container)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<MemberMealScore>()).count, 0,
                       "DM-5: scores die with their meal")
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<Ingredient>()).count, 1,
                       "DM-5: shared ingredients never die with a meal")
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<FamilyMember>()).count, 1)
    }

    @MainActor
    func test_DM6_deletedBreakfastDefault_degradesToNil() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let chad = FamilyMember(name: "Chad", isAdult: false)
        let bagel = Meal(title: "Everything bagel", slots: [.breakfast])
        context.insert(chad)
        context.insert(bagel)
        chad.currentBreakfast = bagel
        try context.save()

        context.delete(bagel)
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<FamilyMember>()).first)
        XCTAssertNil(fetched.currentBreakfast,
                     "DM-6: a deleted breakfast default degrades gracefully to nil")
    }

    @MainActor
    func test_D37_deletedMealLeavesPlanEntryFlagged_neverVanished() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let tacos = Meal(title: "Tacos")
        context.insert(ria)
        context.insert(tacos)
        context.insert(PlanEntry(date: .now, slot: .dinner, meal: tacos,
                                 attendees: [ria]))
        try context.save()

        context.delete(tacos)
        try context.save()

        let fresh = ModelContext(container)
        let entry = try XCTUnwrap(try fresh.fetch(FetchDescriptor<PlanEntry>()).first,
                                  "the entry must SURVIVE meal deletion")
        XCTAssertNil(entry.meal, "meal == nil is the needs-refill flag (D-37)")
    }

    @MainActor
    func test_D40_currentLunch_persistsAndDegradesLikeBreakfast() throws {
        // D-40: lunch is a per-person default with the same DM-6-style
        // graceful deletion as breakfast — and independent of it.
        let container = try makeContainer()
        let context = container.mainContext

        let elsie = FamilyMember(name: "Elsie", isAdult: false)
        let oatmeal = Meal(title: "Oatmeal", slots: [.breakfast])
        let sandwiches = Meal(title: "Sandwiches", slots: [.lunch])
        context.insert(elsie)
        context.insert(oatmeal)
        context.insert(sandwiches)
        elsie.currentBreakfast = oatmeal
        elsie.currentLunch = sandwiches
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<FamilyMember>()).first)
        XCTAssertEqual(fetched.currentLunch?.title, "Sandwiches")
        XCTAssertEqual(fetched.currentBreakfast?.title, "Oatmeal",
                       "lunch and breakfast defaults never interfere")

        context.delete(sandwiches)
        try context.save()
        let fresh2 = ModelContext(container)
        let after = try XCTUnwrap(try fresh2.fetch(FetchDescriptor<FamilyMember>()).first)
        XCTAssertNil(after.currentLunch, "deleted lunch default degrades to nil")
        XCTAssertEqual(after.currentBreakfast?.title, "Oatmeal",
                       "breakfast untouched by the lunch deletion")
    }

    @MainActor
    func test_D37_deletedMemberDropsFromAttendees_andCookNils() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let chad = FamilyMember(name: "Chad", isAdult: false)
        let burgers = Meal(title: "Burgers")
        context.insert(ria)
        context.insert(chad)
        context.insert(burgers)
        context.insert(PlanEntry(date: .now, slot: .dinner, meal: burgers,
                                 attendees: [ria, chad], assignedCook: chad))
        try context.save()

        context.delete(chad)
        try context.save()

        let fresh = ModelContext(container)
        let entry = try XCTUnwrap(try fresh.fetch(FetchDescriptor<PlanEntry>()).first)
        XCTAssertEqual(entry.attendees.map(\.name), ["Ria"],
                       "a deleted member drops out of attendee lists (D-5/D-37)")
        XCTAssertNil(entry.assignedCook,
                     "a deleted member's cook assignment nils (D-37)")
    }
}
