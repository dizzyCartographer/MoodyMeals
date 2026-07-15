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

/// D-44 risk bands (FR-1). `notCheckedYet` is canon's honest offline state —
/// every recipe wears it until assessed (FR-3) or banded by Ria.
enum GFBand: String, Codable {
    case safe
    case awaitingSubstitution   // schedulable, calm indicator (D-44 correction)
    case unsafe                 // structural gluten — the only gating tier
    case notCheckedYet
}

/// Who set the band. Manual outranks assessment FOREVER (D-44: "her overrides
/// persist and outrank any re-score").
enum GFBandSource: String, Codable { case derived, assessment, manualOverride }

@Model
final class Recipe {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var title: String
    var kind: RecipeKind              // .loose or .precise
    var steps: [String]               // may be empty for loose
    var sourceURL: URL?                // unused — kept for existing-store compatibility
    /// Where it came from — a URL or a cookbook title/page, freeform (not
    /// every source parses as a URL). Additive field: nil on every
    /// pre-existing recipe, safe under SwiftData's automatic migration.
    var source: String?
    @Relationship(deleteRule: .cascade) var items: [RecipeItem]
    // FR-1 (D-44): stored band + provenance. Optionals ⇒ lightweight
    // migration on existing stores; nil reads as notCheckedYet/derived.
    var gfBandRaw: String?
    var gfBandSourceRaw: String?
    /// The quiche move, canon verbatim: "my quiche recipe now requires King
    /// Arthur gf pie crust mix." Set ⇒ SAFE, indicator gone, sub rides the
    /// recipe's shopping lines (RT-6 pipe).
    var standardModification: String?

    var gfBand: GFBand? {
        get { gfBandRaw.flatMap(GFBand.init(rawValue:)) }
        set { gfBandRaw = newValue?.rawValue }
    }
    var gfBandSource: GFBandSource {
        get { gfBandSourceRaw.flatMap(GFBandSource.init(rawValue:)) ?? .derived }
        set { gfBandSourceRaw = newValue.rawValue }
    }

    init(
        title: String,
        kind: RecipeKind,
        steps: [String] = [],
        sourceURL: URL? = nil,
        source: String? = nil
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.title = title
        self.kind = kind
        self.steps = steps
        self.sourceURL = sourceURL
        self.source = source
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
