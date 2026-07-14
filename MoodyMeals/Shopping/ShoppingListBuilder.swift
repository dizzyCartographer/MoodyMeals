import Foundation
import SwiftData

// ── M2-4: the buildable list — lines routed to runs, exportable ──
// SL-6: every uncovered item appears ONCE, grouped by run, readable.

struct BuiltShoppingList: Equatable {
    /// One merged line: every entry needing the ingredient contributed,
    /// amounts re-summed, strictest need-by (PT-7). The raw name rides along
    /// because PurchaseRecords must carry it or the guarantee never matches.
    struct Line: Equatable {
        var ingredientName: String
        var text: String                       // export text, amounts summed
        var perishability: Perishability = .pantry
        var neededBy: Date? = nil              // strictest across its meals
        var mealTitles: [String] = []          // the meals this line keeps cookable
        /// D-34 provenance: `.staple` when the always-stocked shelf put it
        /// here (alone or merged into a meal's line — PT-7).
        var source: ItemSource = .meal
    }
    struct RunGroup: Equatable {
        var tier: RunTier
        var plannedDate: Date
        var lines: [Line]
        var itemTexts: [String] { lines.map(\.text) }   // export/markdown view
    }
    var groups: [RunGroup]
    var atRisk: [Line]                 // unroutable lines (feeds GT display)
}

enum ShoppingListBuilder {

    /// A staple as the list sees it (D-6 always-stocked shelf, per Ria
    /// 2026-07-13): always ON — it rides every list unless the current
    /// cycle already brought it home. The pantry check happens at home,
    /// not at the store; an unneeded staple rides along as a safety net.
    struct Staple: Equatable {
        var name: String
        var minOnHand: String = ""
        var perishability: Perishability = .pantry
    }

    /// Explode a date range per entry (so need-by dates survive), merge to
    /// one line per ingredient with the STRICTEST need-by (PT-7 spirit),
    /// route each line, and group by run. Staples join the merge (PT-7:
    /// meal + staple floor = ONE line) or ride alone on the soonest run.
    /// - `covered`: purchase-coverage hook — (lowercased name, perishability,
    ///   the meal's date) → already shopped for that meal. A covered entry
    ///   leaves the merge entirely, so the re-sum stays honest: the line's
    ///   amount is exactly what the REMAINING meals still need.
    static func build(
        entries: [PlanEntry],
        staples: [Staple] = [],
        runs: [(tier: RunTier, plannedDate: Date)],
        pantryExclusions: Set<String> = TuningDefaults.pantryStapleExclusions,
        outOfStock: Set<String> = [],
        covered: (_ name: String, _ perishability: Perishability, _ mealDate: Date) -> Bool
            = { _, _, _ in false },
        now: Date = .now
    ) -> BuiltShoppingList {
        // Merge per ingredient name: strictest need-by wins; amounts re-sum
        // via a combined explode over all its (uncovered) entries.
        var byName: [String: [PlanEntry]] = [:]
        var neededBy: [String: Date] = [:]
        var titles: [String: [String]] = [:]
        for entry in entries {
            for line in ShoppingExplosion.explode([entry],
                                                  pantryExclusions: pantryExclusions,
                                                  outOfStock: outOfStock) {
                let key = line.ingredientName.lowercased()
                if covered(key, line.perishability, entry.date) { continue }
                byName[key, default: []].append(entry)
                neededBy[key] = min(neededBy[key] ?? .distantFuture, entry.date)
                if let title = entry.meal?.title, titles[key]?.contains(title) != true {
                    titles[key, default: []].append(title)
                }
            }
        }

        // Staples still standing after coverage: an item bought this cycle
        // stays home; everything else is on, every list, by default.
        var stapleByKey: [String: Staple] = [:]
        for staple in staples {
            let key = staple.name.lowercased()
            guard stapleByKey[key] == nil,
                  !covered(key, staple.perishability, now) else { continue }
            stapleByKey[key] = staple
        }

        var groupsByRun: [Int: [BuiltShoppingList.Line]] = [:]
        var atRisk: [BuiltShoppingList.Line] = []
        for (key, itsEntries) in byName.sorted(by: { $0.key < $1.key }) {
            // One line per ingredient across the whole range (SL-1/SL-6).
            guard var line = ShoppingExplosion.explode(itsEntries,
                                                       pantryExclusions: pantryExclusions,
                                                       outOfStock: outOfStock)
                .first(where: { $0.ingredientName.lowercased() == key }) else { continue }
            // PT-7: a staple floor merges INTO the meal's line — one item,
            // meal amounts summed, the floor riding as "plus extra".
            let isStaple = stapleByKey[key] != nil
            if isStaple { line.plusExtra = true }
            let built = BuiltShoppingList.Line(
                ingredientName: line.ingredientName,
                text: RunRouting.exportText(for: line),
                perishability: line.perishability,
                neededBy: neededBy[key],
                mealTitles: titles[key] ?? [],
                source: isStaple ? .staple : .meal)
            let result = RunRouting.route(perishability: line.perishability,
                                          neededBy: neededBy[key],
                                          preferredTier: line.preferredRunTier,
                                          runs: runs, now: now)
            switch result {
            case .routed(let index):
                groupsByRun[index, default: []].append(built)
            case .violation:
                atRisk.append(built)
            }
        }

        // Staple-only lines: no meal deadline — they ride the SOONEST run
        // that can carry them (SCH-13's "very next run"). An explicit staple
        // beats the SL-4 assumed-on-hand list: the shelf is deliberate.
        let today = WeekPlan.dayAnchor(for: now)
        for (key, staple) in stapleByKey.sorted(by: { $0.key < $1.key })
        where byName[key] == nil {
            let line = BuiltShoppingList.Line(
                ingredientName: staple.name,
                text: staple.name,
                perishability: staple.perishability,
                source: .staple)
            let eligible = RunRouting.eligibleTiers(for: staple.perishability)
            let soonest = runs.indices
                .filter { eligible.contains(runs[$0].tier)
                    && WeekPlan.dayAnchor(for: runs[$0].plannedDate) >= today }
                .min { runs[$0].plannedDate < runs[$1].plannedDate }
            if let soonest { groupsByRun[soonest, default: []].append(line) }
            else { atRisk.append(line) }   // visible, never silent (RT-4 spirit)
        }

        let groups = groupsByRun
            .map { index, lines in
                BuiltShoppingList.RunGroup(tier: runs[index].tier,
                                           plannedDate: runs[index].plannedDate,
                                           lines: lines.sorted { $0.text < $1.text })
            }
            .sorted { $0.plannedDate < $1.plannedDate }
        return BuiltShoppingList(groups: groups,
                                 atRisk: atRisk.sorted { $0.text < $1.text })
    }

    /// SL-6: readable plain-text markdown, grouped by run.
    static func markdown(_ list: BuiltShoppingList) -> String {
        var out = "# Shopping list\n"
        for group in list.groups {
            let day = group.plannedDate.formatted(.dateTime.weekday(.wide).month().day())
            out += "\n## \(tierName(group.tier)) — \(day)\n"
            for item in group.itemTexts { out += "- [ ] \(item)\n" }
        }
        if !list.atRisk.isEmpty {
            out += "\n## ⚠️ At risk — no run can carry these in time\n"
            for line in list.atRisk { out += "- \(line.text)\n" }
        }
        return out
    }

    static func tierName(_ tier: RunTier) -> String {
        switch tier {
        case .bulk: "Costco (bulk)"
        case .weekly: "Weekly grocery"
        case .midweek: "Midweek top-up"
        }
    }
}

// ── Reminders export, behind its own permission seam ─────────

@MainActor
protocol RemindersStore {
    var authorization: CalendarAuthorization { get }
    func requestAccess() async -> Bool
    /// Adds an item to the named list (creating the list if needed).
    func addItem(_ title: String, toList listName: String) throws
    /// Every reminder currently in the named list ([] if the list is absent).
    func items(inList listName: String) async throws -> [ReminderItem]
    func setCompleted(_ completed: Bool, itemID: String) throws
    func removeItem(itemID: String) throws
}

@MainActor
enum RemindersExport {
    enum Outcome: Equatable {
        case exported(itemCount: Int)
        case unavailable(reason: String)   // CAL-3 spirit: visible, never silent
    }

    static func export(_ list: BuiltShoppingList,
                       to store: RemindersStore) async -> Outcome {
        if store.authorization == .notDetermined {
            _ = await store.requestAccess()
        }
        guard store.authorization == .authorized else {
            return .unavailable(reason:
                "Reminders access is off. The markdown export works without it — or enable access in Settings.")
        }
        var count = 0
        for group in list.groups {
            let day = group.plannedDate.formatted(.dateTime.month(.abbreviated).day())
            let listName = "Moody — \(ShoppingListBuilder.tierName(group.tier)) \(day)"
            for item in group.itemTexts {
                if (try? store.addItem(item, toList: listName)) != nil { count += 1 }
            }
        }
        return .exported(itemCount: count)
    }
}
