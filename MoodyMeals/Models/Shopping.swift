import Foundation
import SwiftData

// ── Shopping, inventory & household state (build-spec §2, M0-5) ──

enum RunStatus: String, Codable { case proposed, confirmed, done, skipped }

@Model
final class ShoppingRun {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var tier: RunTier
    var plannedDate: Date
    var status: RunStatus
    var eventKitID: String?
    @Relationship(deleteRule: .cascade, inverse: \ShoppingItem.run)
    var items: [ShoppingItem]
    /// F18 (D-37 principle): purchase HISTORY outlives disposable runs —
    /// deleting a run nils `sourceRun`, never the records.
    @Relationship(deleteRule: .nullify, inverse: \PurchaseRecord.sourceRun)
    var purchaseRecords: [PurchaseRecord]

    init(tier: RunTier, plannedDate: Date, status: RunStatus = .proposed) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.tier = tier
        self.plannedDate = plannedDate
        self.status = status
        self.eventKitID = nil
        self.items = []
        self.purchaseRecords = []
    }
}

/// D-34 (canon): `staple` marks StapleItem-sourced lines — lifeline provenance.
enum ItemSource: String, Codable { case meal, snackCadence, manual, breakfastStaple, staple }

@Model
final class ShoppingItem {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var run: ShoppingRun?
    var ingredient: Ingredient?
    var freeText: String?             // manual items
    var amount: Double?
    var unit: String?
    var neededBy: Date?               // date of the meal that needs it — routing + guarantee
    var source: ItemSource
    var isPurchased: Bool

    init(
        ingredient: Ingredient? = nil,
        freeText: String? = nil,
        amount: Double? = nil,
        unit: String? = nil,
        neededBy: Date? = nil,
        source: ItemSource,
        isPurchased: Bool = false
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.run = nil
        self.ingredient = ingredient
        self.freeText = freeText
        self.amount = amount
        self.unit = unit
        self.neededBy = neededBy
        self.source = source
        self.isPurchased = isPurchased
    }
}

@Model
final class PurchaseRecord {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var itemName: String
    var ingredient: Ingredient?
    var snack: Snack?
    var purchasedAt: Date
    var sourceRun: ShoppingRun?

    init(itemName: String, purchasedAt: Date,
         ingredient: Ingredient? = nil, snack: Snack? = nil,
         sourceRun: ShoppingRun? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.itemName = itemName
        self.ingredient = ingredient
        self.snack = snack
        self.purchasedAt = purchasedAt
        self.sourceRun = sourceRun
    }
}

// ── Inventory (belief, not ledger) ───────────────────────────

enum StorageLocation: String, Codable { case fridge, freezer, pantry, door, unknown }

/// D-33 (canon): leftovers are first-class inventory (scheduler Step 1d, LC-3/LC-5).
enum InventoryKind: String, Codable { case normal, leftover }

@Model
final class InventoryItem {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var ingredient: Ingredient?
    var label: String                 // what we think it is
    var location: StorageLocation
    var confidence: Double            // 0–1; photos + convo raise it, time decays it
    var estimatedQuantity: String?    // "half a bag" — human-fuzzy on purpose
    var lastConfirmedAt: Date         // last photo/convo/purchase touch
    var flaggedUnclear: Bool          // queued for the reconciliation convo
    var kind: InventoryKind           // D-33
    var useBy: Date?                  // D-33: leftovers expire (LC-5)

    init(
        label: String,
        location: StorageLocation,
        confidence: Double,
        lastConfirmedAt: Date,
        ingredient: Ingredient? = nil,
        estimatedQuantity: String? = nil,
        flaggedUnclear: Bool = false,
        kind: InventoryKind = .normal,
        useBy: Date? = nil
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.ingredient = ingredient
        self.label = label
        self.location = location
        self.confidence = confidence
        self.estimatedQuantity = estimatedQuantity
        self.lastConfirmedAt = lastConfirmedAt
        self.flaggedUnclear = flaggedUnclear
        self.kind = kind
        self.useBy = useBy
    }
}

@Model
final class WasteEvent {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var itemName: String
    var ingredient: Ingredient?
    var loggedAt: Date
    var note: String?                 // "tossed half the spinach again"

    init(itemName: String, loggedAt: Date = .now,
         ingredient: Ingredient? = nil, note: String? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.itemName = itemName
        self.ingredient = ingredient
        self.loggedAt = loggedAt
        self.note = note
    }
}

// ── Read the room ────────────────────────────────────────────

enum Capacity: Int, Codable { case low = 0, medium, high }
enum CheckInModality: String, Codable { case oneTap, textStyle, voiceConversational }

@Model
final class CheckIn {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var date: Date
    var capacity: Capacity?           // nil = skipped (a signal in itself)
    var moodNote: String?
    var modality: CheckInModality     // which style was used (novelty rotation)
    var wasAnswered: Bool

    init(date: Date, capacity: Capacity? = nil, moodNote: String? = nil,
         modality: CheckInModality, wasAnswered: Bool) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.date = date
        self.capacity = capacity
        self.moodNote = moodNote
        self.modality = modality
        self.wasAnswered = wasAnswered
    }
}

@Model
final class WeeklyReflection {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var weekStart: Date
    var summary: String               // Claude-generated, user-edited
    var adjustments: [String]         // human-readable log of what got tuned

    init(weekStart: Date, summary: String = "", adjustments: [String] = []) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.weekStart = weekStart
        self.summary = summary
        self.adjustments = adjustments
    }
}

// ── Household config ─────────────────────────────────────────

@Model
final class StapleItem {              // D-6b: Elsie's fallback + similar — ALWAYS on hand
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var name: String                  // "sandwich bread", "garbanzo beans"
    var ingredient: Ingredient?
    var forMember: FamilyMember?      // whose lifeline this is
    var minOnHand: String             // human-fuzzy: "2 cans"

    init(name: String, minOnHand: String,
         ingredient: Ingredient? = nil, forMember: FamilyMember? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.name = name
        self.ingredient = ingredient
        self.forMember = forMember
        self.minOnHand = minOnHand
    }
}

@Model
final class FridgeSpec {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var modelNumber: String?
    var widthCM: Double?
    var heightCM: Double?
    var depthCM: Double?
    var shelfNotes: String?           // freeform geometry notes / zone layout

    init(modelNumber: String? = nil, widthCM: Double? = nil,
         heightCM: Double? = nil, depthCM: Double? = nil,
         shelfNotes: String? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.modelNumber = modelNumber
        self.widthCM = widthCM
        self.heightCM = heightCM
        self.depthCM = depthCM
        self.shelfNotes = shelfNotes
    }
}
