import Foundation
import SwiftData

// ── Planning (build-spec §2) ─────────────────────────────────

enum PlanStatus: String, Codable { case planned, eaten, swapped, skipped }

@Model
final class PlanEntry {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var date: Date                    // day-granularity
    var slot: SlotKind
    /// Optional per D-37: nil means the meal was deleted out from under this
    /// entry — the needs-refill flag. Entries never silently vanish.
    var meal: Meal?
    var isLocked: Bool                // user pinned; scheduler won't move
    var eventKitID: String?           // synced calendar event
    var status: PlanStatus            // planned / eaten / swapped / skipped
    var attendees: [FamilyMember]     // default: everyone. Hard constraints apply to ATTENDEES only (D-5)
    var assignedCook: FamilyMember?   // kid cook-nights (D-6); nil = default cook

    init(
        date: Date,
        slot: SlotKind,
        meal: Meal,
        attendees: [FamilyMember],
        isLocked: Bool = false,
        status: PlanStatus = .planned,
        assignedCook: FamilyMember? = nil
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.date = date
        self.slot = slot
        self.meal = meal
        self.isLocked = isLocked
        self.eventKitID = nil
        self.status = status
        self.attendees = attendees
        self.assignedCook = assignedCook
    }
}

@Model
final class ThemeAnchor {             // "Taco Tuesday"
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var weekday: Int                  // 1–7
    var slot: SlotKind
    var themeTag: String              // meals matching this tag fill the anchor
    var varietyPeriodWeeks: Int       // rotate the specific meal every N weeks
    var isActive: Bool

    init(
        weekday: Int,
        slot: SlotKind,
        themeTag: String,
        varietyPeriodWeeks: Int = TuningDefaults.anchorVarietyPeriodWeeks,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.weekday = weekday
        self.slot = slot
        self.themeTag = themeTag
        self.varietyPeriodWeeks = varietyPeriodWeeks
        self.isActive = isActive
    }
}
