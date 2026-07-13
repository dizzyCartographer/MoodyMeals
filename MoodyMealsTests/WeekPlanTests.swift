import XCTest
import SwiftData
@testable import MoodyEngine

/// M1-1 acceptance: PlanEntry created/edited; lock persists. Plus the HC-5
/// confirmation guard that manual assignment must honor (§1 ⚠️).
final class WeekPlanTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    func test_assign_createsEntry_onDayAnchor_withAttendees() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let chad = FamilyMember(name: "Chad", isAdult: false)
        let tacos = Meal(title: "Tacos")
        context.insert(ria)
        context.insert(chad)
        context.insert(tacos)

        let lateEvening = Calendar.current.date(
            bySettingHour: 22, minute: 41, second: 0, of: .now)!
        try WeekPlan.assign(tacos, on: lateEvening, slot: .dinner,
                            attendees: [ria, chad], in: context)

        let fresh = ModelContext(container)
        let entry = try XCTUnwrap(try fresh.fetch(FetchDescriptor<PlanEntry>()).first)
        XCTAssertEqual(entry.meal?.title, "Tacos")
        XCTAssertEqual(entry.date, WeekPlan.dayAnchor(for: lateEvening),
                       "entries live on the day anchor, not the tap timestamp")
        XCTAssertEqual(Set(entry.attendees.map(\.name)), ["Ria", "Chad"])
        XCTAssertEqual(entry.status, .planned)
        XCTAssertFalse(entry.isLocked)
    }

    @MainActor
    func test_reassignSameSlot_editsExistingEntry_noDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let tacos = Meal(title: "Tacos")
        let burgers = Meal(title: "Burgers")
        context.insert(ria)
        context.insert(tacos)
        context.insert(burgers)

        let day = Date.now
        try WeekPlan.assign(tacos, on: day, slot: .dinner, attendees: [ria], in: context)
        try WeekPlan.assign(burgers, on: day, slot: .dinner, attendees: [ria], in: context)

        let fresh = ModelContext(container)
        let entries = try fresh.fetch(FetchDescriptor<PlanEntry>())
        XCTAssertEqual(entries.count, 1, "one entry per (day, slot) — reassign edits")
        XCTAssertEqual(entries.first?.meal?.title, "Burgers")
    }

    @MainActor
    func test_allThreeSlots_coexistOnOneDay_D40() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let oatmeal = Meal(title: "Oatmeal", slots: [.breakfast])
        let sandwiches = Meal(title: "Sandwiches", slots: [.lunch]) // D-40
        let tacos = Meal(title: "Tacos")
        context.insert(ria)
        context.insert(oatmeal)
        context.insert(sandwiches)
        context.insert(tacos)

        let day = Date.now
        try WeekPlan.assign(oatmeal, on: day, slot: .breakfast, attendees: [ria], in: context)
        try WeekPlan.assign(sandwiches, on: day, slot: .lunch, attendees: [ria], in: context)
        try WeekPlan.assign(tacos, on: day, slot: .dinner, attendees: [ria], in: context)

        let fresh = ModelContext(container)
        let entries = try fresh.fetch(FetchDescriptor<PlanEntry>())
        XCTAssertEqual(entries.count, 3, "slots are independent within a day (D-40)")
        XCTAssertEqual(Set(entries.map(\.slot)), [.breakfast, .lunch, .dinner])
    }

    @MainActor
    func test_lockToggle_persists() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let ria = FamilyMember(name: "Ria", isAdult: true)
        let tacos = Meal(title: "Tacos")
        context.insert(ria)
        context.insert(tacos)

        let entry = try WeekPlan.assign(tacos, on: .now, slot: .dinner,
                                        attendees: [ria], in: context)
        try WeekPlan.setLocked(true, entry: entry, in: context)

        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<PlanEntry>()).first)
        XCTAssertTrue(fetched.isLocked, "the lock must survive the store (M1-1 AC)")
    }

    @MainActor
    func test_weekDays_returnsSevenAnchoredDays() {
        let days = WeekPlan.weekDays(containing: .now)
        XCTAssertEqual(days.count, 7)
        XCTAssertTrue(days.allSatisfy { $0 == WeekPlan.dayAnchor(for: $0) })
    }

    // MARK: - HC-5 ⚠️ (manual override allowed, silent never)

    @MainActor
    func test_HC5_unsafeBand_withGFAttendee_requiresConfirmation() throws {
        // D-57: the confirm belongs to the UNSAFE tier only.
        let container = try makeContainer()
        let context = container.mainContext

        let caddie = FamilyMember(name: "Caddie", isAdult: false,
                                  hardRequirements: [.glutenFree])
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(caddie)
        context.insert(ria)

        let flour = Ingredient(name: "flour", perishability: .pantry,
                               isGlutenFreeVerified: false)
        context.insert(flour)
        let bread = Meal(title: "Homemade bread")   // the rubric's unsafe pin
        context.insert(bread)
        let recipe = Recipe(title: "bread", kind: .loose)
        context.insert(recipe)
        recipe.items = [RecipeItem(ingredient: flour)]
        recipe.gfBand = .unsafe
        recipe.gfBandSource = .manualOverride
        bread.recipes = [recipe]
        try context.save()

        XCTAssertTrue(WeekPlan.requiresGFConfirmation(bread, attendees: [ria, caddie]),
                      "unsafe band + GF attendee ⇒ explicit named confirmation")
        XCTAssertEqual(WeekPlan.gfAttendeeNames([ria, caddie]), ["Caddie"])
    }

    @MainActor
    func test_HC5_awaitingSubstitution_assignsFrictionlessly_theD57Flip() throws {
        // Ria's correction, now live: a carrier line (regular soy sauce) is a
        // calm cook-time reminder — NOT a confirmation wall, even for Caddie.
        let container = try makeContainer()
        let context = container.mainContext

        let caddie = FamilyMember(name: "Caddie", isAdult: false,
                                  hardRequirements: [.glutenFree])
        context.insert(caddie)

        let soySauce = Ingredient(name: "regular soy sauce", perishability: .pantry,
                                  isGlutenFreeVerified: false)
        context.insert(soySauce)
        let stirFry = Meal(title: "Stir-fry")
        context.insert(stirFry)
        stirFry.directItems = [RecipeItem(ingredient: soySauce)]
        try context.save()

        XCTAssertEqual(MealBand.band(for: stirFry), .awaitingSubstitution)
        XCTAssertFalse(WeekPlan.requiresGFConfirmation(stirFry, attendees: [caddie]),
                       "awaiting-substitution is frictionless (D-57 HC-5)")

        let mystery = Ingredient(name: "mystery sauce", perishability: .pantry,
                                 isGlutenFreeVerified: nil)
        context.insert(mystery)
        let casserole = Meal(title: "Casserole")
        context.insert(casserole)
        casserole.directItems = [RecipeItem(ingredient: mystery)]
        try context.save()

        XCTAssertFalse(WeekPlan.requiresGFConfirmation(casserole, attendees: [caddie]),
                       "not-checked-yet assigns manually without friction too — auto-fill is what skips it")
    }

    @MainActor
    func test_HC5_noConfirmationNeeded_whenVerifiedOrGFMemberAbsent() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let caddie = FamilyMember(name: "Caddie", isAdult: false,
                                  hardRequirements: [.glutenFree])
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(caddie)
        context.insert(ria)

        let gfShells = Ingredient(name: "GF shells", perishability: .pantry,
                                  isGlutenFreeVerified: true)
        context.insert(gfShells)
        let tacos = Meal(title: "Tacos (GF)")
        context.insert(tacos)
        tacos.directItems = [RecipeItem(ingredient: gfShells)]

        XCTAssertFalse(WeekPlan.requiresGFConfirmation(tacos, attendees: [ria, caddie]),
                       "verified-safe meals assign without friction")

        let soySauce = Ingredient(name: "regular soy sauce", perishability: .pantry,
                                  isGlutenFreeVerified: false)
        context.insert(soySauce)
        let stirFry = Meal(title: "Stir-fry")
        context.insert(stirFry)
        stirFry.directItems = [RecipeItem(ingredient: soySauce)]

        try context.save()
        XCTAssertFalse(WeekPlan.requiresGFConfirmation(stirFry, attendees: [ria]),
                       "SCH-14 groundwork: with the GF member absent, gluten is eligible")
    }
}
