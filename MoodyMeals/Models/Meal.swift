import Foundation
import SwiftData

// ── Meal: the atomic plannable unit (build-spec §2) ───────────
// M0-2 PLACEHOLDER: only the minimum needed so People models compile
// (`MemberMealScore.meal`, `FamilyMember.currentBreakfast`).
// Completed to the full spec §2 shape at M0-4 — staging, not deviation.

@Model
final class Meal {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var title: String

    init(title: String) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.title = title
    }
}
