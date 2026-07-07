import Foundation
import SwiftData

// ── Snack (build-spec §2) ─────────────────────────────────────
// M0-2 PLACEHOLDER: only the minimum needed so `FamilyMember.favoriteSnacks`
// (inverse: \Snack.favoriteOf) compiles. Completed at M0-5.

@Model
final class Snack {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var name: String
    var favoriteOf: [FamilyMember]

    init(name: String) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.name = name
        self.favoriteOf = []
    }
}
