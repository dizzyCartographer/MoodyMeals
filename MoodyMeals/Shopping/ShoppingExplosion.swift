import Foundation
import SwiftData

// ── M2-1: meals → shopping lines (SL-1..5), pure logic ───────
// Precise amounts sum per (ingredient, unit); loose requirements ride as
// "plus extra" on the same line — dedup never loses intent (SL-2).

struct ExplodedAmount: Equatable {
    var amount: Double
    var unit: String?
}

struct ExplodedLine: Equatable {
    var ingredientName: String
    var amounts: [ExplodedAmount]   // summed per unit, sorted for stability
    var plusExtra: Bool             // some requirement carried no amount
    /// GF qualifier survives into export text (RT-6 groundwork).
    var isGlutenFreeVerified: Bool?
}

enum ShoppingExplosion {

    /// The PlanEntries a range explosion covers: exactly those in
    /// [from, to), still cookable (planned/swapped, meal present) — SL-5.
    @MainActor
    static func entries(from: Date, to: Date,
                        in context: ModelContext) throws -> [PlanEntry] {
        let start = WeekPlan.dayAnchor(for: from)
        let end = WeekPlan.dayAnchor(for: to)
        let descriptor = FetchDescriptor<PlanEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor).filter {
            $0.meal != nil && ($0.status == .planned || $0.status == .swapped)
        }
    }

    /// Explode entries into consolidated lines.
    /// - `pantryExclusions`: SL-4 — assumed-on-hand names, skipped…
    /// - `outOfStock`: …unless flagged out (inventory belief supplies this
    ///   from M2-3/M6; callers pass names lowercased).
    static func explode(
        _ entries: [PlanEntry],
        pantryExclusions: Set<String> = TuningDefaults.pantryStapleExclusions,
        outOfStock: Set<String> = []
    ) -> [ExplodedLine] {
        struct Accumulator {
            var ingredient: Ingredient
            var totals: [String?: Double] = [:]
            var plusExtra = false
        }
        var byIngredient: [UUID: Accumulator] = [:]

        for entry in entries {
            guard let meal = entry.meal else { continue } // freeform/refill: nothing (SL-3)
            let items = meal.recipes.flatMap(\.items) + meal.directItems
            for item in items {
                let ingredient = item.ingredient
                let key = ingredient.id
                let name = ingredient.name.lowercased()
                if pantryExclusions.contains(name), !outOfStock.contains(name) {
                    continue // SL-4: assumed on hand
                }
                var acc = byIngredient[key] ?? Accumulator(ingredient: ingredient)
                if let amount = item.amount {
                    acc.totals[item.unit, default: 0] += amount // SL-1: sum per unit
                } else {
                    acc.plusExtra = true // SL-2: loose intent preserved
                }
                byIngredient[key] = acc
            }
        }

        return byIngredient.values.map { acc in
            ExplodedLine(
                ingredientName: acc.ingredient.name,
                amounts: acc.totals
                    .map { ExplodedAmount(amount: $0.value, unit: $0.key) }
                    .sorted { ($0.unit ?? "") < ($1.unit ?? "") },
                plusExtra: acc.plusExtra,
                isGlutenFreeVerified: acc.ingredient.isGlutenFreeVerified
            )
        }
        .sorted { $0.ingredientName.lowercased() < $1.ingredientName.lowercased() }
    }
}
