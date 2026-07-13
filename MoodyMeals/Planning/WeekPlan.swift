import Foundation
import SwiftData

/// M1-1: the manual-planning operations behind the week grid — UI-free so
/// the acceptance criteria (PlanEntry created/edited; lock persists) are
/// testable without XCUITest.
enum WeekPlan {

    /// Day-granularity anchor: plan entries live on startOfDay.
    /// Calendar-aware (never +86 400) so DST days behave — PT-8 groundwork.
    static func dayAnchor(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// The seven day-anchors of the week containing `date`.
    static func weekDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let anchor = dayAnchor(for: date, calendar: calendar)
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: anchor) else {
            return [anchor]
        }
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
    }

    /// HC-5 (§1 ⚠️, as approved in D-57): manual assignment warns ONLY for
    /// the UNSAFE band — plainly, named, once (override allowed, silent
    /// never). Awaiting-substitution and not-checked-yet assign
    /// frictionlessly (Ria's correction: the badge rides as a cook-time
    /// reminder, never friction).
    @MainActor
    static func requiresGFConfirmation(_ meal: Meal, attendees: [FamilyMember]) -> Bool {
        let gfMembers = attendees.filter { $0.hardRequirements.contains(.glutenFree) }
        return !gfMembers.isEmpty && MealBand.band(for: meal) == .unsafe
    }

    /// Names of attending GF-hard members, for warning copy (no one hardcoded — D-35).
    static func gfAttendeeNames(_ attendees: [FamilyMember]) -> [String] {
        attendees.filter { $0.hardRequirements.contains(.glutenFree) }.map(\.name)
    }

    /// The entry occupying (day, slot), if any — one entry per day+slot.
    @MainActor
    static func entry(on date: Date, slot: SlotKind,
                      in context: ModelContext) throws -> PlanEntry? {
        let day = dayAnchor(for: date)
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) else {
            return nil
        }
        let descriptor = FetchDescriptor<PlanEntry>(
            predicate: #Predicate { $0.date >= day && $0.date < nextDay }
        )
        return try context.fetch(descriptor).first { $0.slot == slot }
    }

    /// Assign a meal to (date, slot): creates the entry, or repoints the
    /// existing one (manual assignment IS user intent — `isLocked` guards
    /// against the SCHEDULER moving things, never against the user).
    @MainActor
    @discardableResult
    static func assign(_ meal: Meal, on date: Date, slot: SlotKind,
                       attendees: [FamilyMember],
                       in context: ModelContext) throws -> PlanEntry {
        if let existing = try entry(on: date, slot: slot, in: context) {
            existing.meal = meal
            existing.status = .planned
            existing.updatedAt = .now
            try context.save()
            return existing
        }
        let entry = PlanEntry(date: dayAnchor(for: date), slot: slot,
                              meal: meal, attendees: attendees)
        context.insert(entry)
        try context.save()
        return entry
    }

    @MainActor
    static func setLocked(_ locked: Bool, entry: PlanEntry,
                          in context: ModelContext) throws {
        entry.isLocked = locked
        entry.updatedAt = .now
        try context.save()
    }

    @MainActor
    static func clear(entry: PlanEntry, in context: ModelContext) throws {
        context.delete(entry)
        try context.save()
    }
}
