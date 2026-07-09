import Foundation
import SwiftData

// ── Food objects (build-spec §2) ──────────────────────────────

enum Perishability: String, Codable {
    case pantry, freezer, refrigeratedLong, freshShort // freshShort = milk/produce/fish
}

/// Shopping-run tier (§2 shopping section; referenced by Ingredient overrides).
enum RunTier: String, Codable { case bulk /* Costco */, weekly, midweek }

@Model
final class Ingredient {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var name: String
    var perishability: Perishability
    var preferredRunTier: RunTier?    // override; else inferred from perishability (RT-5)
    var fdcID: Int?                   // USDA FoodData Central match (Phase 2)
    /// Celiac label-verification rule, encoded in the type (spec §2 note 5):
    /// tri-state — `nil` means unverified, and unverified = UNSAFE for GF members.
    var isGlutenFreeVerified: Bool?

    init(
        name: String,
        perishability: Perishability,
        preferredRunTier: RunTier? = nil,
        fdcID: Int? = nil,
        isGlutenFreeVerified: Bool? = nil
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.name = name
        self.perishability = perishability
        self.preferredRunTier = preferredRunTier
        self.fdcID = fdcID
        self.isGlutenFreeVerified = isGlutenFreeVerified
    }
}

enum RecipeKind: String, Codable { case loose, precise }

@Model
final class Recipe {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var title: String
    var kind: RecipeKind              // .loose or .precise
    var steps: [String]               // may be empty for loose
    var sourceURL: URL?
    @Relationship(deleteRule: .cascade) var items: [RecipeItem]

    init(
        title: String,
        kind: RecipeKind,
        steps: [String] = [],
        sourceURL: URL? = nil
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.title = title
        self.kind = kind
        self.steps = steps
        self.sourceURL = sourceURL
        self.items = []
    }
}

@Model
final class RecipeItem {              // join: recipe ↔ ingredient
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var ingredient: Ingredient
    /// nil is VALID — loose recipes have no amounts, and per D-36 a PRECISE
    /// recipe may carry amount-less items too ("all seasoning by taste").
    var amount: Double?
    var unit: String?

    init(ingredient: Ingredient, amount: Double? = nil, unit: String? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.ingredient = ingredient
        self.amount = amount
        self.unit = unit
    }
}
