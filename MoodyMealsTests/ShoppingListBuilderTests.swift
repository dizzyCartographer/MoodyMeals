import XCTest
import SwiftData
@testable import MoodyEngine

/// M2-4 acceptance: TC-SL-6 + Reminders export behind permission check.
final class ShoppingListBuilderTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private let now = Date.now
    private func days(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: now)!
    }

    @MainActor
    func test_SL6_markdown_everyItemOnce_groupedByRun_readable() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let beef = Ingredient(name: "ground beef", perishability: .freshShort)
        let rice = Ingredient(name: "rice", perishability: .pantry)
        context.insert(beef)
        context.insert(rice)

        // Beef needed by TWO meals (dedup must yield one line, summed);
        // rice by one; cod is unroutable (fresh, no fresh-capable run in time).
        let tacos = Meal(title: "Tacos")
        context.insert(tacos)
        tacos.directItems = [RecipeItem(ingredient: beef, amount: 1, unit: "lb")]
        let burgers = Meal(title: "Burgers")
        context.insert(burgers)
        burgers.directItems = [RecipeItem(ingredient: beef, amount: 2, unit: "lb")]
        let friedRice = Meal(title: "Fried rice")
        context.insert(friedRice)
        friedRice.directItems = [RecipeItem(ingredient: rice, amount: 1, unit: "bag")]
        let codNight = Meal(title: "Cod night")
        context.insert(codNight)
        let cod = Ingredient(name: "fresh cod", perishability: .freshShort)
        context.insert(cod)
        codNight.directItems = [RecipeItem(ingredient: cod)]

        let entries = [
            try WeekPlan.assign(tacos, on: days(2), slot: .dinner, attendees: [ria], in: context),
            try WeekPlan.assign(burgers, on: days(4), slot: .dinner, attendees: [ria], in: context),
            try WeekPlan.assign(friedRice, on: days(5), slot: .dinner, attendees: [ria], in: context),
            try WeekPlan.assign(codNight, on: days(6), slot: .dinner, attendees: [ria], in: context),
        ]
        // One weekly run on day 1: carries beef (need day 2) and rice, but
        // cod on day 6 is outside its freshness window (6 − 1 = 5 > 4 shelf
        // days) and nothing else can reach it ⇒ genuinely at risk.
        let runs: [(tier: RunTier, plannedDate: Date)] = [
            (.weekly, days(1)),
        ]
        let list = ShoppingListBuilder.build(entries: entries, runs: runs, now: now)
        let markdown = ShoppingListBuilder.markdown(list)

        // Every uncovered item appears exactly once (SL-6).
        XCTAssertEqual(markdown.components(separatedBy: "ground beef").count - 1, 1,
                       "beef appears ONCE despite two meals")
        XCTAssertTrue(markdown.contains("3 lb"), "amounts summed across the range")
        XCTAssertEqual(markdown.components(separatedBy: "rice").count - 1, 1)
        XCTAssertEqual(markdown.components(separatedBy: "fresh cod").count - 1, 1)

        // Grouped by run, readable headings, at-risk section present.
        XCTAssertTrue(markdown.contains("## Weekly grocery"))
        XCTAssertTrue(markdown.contains("- [ ]"), "checklist format")
        XCTAssertTrue(markdown.contains("## ⚠️ At risk"))
        XCTAssertTrue(list.atRisk.contains { $0.text.contains("fresh cod") })

        // The strictest need-by routed beef onto the day-1 weekly run, and
        // the line carries the projection contract: raw name (PurchaseRecords
        // must match the guarantee) + every meal it keeps cookable.
        let weekly = try XCTUnwrap(list.groups.first { $0.tier == .weekly })
        let beefLine = try XCTUnwrap(weekly.lines.first { $0.ingredientName == "ground beef" })
        XCTAssertEqual(beefLine.text, "ground beef — 3 lb")
        XCTAssertEqual(Set(beefLine.mealTitles), ["Tacos", "Burgers"])
        XCTAssertEqual(beefLine.neededBy, entries[0].date,
                       "strictest need-by across both meals")
    }

    /// SL-6 + GT-1 seam: a covered entry (already shopped for that meal)
    /// leaves the merge entirely — the surviving line re-sums over the
    /// REMAINING meals only, never first-wins, never double-counts.
    @MainActor
    func test_SL6_coveredEntryLeavesTheMerge_amountsStayHonest() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)

        let beef = Ingredient(name: "ground beef", perishability: .freshShort)
        context.insert(beef)
        let tacos = Meal(title: "Tacos")
        context.insert(tacos)
        tacos.directItems = [RecipeItem(ingredient: beef, amount: 1, unit: "lb")]
        let burgers = Meal(title: "Burgers")
        context.insert(burgers)
        burgers.directItems = [RecipeItem(ingredient: beef, amount: 2, unit: "lb")]

        let entries = [
            try WeekPlan.assign(tacos, on: days(2), slot: .dinner, attendees: [ria], in: context),
            try WeekPlan.assign(burgers, on: days(4), slot: .dinner, attendees: [ria], in: context),
        ]
        let runs: [(tier: RunTier, plannedDate: Date)] = [(.weekly, days(1))]

        // Tacos' beef is covered (a done run already brought it home);
        // Burgers' is not — the line must read 2 lb, not 3, not 1.
        let tacosDay = entries[0].date
        let list = ShoppingListBuilder.build(
            entries: entries, runs: runs,
            covered: { name, _, mealDate in
                name == "ground beef" && mealDate == tacosDay
            },
            now: now)

        let weekly = try XCTUnwrap(list.groups.first { $0.tier == .weekly })
        let beefLine = try XCTUnwrap(weekly.lines.first { $0.ingredientName == "ground beef" })
        XCTAssertEqual(beefLine.text, "ground beef — 2 lb",
                       "the covered meal's amount stays out of the re-sum")
        XCTAssertEqual(beefLine.mealTitles, ["Burgers"])

        // Both covered → the line is gone entirely.
        let allCovered = ShoppingListBuilder.build(
            entries: entries, runs: runs,
            covered: { name, _, _ in name == "ground beef" },
            now: now)
        XCTAssertFalse(allCovered.groups.flatMap(\.lines)
            .contains { $0.ingredientName == "ground beef" })
    }

    /// SCH-13 + Ria 2026-07-13 (always-on): staples ride every list — on the
    /// soonest run that can carry them — and an EXPLICIT staple beats the
    /// SL-4 assumed-on-hand exclusions (the shelf is deliberate).
    @MainActor
    func test_SCH13_staples_alwaysOn_rideTheSoonestEligibleRun() throws {
        let runs: [(tier: RunTier, plannedDate: Date)] = [
            (.bulk, days(3)),
            (.weekly, days(1)),
        ]
        let list = ShoppingListBuilder.build(
            entries: [],
            staples: [.init(name: "garbanzo beans", minOnHand: "2 cans"),
                      .init(name: "oil", minOnHand: "1 bottle")],  // SL-4-excluded name
            runs: runs, now: now)

        let weekly = try XCTUnwrap(list.groups.first { $0.tier == .weekly },
                                   "staples land on the SOONEST run, not bulk")
        XCTAssertEqual(weekly.lines.map(\.text), ["garbanzo beans", "oil"])
        XCTAssertTrue(weekly.lines.allSatisfy { $0.source == .staple },
                      "D-34 provenance rides the line")
        XCTAssertNil(list.groups.first { $0.tier == .bulk })
        XCTAssertTrue(list.atRisk.isEmpty)
    }

    /// PT-7: an ingredient required by a meal AND on the staples floor is
    /// ONE line — meal amounts summed, the floor riding as "plus extra",
    /// staple provenance kept, strictest (meal) need-by.
    @MainActor
    func test_PT7_stapleAndMeal_mergeToOneLine() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let ria = FamilyMember(name: "Ria", isAdult: true)
        context.insert(ria)
        let beans = Ingredient(name: "garbanzo beans", perishability: .pantry)
        context.insert(beans)
        let curry = Meal(title: "Chickpea curry")
        context.insert(curry)
        curry.directItems = [RecipeItem(ingredient: beans, amount: 2, unit: "can")]

        let entries = [
            try WeekPlan.assign(curry, on: days(2), slot: .dinner, attendees: [ria], in: context),
        ]
        let list = ShoppingListBuilder.build(
            entries: entries,
            staples: [.init(name: "garbanzo beans", minOnHand: "2 cans")],
            runs: [(.weekly, days(1))], now: now)

        let lines = list.groups.flatMap(\.lines)
            .filter { $0.ingredientName.lowercased() == "garbanzo beans" }
        XCTAssertEqual(lines.count, 1, "PT-7: one line, never two")
        XCTAssertEqual(lines.first?.text, "garbanzo beans — 2 can, plus extra")
        XCTAssertEqual(lines.first?.source, .staple)
        XCTAssertEqual(lines.first?.neededBy, entries[0].date)
        XCTAssertEqual(lines.first?.mealTitles, ["Chickpea curry"])
    }

    /// A staple bought this cycle stays home (coverage keeps it off the
    /// list); the next cycle it rides again — that's the safety net.
    @MainActor
    func test_staple_coveredThisCycle_staysOff() {
        let staples: [ShoppingListBuilder.Staple] =
            [.init(name: "garbanzo beans", minOnHand: "2 cans")]
        let runs: [(tier: RunTier, plannedDate: Date)] = [(.weekly, days(1))]

        let covered = ShoppingListBuilder.build(
            entries: [], staples: staples, runs: runs,
            covered: { name, _, _ in name == "garbanzo beans" }, now: now)
        XCTAssertTrue(covered.groups.flatMap(\.lines).isEmpty)
        XCTAssertTrue(covered.atRisk.isEmpty)

        let nextCycle = ShoppingListBuilder.build(
            entries: [], staples: staples, runs: runs, now: now)
        XCTAssertEqual(nextCycle.groups.flatMap(\.lines).map(\.text),
                       ["garbanzo beans"])
    }

    // Reminders export: permission-gated, graceful, counted.
    @MainActor
    private final class MockRemindersStore: RemindersStore {
        var authorization: CalendarAuthorization
        var added: [(String, String)] = []
        init(_ auth: CalendarAuthorization) { authorization = auth }
        func requestAccess() async -> Bool {
            if authorization == .notDetermined { authorization = .authorized }
            return authorization == .authorized
        }
        func addItem(_ title: String, toList listName: String) throws {
            added.append((title, listName))
        }
        // Sync-seam members (unused by the one-shot export under test —
        // RemindersSyncTests exercises them against its own mock).
        func items(inList listName: String) async throws -> [ReminderItem] { [] }
        func setCompleted(_ completed: Bool, itemID: String) throws {}
        func removeItem(itemID: String) throws {}
    }

    @MainActor
    func test_remindersExport_authorized_addsEveryItemToRunLists() async {
        let list = BuiltShoppingList(
            groups: [.init(tier: .weekly, plannedDate: days(1),
                           lines: [.init(ingredientName: "ground beef",
                                         text: "ground beef — 3 lb"),
                                   .init(ingredientName: "rice",
                                         text: "rice — 1 bag")])],
            atRisk: [])
        let store = MockRemindersStore(.notDetermined) // will grant on request
        let outcome = await RemindersExport.export(list, to: store)

        XCTAssertEqual(outcome, .exported(itemCount: 2))
        XCTAssertEqual(store.added.count, 2)
        XCTAssertTrue(store.added.allSatisfy { $0.1.contains("Weekly grocery") },
                      "items land on the run's own list")
    }

    @MainActor
    func test_remindersExport_denied_isVisiblyUnavailable_neverSilent() async {
        let list = BuiltShoppingList(
            groups: [.init(tier: .weekly, plannedDate: days(1),
                           lines: [.init(ingredientName: "ground beef",
                                         text: "ground beef — 3 lb")])],
            atRisk: [])
        let store = MockRemindersStore(.denied)
        let outcome = await RemindersExport.export(list, to: store)

        guard case .unavailable(let reason) = outcome else {
            return XCTFail("denied must surface as unavailable, not silence")
        }
        XCTAssertTrue(reason.contains("markdown"),
                      "the fallback path is named — app fully functional without")
        XCTAssertTrue(store.added.isEmpty)
    }
}
