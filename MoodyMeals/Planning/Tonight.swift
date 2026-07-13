import Foundation
import SwiftData

/// M1-3: tonight's dinner + per-member safety (SF-1..3), UI-free.
enum Tonight {

    @MainActor
    static func todaysDinner(in context: ModelContext) throws -> PlanEntry? {
        try WeekPlan.entry(on: .now, slot: .dinner, in: context)
    }

    /// SF-2: safety is per (member, meal) — never household-wide.
    /// A GF-hard member's "safe" requires the SAFE band (D-57): awaiting,
    /// not-checked, and unsafe all cap the comfort flag — the hard
    /// constraint outranks it (§1 spirit, band vocabulary).
    @MainActor
    static func isSafe(_ meal: Meal, for member: FamilyMember, at date: Date = .now) -> Bool {
        if member.hardRequirements.contains(.glutenFree),
           MealBand.band(for: meal) != .safe {
            return false
        }
        guard let score = meal.memberScores.first(where: { $0.member.id == member.id })
        else { return false }
        return score.isSafeFood && !isHidden(meal, for: member, at: date)
    }

    /// SF-3: "not today" is a per-member window that lapses on its own.
    static func isHidden(_ meal: Meal, for member: FamilyMember, at date: Date = .now) -> Bool {
        guard let score = meal.memberScores.first(where: { $0.member.id == member.id }),
              let until = score.notTodayUntil else { return false }
        return until > date
    }

    /// SF-1: "what's safe for <member> tonight" — their list, nobody else's.
    @MainActor
    static func safeMeals(for member: FamilyMember, in context: ModelContext,
                          at date: Date = .now) throws -> [Meal] {
        let meals = try context.fetch(FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.title)]))
        return meals.filter {
            $0.rotationState == .active && isSafe($0, for: member, at: date)
        }
    }

    /// Swap tonight's dinner: the entry keeps its identity and lock, the
    /// meal changes, and the status records that a swap happened.
    @MainActor
    static func swap(_ entry: PlanEntry, to meal: Meal,
                     in context: ModelContext) throws {
        entry.meal = meal
        entry.status = .swapped
        entry.updatedAt = .now
        try context.save()
    }
}
