import Foundation

// ── M2-2: item → run routing (spec §4 step 4, RT-1..6) ───────
// freshShort → nearest weekly/midweek before need-by, never bulk;
// shelf-stable → any run before need-by, preferring bulk when far out;
// nothing eligible → a guarantee violation, never a silent drop (RT-4).

enum RoutingResult: Equatable {
    case routed(runIndex: Int)          // index into the candidate runs array
    case violation                       // feeds the guarantee check (GT)
}

enum RunRouting {

    /// Tiers a perishability class may ride (RT-1: fresh never rides bulk).
    static func eligibleTiers(for perishability: Perishability) -> Set<RunTier> {
        switch perishability {
        case .freshShort: [.weekly, .midweek]
        case .pantry, .freezer, .refrigeratedLong: [.bulk, .weekly, .midweek]
        }
    }

    /// Route one requirement onto the best candidate run.
    /// - `runs`: upcoming runs (proposed/confirmed), any order.
    /// - `preferredTier`: RT-5 — an explicit override beats inference when an
    ///   eligible run of that tier exists; otherwise inference proceeds.
    ///
    /// GRANULARITY CONTRACT (review-hardened): all date comparisons happen at
    /// DAY granularity — a run at 2pm covers that evening's dinner, and a
    /// run later today covers tonight. Fresh items additionally require the
    /// run within `freshShortShelfDays` of the meal (a run 17 days early
    /// "covering" fresh fish is spoilage, not coverage).
    static func route(
        perishability: Perishability,
        neededBy: Date?,
        preferredTier: RunTier? = nil,
        runs: [(tier: RunTier, plannedDate: Date)],
        now: Date = .now
    ) -> RoutingResult {
        let tiers = eligibleTiers(for: perishability)
        let today = WeekPlan.dayAnchor(for: now)
        let needDay = neededBy.map { WeekPlan.dayAnchor(for: $0) }
        let freshFloor: Date? = needDay.flatMap { day in
            perishability == .freshShort
                ? Calendar.current.date(byAdding: .day,
                                        value: -TuningDefaults.freshShortShelfDays,
                                        to: day)
                : nil
        }
        let inWindow = runs.indices.filter { index in
            let run = runs[index]
            let runDay = WeekPlan.dayAnchor(for: run.plannedDate)
            guard runDay >= today else { return false }
            if let needDay { guard runDay <= needDay else { return false } }
            if let freshFloor { guard runDay >= freshFloor else { return false } }
            return tiers.contains(run.tier)
        }
        guard !inWindow.isEmpty else { return .violation } // RT-4

        // RT-5: explicit override wins when satisfiable.
        if let preferredTier,
           let preferred = inWindow
               .filter({ runs[$0].tier == preferredTier })
               .min(by: { runs[$0].plannedDate < runs[$1].plannedDate }) {
            return .routed(runIndex: preferred)
        }

        switch perishability {
        case .freshShort:
            if let needDay, needDay > today {
                // RT-1: the LATEST run before need-by — maximal freshness.
                let latest = inWindow.max { runs[$0].plannedDate < runs[$1].plannedDate }!
                return .routed(runIndex: latest)
            }
            // RT-2: no need-by pressure → the top-up run is the default home.
            if let midweek = inWindow
                .filter({ runs[$0].tier == .midweek })
                .min(by: { runs[$0].plannedDate < runs[$1].plannedDate }) {
                return .routed(runIndex: midweek)
            }
            let earliest = inWindow.min { runs[$0].plannedDate < runs[$1].plannedDate }!
            return .routed(runIndex: earliest)

        case .pantry, .freezer, .refrigeratedLong:
            // RT-3: far-out shelf-stable prefers bulk.
            let farOut: Bool = {
                guard let needDay else { return true } // no deadline = stock-up
                let lead = Calendar.current.date(
                    byAdding: .day, value: TuningDefaults.bulkPreferenceLeadDays, to: today)!
                return needDay > lead
            }()
            if farOut,
               let bulk = inWindow
                   .filter({ runs[$0].tier == .bulk })
                   .min(by: { runs[$0].plannedDate < runs[$1].plannedDate }) {
                return .routed(runIndex: bulk)
            }
            let earliest = inWindow.min { runs[$0].plannedDate < runs[$1].plannedDate }!
            return .routed(runIndex: earliest)
        }
    }

    /// RT-6: the routed line's export text — the dietary qualifier is part of
    /// the item's identity and survives routing untouched.
    static func exportText(for line: ExplodedLine) -> String {
        var text = line.ingredientName
        let amounts = line.amounts
            .map { amount in
                amount.unit.map { "\(amount.amount.formatted()) \($0)" }
                    ?? "×\(amount.amount.formatted())"
            }
            .joined(separator: " + ")
        if !amounts.isEmpty { text += " — \(amounts)" }
        if line.plusExtra { text += line.amounts.isEmpty ? "" : ", plus extra" }
        return text
    }
}
