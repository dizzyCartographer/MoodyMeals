import Foundation
import SwiftData

// ── Snack (build-spec §2, completed at M0-5) ──────────────────

@Model
final class Snack {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var name: String
    var favoriteOf: [FamilyMember]
    var cadenceDays: Double?          // nil until inferred or set (SN-5)
    var cadenceIsInferred: Bool       // manual override stops re-inference (SN-2)
    var lastPurchasedAt: Date?
    /// F18 (D-37 principle): history outlives a deleted snack — records keep
    /// their itemName, the `snack` link nils.
    @Relationship(deleteRule: .nullify, inverse: \PurchaseRecord.snack)
    var purchaseRecords: [PurchaseRecord]

    init(
        name: String,
        cadenceDays: Double? = nil,
        cadenceIsInferred: Bool = false,
        lastPurchasedAt: Date? = nil
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.name = name
        self.favoriteOf = []
        self.cadenceDays = cadenceDays
        self.cadenceIsInferred = cadenceIsInferred
        self.lastPurchasedAt = lastPurchasedAt
        self.purchaseRecords = []
    }
}
