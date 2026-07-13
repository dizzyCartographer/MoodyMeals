import XCTest
import SwiftData
@testable import MoodyEngine

/// M2-3 acceptance: TC-GT-1..6 ⚠️ (§10 — halt-the-line tests).
final class GuaranteeCheckTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Pinned to today 10:00, not wall-clock: "later today" scenarios must not
    /// cross midnight when the suite runs in the evening (found 2026-07-12 at
    /// 22:07 — a now+2h run day-anchored to TOMORROW, so same-day coverage
    /// correctly failed). Day-granularity behavior under test is unchanged.
    private let now = Calendar.current.date(
        byAdding: .hour, value: 10,
        to: Calendar.current.startOfDay(for: .now))!
    private func days(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: now)!
    }

    @MainActor
    private func mealWith(_ ingredients: [(String, Perishability)],
                          title: String, in context: ModelContext) -> Meal {
        let meal = Meal(title: title)
        context.insert(meal)
        meal.directItems = ingredients.map { name, perishability in
            let ingredient = Ingredient(name: name, perishability: perishability)
            context.insert(ingredient)
            return RecipeItem(ingredient: ingredient)
        }
        return meal
    }

    // GT-1 + GT-5: the happy path holds, with zero false alarms.
    @MainActor
    func test_GT1_GT5_happyPath_invariantHolds_noFalseAlarms() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        // Yesterday's weekly run bought everything for the next few days.
        let tacos = mealWith([("ground beef", .freshShort), ("gf shells", .pantry)],
                             title: "Tacos", in: context)
        let pasta = mealWith([("gf pasta", .pantry)], title: "Pasta night", in: context)
        let e1 = try WeekPlan.assign(tacos, on: days(1), slot: .dinner,
                                     attendees: [ria], in: context)
        let e2 = try WeekPlan.assign(pasta, on: days(3), slot: .dinner,
                                     attendees: [ria], in: context)

        let runs: [GuaranteeCheck.RunSnapshot] = [
            .init(tier: .weekly, plannedDate: days(-1), status: .done,
                  purchasedNames: ["ground beef", "gf shells", "gf pasta"]),
            .init(tier: .weekly, plannedDate: days(6), status: .confirmed),
            .init(tier: .weekly, plannedDate: days(13), status: .confirmed), // horizon pins to the NEXT, not furthest-in-tier
        ]
        let result = GuaranteeCheck.check(entries: [e1, e2], runs: runs, now: now)

        XCTAssertTrue(result.isSatisfied, "shopped per plan ⇒ the invariant holds (GT-1)")
        XCTAssertTrue(result.violations.isEmpty, "no false alarms — ever (GT-5)")
        XCTAssertEqual(result.coveredThrough, WeekPlan.dayAnchor(for: days(6)))
    }

    // GT-2: the violation names the meal, the item, and both ways out.
    @MainActor
    func test_GT2_uncoverableItem_namesMealItemAndProposals() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        // Cod on Thursday (day 4); the only runs before it are bulk —
        // fresh can't ride bulk (RT-1) and the weekly lands after.
        let codDinner = mealWith([("fresh cod", .freshShort)],
                                 title: "Cod & greens", in: context)
        let entry = try WeekPlan.assign(codDinner, on: days(4), slot: .dinner,
                                        attendees: [ria], in: context)
        let runs: [GuaranteeCheck.RunSnapshot] = [
            .init(tier: .bulk, plannedDate: days(2), status: .confirmed),
            .init(tier: .weekly, plannedDate: days(6), status: .confirmed),
        ]
        let result = GuaranteeCheck.check(entries: [entry], runs: runs, now: now)

        XCTAssertFalse(result.isSatisfied)
        let violation = try XCTUnwrap(result.violations.first)
        XCTAssertEqual(violation.mealTitle, "Cod & greens", "the MEAL is named (GT-2)")
        XCTAssertEqual(violation.date, WeekPlan.dayAnchor(for: days(4)))
        XCTAssertTrue(violation.missingItems.contains { $0.contains("fresh cod") },
                      "the missing ITEM is named (GT-2)")
        XCTAssertEqual(violation.proposals,
                       [.swapMeal, .addMiniRun(onOrBefore: WeekPlan.dayAnchor(for: days(4)))],
                       "swap OR mini-run — both ways out proposed (GT-2)")
    }

    // GT-3: a skipped run stops covering; the re-check lists exactly the
    // at-risk meals and their dates.
    @MainActor
    func test_GT3_skippedRun_listsExactlyTheAtRiskMeals() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let stirFry = mealWith([("flank steak", .freshShort)],
                               title: "Stir-fry", in: context)
        let pantryNight = mealWith([("canned soup", .pantry)],
                                   title: "Soup night", in: context)
        let e1 = try WeekPlan.assign(stirFry, on: days(2), slot: .dinner,
                                     attendees: [ria], in: context)
        let e2 = try WeekPlan.assign(pantryNight, on: days(3), slot: .dinner,
                                     attendees: [ria], in: context)

        // The weekly run tomorrow was SKIPPED; the only other run is bulk day 5.
        let runs: [GuaranteeCheck.RunSnapshot] = [
            .init(tier: .weekly, plannedDate: days(1), status: .skipped),
            .init(tier: .bulk, plannedDate: days(5), status: .confirmed),
        ]
        let result = GuaranteeCheck.check(entries: [e1, e2], runs: runs, now: now)

        XCTAssertFalse(result.isSatisfied)
        // Steak (fresh, can't ride bulk, nothing else in time) is at risk.
        // Canned soup needs day 3 but bulk lands day 5 → also at risk.
        XCTAssertEqual(result.violations.map(\.mealTitle), ["Stir-fry", "Soup night"],
                       "exactly the at-risk meals, in date order (GT-3)")
        XCTAssertEqual(result.violations.map(\.date),
                       [WeekPlan.dayAnchor(for: days(2)), WeekPlan.dayAnchor(for: days(3))])
    }

    // GT-4: inventory belief offsets the list at ≥ threshold, never below.
    @MainActor
    func test_GT4_inventoryConfidenceThreshold() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let friedRice = mealWith([("rice", .pantry)], title: "Fried rice", in: context)
        let entry = try WeekPlan.assign(friedRice, on: days(2), slot: .dinner,
                                        attendees: [ria], in: context)
        // No runs at all: only inventory can cover it.
        let confident = GuaranteeCheck.check(
            entries: [entry], runs: [],
            inventory: [("rice", 0.9)], now: now)
        XCTAssertTrue(confident.isSatisfied, "belief at 0.9 covers rice (GT-4)")

        let doubtful = GuaranteeCheck.check(
            entries: [entry], runs: [],
            inventory: [("rice", 0.5)], now: now)
        XCTAssertFalse(doubtful.isSatisfied,
                       "belief at 0.5 < 0.7 ⇒ buy it anyway (GT-4)")
        XCTAssertEqual(doubtful.violations.first?.mealTitle, "Fried rice")
    }

    // GT-6: a meal added AFTER this week's run already happened is checked
    // against reality — the run can't retroactively cover it.
    @MainActor
    func test_GT6_mealAddedAfterRunHappened_flagsImmediately() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        // The weekly run happened yesterday and did NOT buy salmon
        // (the meal didn't exist yet). Next confirmed run: day 6.
        let salmon = mealWith([("salmon", .freshShort)],
                              title: "Salmon night", in: context)
        let entry = try WeekPlan.assign(salmon, on: days(1), slot: .dinner,
                                        attendees: [ria], in: context)
        let runs: [GuaranteeCheck.RunSnapshot] = [
            .init(tier: .weekly, plannedDate: days(-1), status: .done,
                  purchasedNames: ["ground beef"]),
            .init(tier: .weekly, plannedDate: days(6), status: .confirmed),
        ]
        let result = GuaranteeCheck.check(entries: [entry], runs: runs, now: now)

        XCTAssertFalse(result.isSatisfied, "instant flag on save (GT-6)")
        let violation = try XCTUnwrap(result.violations.first)
        XCTAssertEqual(violation.mealTitle, "Salmon night")
        XCTAssertTrue(violation.missingItems.contains { $0.contains("salmon") })
    }

    // ── Review-hardening pins (each kills a suite-surviving mutation) ──

    @MainActor
    func test_sameDayRun_coversSameDayDinner_andTonight() throws {
        // The canonical rhythm: shop Saturday morning, cook Saturday night.
        // Day granularity means a run ON the meal's day covers it — including
        // a run later TODAY covering tonight (GT-5: no weekly cry-wolf).
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let saturday = mealWith([("ground beef", .freshShort)],
                                title: "Burgers", in: context)
        let saturdayEntry = try WeekPlan.assign(saturday, on: days(3), slot: .dinner,
                                                attendees: [ria], in: context)
        let morningOfMealDay = Calendar.current.date(
            byAdding: .hour, value: 10, to: WeekPlan.dayAnchor(for: days(3)))!
        let runs: [GuaranteeCheck.RunSnapshot] = [
            .init(tier: .weekly, plannedDate: morningOfMealDay, status: .confirmed),
        ]
        let result = GuaranteeCheck.check(entries: [saturdayEntry], runs: runs, now: now)
        XCTAssertTrue(result.isSatisfied,
                      "a run on the meal's own day covers its dinner")

        // Tonight's dinner + a run later today.
        let tonight = mealWith([("salmon", .freshShort)], title: "Salmon", in: context)
        let tonightEntry = try WeekPlan.assign(tonight, on: now, slot: .dinner,
                                               attendees: [ria], in: context)
        let laterToday = now.addingTimeInterval(2 * 3600)
        let todayRun: [GuaranteeCheck.RunSnapshot] = [
            .init(tier: .midweek, plannedDate: laterToday, status: .confirmed),
        ]
        let tonightResult = GuaranteeCheck.check(entries: [tonightEntry],
                                                 runs: todayRun, now: now)
        XCTAssertTrue(tonightResult.isSatisfied,
                      "a run in two hours covers tonight — never a false alarm")
    }

    @MainActor
    func test_todayViolation_proposalIsActionable() throws {
        // When today's meal genuinely can't be covered, the mini-run proposal
        // must still be actionable (a run TODAY counts), never a past instant.
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let tonight = mealWith([("fresh cod", .freshShort)], title: "Cod", in: context)
        let entry = try WeekPlan.assign(tonight, on: now, slot: .dinner,
                                        attendees: [ria], in: context)
        let result = GuaranteeCheck.check(entries: [entry], runs: [], now: now)

        XCTAssertFalse(result.isSatisfied)
        let proposal = try XCTUnwrap(result.violations.first?.proposals.last)
        XCTAssertEqual(proposal,
                       .addMiniRun(onOrBefore: WeekPlan.dayAnchor(for: now)),
                       "a mini-run today still saves tonight — actionable, not past")
    }

    @MainActor
    func test_stalePurchase_neverCoversFreshAgain() throws {
        // The phantom-cod blocker: cod bought 3 weeks ago (and eaten) must
        // not cover this week's cod dinner.
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let codDinner = mealWith([("fresh cod", .freshShort)],
                                 title: "Cod again", in: context)
        let entry = try WeekPlan.assign(codDinner, on: days(2), slot: .dinner,
                                        attendees: [ria], in: context)
        let runs: [GuaranteeCheck.RunSnapshot] = [
            .init(tier: .weekly, plannedDate: days(-21), status: .done,
                  purchasedNames: ["fresh cod"]),
            .init(tier: .weekly, plannedDate: days(6), status: .confirmed),
        ]
        let result = GuaranteeCheck.check(entries: [entry], runs: runs, now: now)
        XCTAssertFalse(result.isSatisfied,
                       "a 3-week-old purchase is spoilage, not coverage")
    }

    @MainActor
    func test_staleConfirmedRun_neverDefinesHorizonOrCoverage() throws {
        // A confirmed run whose day has passed (never marked done/skipped —
        // an everyday event here) must not collapse the horizon or cover.
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let codDinner = mealWith([("fresh cod", .freshShort)],
                                 title: "Cod night", in: context)
        let entry = try WeekPlan.assign(codDinner, on: days(3), slot: .dinner,
                                        attendees: [ria], in: context)
        let runs: [GuaranteeCheck.RunSnapshot] = [
            .init(tier: .weekly, plannedDate: days(-1), status: .confirmed), // stale
            .init(tier: .weekly, plannedDate: days(6), status: .confirmed),
        ]
        let result = GuaranteeCheck.check(entries: [entry], runs: runs, now: now)
        XCTAssertFalse(result.isSatisfied,
                       "the stale run can't cover; the weekly lands after the need")
        XCTAssertEqual(result.coveredThrough, WeekPlan.dayAnchor(for: days(6)),
                       "the horizon comes from the REAL upcoming run")
    }

    @MainActor
    func test_swappedEntry_staysUnderTheGuarantee() throws {
        // Tonight.swap() sets .swapped — the single most common change to
        // tonight's requirements must stay in scope.
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let original = mealWith([("gf pasta", .pantry)], title: "Pasta", in: context)
        let entry = try WeekPlan.assign(original, on: days(2), slot: .dinner,
                                        attendees: [ria], in: context)
        let swappedTo = mealWith([("fresh cod", .freshShort)], title: "Cod", in: context)
        try Tonight.swap(entry, to: swappedTo, in: context)

        let result = GuaranteeCheck.check(entries: [entry], runs: [], now: now)
        XCTAssertEqual(result.violations.first?.mealTitle, "Cod",
                       "swapped entries are exactly where coverage gaps appear")
    }

    @MainActor
    func test_proposedRuns_countAsCoverage() throws {
        // Runs start life .proposed — the normal planning state must not
        // read as an alert storm (GT-5).
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let tacos = mealWith([("ground beef", .freshShort)], title: "Tacos", in: context)
        let entry = try WeekPlan.assign(tacos, on: days(3), slot: .dinner,
                                        attendees: [ria], in: context)
        let runs: [GuaranteeCheck.RunSnapshot] = [
            .init(tier: .weekly, plannedDate: days(1), status: .proposed),
        ]
        let result = GuaranteeCheck.check(entries: [entry], runs: runs, now: now)
        XCTAssertTrue(result.isSatisfied, "proposed runs are still runs")
    }

    @MainActor
    func test_GT4_boundary_exactlyAtThreshold_counts() throws {
        // Spec §4 step 3: subtract "only at confidence ≥ 0.7" — AT counts.
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let friedRice = mealWith([("rice", .pantry)], title: "Fried rice", in: context)
        let entry = try WeekPlan.assign(friedRice, on: days(2), slot: .dinner,
                                        attendees: [ria], in: context)
        let result = GuaranteeCheck.check(
            entries: [entry], runs: [],
            inventory: [("rice", TuningDefaults.inventoryConfidenceThreshold)],
            now: now)
        XCTAssertTrue(result.isSatisfied, "belief exactly AT threshold counts (≥)")
    }

    @MainActor
    func test_pastEntries_areNotThisChecksBusiness() throws {
        // A planned entry whose day passed (never marked eaten — routine
        // here) must not raise permanent unfixable alarms (GT-5).
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let old = mealWith([("fresh cod", .freshShort)], title: "Old cod", in: context)
        let entry = try WeekPlan.assign(old, on: days(-3), slot: .dinner,
                                        attendees: [ria], in: context)
        let result = GuaranteeCheck.check(entries: [entry], runs: [], now: now)
        XCTAssertTrue(result.isSatisfied, "the past is not shoppable")
    }

    @MainActor
    func test_outOfStockStaple_entersTheGuarantee() throws {
        // SL-4's exception must be reachable from the guarantee path: an
        // empty salt jar makes the meal genuinely uncookable.
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let roast = mealWith([("salt", .pantry)], title: "Roast chicken", in: context)
        let entry = try WeekPlan.assign(roast, on: days(2), slot: .dinner,
                                        attendees: [ria], in: context)

        let assumed = GuaranteeCheck.check(entries: [entry], runs: [], now: now)
        XCTAssertTrue(assumed.isSatisfied, "staples assumed on hand (SL-4)")

        let empty = GuaranteeCheck.check(entries: [entry], runs: [],
                                         outOfStock: ["salt"], now: now)
        XCTAssertFalse(empty.isSatisfied,
                       "an out-flagged staple is a real requirement (SL-4 exception)")
    }

    // INV-6 spirit: with zero inventory data the check still works.
    @MainActor
    func test_zeroInventory_neverBlocks() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let tacos = mealWith([("ground beef", .freshShort)], title: "Tacos", in: context)
        let entry = try WeekPlan.assign(tacos, on: days(2), slot: .dinner,
                                        attendees: [ria], in: context)
        let runs: [GuaranteeCheck.RunSnapshot] = [
            .init(tier: .weekly, plannedDate: days(1), status: .confirmed),
        ]
        let result = GuaranteeCheck.check(entries: [entry], runs: runs, now: now)
        XCTAssertTrue(result.isSatisfied,
                      "no inventory data ⇒ route everything, block nothing (INV-6)")
    }
}
