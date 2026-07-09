import XCTest
@testable import MoodyEngine

/// M2-2 acceptance: TC-RT-1..6, against the pure routing rules.
final class RunRoutingTests: XCTestCase {

    private let now = Date.now
    private func days(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: now)!
    }

    /// bulk in 10 days, weekly in 2, midweek in 4 — the household default shape.
    private var standardRuns: [(tier: RunTier, plannedDate: Date)] {
        [(.bulk, days(10)), (.weekly, days(2)), (.midweek, days(4))]
    }

    func test_RT1_freshCod_latestEligibleBeforeNeed_neverBulk() {
        // Needed Thursday (day 5): weekly(2) and midweek(4) qualify —
        // midweek is later, so fresher. Bulk(10) is out of window anyway,
        // but fresh must never ride bulk even when bulk is in-window.
        let result = RunRouting.route(perishability: .freshShort,
                                      neededBy: days(5),
                                      runs: standardRuns, now: now)
        XCTAssertEqual(result, .routed(runIndex: 2), "latest fresh-capable run (RT-1)")

        // Bulk in-window and LATEST — the slot fresh routing prefers —
        // must still never be chosen for fresh (a real pin, review-hardened:
        // with bulk earliest, "latest wins" masked the tier rule).
        let bulkLatest: [(tier: RunTier, plannedDate: Date)] =
            [(.weekly, days(2)), (.bulk, days(4))]
        let result2 = RunRouting.route(perishability: .freshShort,
                                       neededBy: days(5),
                                       runs: bulkLatest, now: now)
        XCTAssertEqual(result2, .routed(runIndex: 0), "fresh NEVER rides bulk (RT-1)")
    }

    func test_RT2_milk_defaultsToMidweek() {
        let result = RunRouting.route(perishability: .freshShort,
                                      neededBy: nil, // cadence item, no hard deadline
                                      runs: standardRuns, now: now)
        XCTAssertEqual(result, .routed(runIndex: 2),
                       "freshShort with no deadline lands on the top-up run (RT-2)")
    }

    func test_RT3_frozenNuggetsThreeWeeksOut_preferBulk() {
        let result = RunRouting.route(perishability: .freezer,
                                      neededBy: days(21),
                                      runs: standardRuns, now: now)
        XCTAssertEqual(result, .routed(runIndex: 0),
                       "far-out freezer items prefer the bulk run (RT-3)")

        // Needed SOON: bulk preference yields to the earliest run that makes it.
        let soon = RunRouting.route(perishability: .freezer,
                                    neededBy: days(3),
                                    runs: standardRuns, now: now)
        XCTAssertEqual(soon, .routed(runIndex: 1),
                       "inside the lead window, earliest eligible wins")
    }

    func test_RT4_neededBeforeAnyEligibleRun_isViolation() {
        let result = RunRouting.route(perishability: .freshShort,
                                      neededBy: days(1), // before weekly(2)
                                      runs: standardRuns, now: now)
        XCTAssertEqual(result, .violation,
                       "unroutable ⇒ raised, never silently dropped (RT-4)")
    }

    func test_RT5_preferredTierOverride_beatsInference() {
        // Freezer item needed far out would infer bulk — but the ingredient
        // says weekly (e.g. the GF brand only stocked at the grocery).
        let result = RunRouting.route(perishability: .freezer,
                                      neededBy: days(21),
                                      preferredTier: .weekly,
                                      runs: standardRuns, now: now)
        XCTAssertEqual(result, .routed(runIndex: 1), "override beats inference (RT-5)")

        // Unsatisfiable override falls back to inference, not violation.
        let noMidweek: [(tier: RunTier, plannedDate: Date)] =
            [(.bulk, days(10)), (.weekly, days(2))]
        let fallback = RunRouting.route(perishability: .pantry,
                                        neededBy: days(21),
                                        preferredTier: .midweek,
                                        runs: noMidweek, now: now)
        XCTAssertEqual(fallback, .routed(runIndex: 0),
                       "an unsatisfiable preference degrades to inference")
    }

    func test_freshnessFloor_runTooEarlyCannotCarryFresh() {
        // Review blocker: a run 17 days before the meal is spoilage, not
        // coverage — outside freshShortShelfDays, fresh is unroutable.
        let result = RunRouting.route(perishability: .freshShort,
                                      neededBy: days(19),
                                      runs: [(.weekly, days(2))], now: now)
        XCTAssertEqual(result, .violation,
                       "fresh can only ride runs within its shelf window")

        // Same distance, shelf-stable: perfectly fine.
        let pantry = RunRouting.route(perishability: .pantry,
                                      neededBy: days(19),
                                      runs: [(.weekly, days(2))], now: now)
        XCTAssertEqual(pantry, .routed(runIndex: 0))
    }

    func test_sameDayRun_isEligible_dayGranularity() {
        // A run at 10am covers that evening's dinner — day anchors compare.
        let mealDay = WeekPlan.dayAnchor(for: days(2))
        let morningRun = Calendar.current.date(byAdding: .hour, value: 10, to: mealDay)!
        let result = RunRouting.route(perishability: .freshShort,
                                      neededBy: mealDay,
                                      runs: [(.weekly, morningRun)], now: now)
        XCTAssertEqual(result, .routed(runIndex: 0),
                       "shop Saturday morning, cook Saturday night")
    }

    func test_shelfStable_noDeadline_prefersBulk_andLeadBoundary() {
        // Stock-up items (no deadline) belong on the Costco run.
        let stockUp = RunRouting.route(perishability: .pantry,
                                       neededBy: nil,
                                       runs: standardRuns, now: now)
        XCTAssertEqual(stockUp, .routed(runIndex: 0), "no deadline = stock-up = bulk")

        // Boundary: needed EXACTLY at the lead threshold is NOT far-out
        // (strictly greater-than, per §4's "> 2 weeks") → earliest eligible.
        let atBoundary = RunRouting.route(
            perishability: .pantry,
            neededBy: Calendar.current.date(byAdding: .day,
                                            value: TuningDefaults.bulkPreferenceLeadDays,
                                            to: WeekPlan.dayAnchor(for: now))!,
            runs: standardRuns, now: now)
        XCTAssertEqual(atBoundary, .routed(runIndex: 1),
                       "at the boundary the earliest run wins, not bulk")
    }

    func test_RT6_gfQualifierSurvivesToExportText() {
        let line = ExplodedLine(ingredientName: "gluten free chicken tenders frozen",
                                amounts: [ExplodedAmount(amount: 2, unit: "bags")],
                                plusExtra: false,
                                isGlutenFreeVerified: true)
        let text = RunRouting.exportText(for: line)
        XCTAssertTrue(text.localizedCaseInsensitiveContains("gluten free"),
                      "the dietary qualifier reaches the store list (RT-6)")
        XCTAssertTrue(text.contains("2 bags"))

        let loose = ExplodedLine(ingredientName: "cilantro",
                                 amounts: [ExplodedAmount(amount: 1, unit: "bunch")],
                                 plusExtra: true,
                                 isGlutenFreeVerified: true)
        XCTAssertTrue(RunRouting.exportText(for: loose).contains("plus extra"),
                      "SL-2's marker survives into export text")
    }
}
