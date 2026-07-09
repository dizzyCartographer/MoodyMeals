import Foundation

// ── M2-3 ⚠️: the shopping guarantee, v1 (spec §4) ─────────────
// THE PROMISE: if you shop per the app, every planned meal between now and
// the next confirmed run is cookable. A violation is a structured result
// naming the meal, the date, the missing items, and what to do about it —
// never a vague alarm (GT-2), and never a false one (GT-5).
//
// GRANULARITY CONTRACT (review-hardened): everything compares at DAY
// granularity. A run any time on a given day covers that day's meals
// (shop Saturday 2pm → Saturday dinner is fine), and a confirmed run stays
// "upcoming" for the whole of its own day.

enum GuaranteeProposal: Equatable {
    /// `addMiniRun(onOrBefore:)` — a run ON the meal's day still covers it,
    /// so the proposal is always actionable (never a past instant).
    case swapMeal
    case addMiniRun(onOrBefore: Date)
}

struct GuaranteeViolation: Equatable {
    var mealTitle: String
    var date: Date
    var missingItems: [String]          // export-text names, store-search ready
    var proposals: [GuaranteeProposal]
}

struct GuaranteeResult: Equatable {
    var isSatisfied: Bool
    var coveredThrough: Date?           // the horizon this check vouches for
    var violations: [GuaranteeViolation]
}

enum GuaranteeCheck {

    /// A run as the check sees it. `plannedDate` may be day-anchored or
    /// wall-clock — the check only ever compares its DAY. `purchasedNames`
    /// (lowercased) matters only for `.done` runs — what actually came home.
    struct RunSnapshot {
        var tier: RunTier
        var plannedDate: Date
        var status: RunStatus
        var purchasedNames: Set<String> = []
    }

    /// v1 semantics, documented limits:
    /// - Inventory is OPTIONAL and never blocking (INV-6); beliefs offset the
    ///   list only at confidence ≥ threshold (GT-4).
    /// - Done-run purchases cover a meal only inside that run's CYCLE (until
    ///   the next run after it) and, for fresh items, only within
    ///   `freshShortShelfDays` — last week's cod never covers this week's.
    ///   Shelf-stable purchases are presence-level until M6's inventory.
    /// - `outOfStock` (lowercased names) re-includes SL-4 pantry staples that
    ///   are genuinely empty; M6 supplies it automatically.
    static func check(
        entries: [PlanEntry],
        runs: [RunSnapshot],
        inventory: [(name: String, confidence: Double)] = [],
        outOfStock: Set<String> = [],
        confidenceThreshold: Double = TuningDefaults.inventoryConfidenceThreshold,
        pantryExclusions: Set<String> = TuningDefaults.pantryStapleExclusions,
        now: Date = .now
    ) -> GuaranteeResult {
        let calendar = Calendar.current
        let today = WeekPlan.dayAnchor(for: now)
        func day(_ date: Date) -> Date { WeekPlan.dayAnchor(for: date) }

        // Horizon (spec §4 step 1, guaranteeLookaheadRuns = 1): the FURTHEST
        // of the per-tier next-confirmed runs — a near bulk run must not
        // shrink the window. No confirmed run ahead → open horizon; every
        // future entry stands on its own.
        let horizonEnd = Dictionary(grouping: runs.filter {
            $0.status == .confirmed && day($0.plannedDate) >= today
        }, by: \.tier)
        .compactMapValues { $0.map { day($0.plannedDate) }.min() }
        .values.max()

        let inScope = entries.filter { entry in
            guard entry.meal != nil,
                  entry.status == .planned || entry.status == .swapped,
                  entry.date >= today else { return false }
            if let horizonEnd { return entry.date <= horizonEnd }
            return true
        }

        let believedOnHand = Set(
            inventory.filter { $0.confidence >= confidenceThreshold }
                .map { $0.name.lowercased() }
        )
        let upcoming = runs
            .filter { ($0.status == .proposed || $0.status == .confirmed)
                      && day($0.plannedDate) >= today }

        // Purchase coverage windows: a done run covers meals from its own day
        // until the next run after it (any status — that's the cycle end).
        let allRunDays = runs.map { day($0.plannedDate) }.sorted()
        let doneWindows: [(names: Set<String>, start: Date, end: Date)] = runs
            .filter { $0.status == .done }
            .map { run in
                let start = day(run.plannedDate)
                let end = allRunDays.first { $0 > start } ?? .distantFuture
                return (run.purchasedNames, start, end)
            }
        func purchasedCovers(_ name: String, mealDay: Date,
                             perishability: Perishability) -> Bool {
            doneWindows.contains { window in
                guard window.names.contains(name),
                      mealDay >= window.start, mealDay <= window.end else { return false }
                guard perishability == .freshShort else { return true }
                let age = calendar.dateComponents([.day], from: window.start,
                                                  to: mealDay).day ?? .max
                return age <= TuningDefaults.freshShortShelfDays
            }
        }

        var violations: [GuaranteeViolation] = []
        for entry in inScope {
            guard let meal = entry.meal else { continue }
            let lines = ShoppingExplosion.explode([entry],
                                                  pantryExclusions: pantryExclusions,
                                                  outOfStock: outOfStock)
            var missing: [String] = []
            for line in lines {
                let name = line.ingredientName.lowercased()
                if believedOnHand.contains(name) { continue }   // GT-4 (≥ threshold)
                if purchasedCovers(name, mealDay: entry.date,
                                   perishability: line.perishability) { continue } // GT-1
                // Not on hand, not freshly bought: can it ride a run in time?
                let routable = RunRouting.route(
                    perishability: line.perishability,       // identity rides the line
                    neededBy: entry.date,
                    preferredTier: line.preferredRunTier,    // RT-5 honored here too
                    runs: upcoming.map { ($0.tier, $0.plannedDate) },
                    now: now
                )
                if routable == .violation {
                    missing.append(RunRouting.exportText(for: line)) // GT-2: named
                }
            }
            if !missing.isEmpty {
                violations.append(GuaranteeViolation(
                    mealTitle: meal.title,
                    date: entry.date,
                    missingItems: missing,
                    proposals: [.swapMeal, .addMiniRun(onOrBefore: entry.date)] // GT-2
                ))
            }
        }

        return GuaranteeResult(
            isSatisfied: violations.isEmpty,                    // GT-5: no false alarms
            coveredThrough: horizonEnd,
            violations: violations.sorted { $0.date < $1.date } // GT-3: meals + dates
        )
    }
}
