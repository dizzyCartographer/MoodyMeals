import Foundation
import SwiftData

// ── M2-4: the buildable list — lines routed to runs, exportable ──
// SL-6: every uncovered item appears ONCE, grouped by run, readable.

struct BuiltShoppingList: Equatable {
    struct RunGroup: Equatable {
        var tier: RunTier
        var plannedDate: Date
        var itemTexts: [String]        // export texts, sorted, deduped
    }
    var groups: [RunGroup]
    var atRisk: [String]               // unroutable lines (feeds GT display)
}

enum ShoppingListBuilder {

    /// Explode a date range per entry (so need-by dates survive), merge to
    /// one line per ingredient with the STRICTEST need-by (PT-7 spirit),
    /// route each line, and group by run.
    static func build(
        entries: [PlanEntry],
        runs: [(tier: RunTier, plannedDate: Date)],
        pantryExclusions: Set<String> = TuningDefaults.pantryStapleExclusions,
        outOfStock: Set<String> = [],
        now: Date = .now
    ) -> BuiltShoppingList {
        struct Requirement {
            var line: ExplodedLine
            var neededBy: Date
        }
        // Merge per ingredient name: strictest need-by wins; amounts re-sum
        // via a combined explode over all its entries.
        var byName: [String: [PlanEntry]] = [:]
        var neededBy: [String: Date] = [:]
        for entry in entries {
            for line in ShoppingExplosion.explode([entry],
                                                  pantryExclusions: pantryExclusions,
                                                  outOfStock: outOfStock) {
                let key = line.ingredientName.lowercased()
                byName[key, default: []].append(entry)
                neededBy[key] = min(neededBy[key] ?? .distantFuture, entry.date)
            }
        }

        var groupsByRun: [Int: [String]] = [:]
        var atRisk: [String] = []
        for (key, itsEntries) in byName.sorted(by: { $0.key < $1.key }) {
            // One line per ingredient across the whole range (SL-1/SL-6).
            guard let line = ShoppingExplosion.explode(itsEntries,
                                                       pantryExclusions: pantryExclusions,
                                                       outOfStock: outOfStock)
                .first(where: { $0.ingredientName.lowercased() == key }) else { continue }
            let result = RunRouting.route(perishability: line.perishability,
                                          neededBy: neededBy[key],
                                          preferredTier: line.preferredRunTier,
                                          runs: runs, now: now)
            switch result {
            case .routed(let index):
                groupsByRun[index, default: []].append(RunRouting.exportText(for: line))
            case .violation:
                atRisk.append(RunRouting.exportText(for: line))
            }
        }

        let groups = groupsByRun
            .map { index, texts in
                BuiltShoppingList.RunGroup(tier: runs[index].tier,
                                           plannedDate: runs[index].plannedDate,
                                           itemTexts: texts.sorted())
            }
            .sorted { $0.plannedDate < $1.plannedDate }
        return BuiltShoppingList(groups: groups, atRisk: atRisk.sorted())
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
            for item in list.atRisk { out += "- \(item)\n" }
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
