import Foundation
import SwiftData

// ── FoodRule (FR-1, per D-42/D-45 as amended) ────────────────
// "Rules should still be structure for maximum consistency" (Ria): a rule is
// a STRUCTURED record, never freeform prose. Identical shapes get identical
// scheduler semantics, identical chips (D-46), identical settings UI, and
// the assessment prompt (FR-3) is BUILT from these fields deterministically.
// The generative layer only ever JUDGES recipes against them; its output is
// schema-validated annotations. Elsie has NO rule (D-35/D-44: her dinners
// are the scheduler's objective, staples the net). Caddie's protection is
// the D-44 band model, not a rule row.

enum RuleDirection: String, Codable {
    case never    // hard filter (M4-2)
    case limit    // cap window, symmetric to D-17's dislike windows
    case boost    // fit-coverage guardrails (M4-8)

    /// D-58: Ria's level words. Storage keeps the stable raws.
    var levelLabel: String {
        switch self {
        case .never: "never"
        case .limit: "infrequent"
        case .boost: "increased"
        }
    }
}

/// D-58: the category PICKER — a curated starter list, extensible as data
/// later, never freeform (D-45 as amended). Gluten lives here too: a
/// {gluten, never} record IS the GF guarantee the D-57 gates protect.
enum RuleCategory: String, Codable, CaseIterable {
    case gluten
    case highCholesterol
    case fiber
    case iron
    case antiInflammatory
    case calorieDense
    case redMeatPork

    var displayName: String {
        switch self {
        case .gluten: "Gluten"
        case .highCholesterol: "High Cholesterol"
        case .fiber: "Fiber"
        case .iron: "Iron"
        case .antiInflammatory: "Anti-Inflammatory"
        case .calorieDense: "Calorie-Dense"
        case .redMeatPork: "Red Meat & Pork"
        }
    }
}

@Model
final class FoodRule {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var member: FamilyMember?
    var directionRaw: String
    /// D-58: the picked category. Optional for migration; v2 backfill fills
    /// it on existing rules. When present, it drives display + matching.
    var categoryRaw: String?
    /// Human-readable subject, e.g. "red meat & pork", "iron-rich foods".
    /// Legacy display (pre-category rules) and future fine-print.
    var subject: String
    /// Why the rule exists, e.g. "high cholesterol" — rides into the
    /// assessment prompt so judgments carry context.
    var reason: String
    /// Cap/coverage window in days (limit: ≤1 per window; boost: ≥1 per
    /// window). nil for direction-inherent defaults.
    var frequencyWindowDays: Int?

    var direction: RuleDirection {
        get { RuleDirection(rawValue: directionRaw) ?? .boost }
        set { directionRaw = newValue.rawValue }
    }

    var category: RuleCategory? {
        get { categoryRaw.flatMap(RuleCategory.init(rawValue:)) }
        set { categoryRaw = newValue?.rawValue }
    }

    /// What the row shows: the picked category, else the legacy subject.
    var displaySubject: String { category?.displayName ?? subject }

    init(member: FamilyMember?, direction: RuleDirection,
         subject: String, reason: String, frequencyWindowDays: Int? = nil,
         category: RuleCategory? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.member = member
        self.directionRaw = direction.rawValue
        self.categoryRaw = category?.rawValue
        self.subject = subject
        self.reason = reason
        self.frequencyWindowDays = frequencyWindowDays
    }
}

// D-58: the GF guarantee IS a rule record now. `hardRequirements` stays as a
// conservative FALLBACK (pre-backfill stores over-protect, never under).
extension FamilyMember {
    var isGFGuaranteed: Bool {
        foodRules.contains { $0.category == .gluten && $0.direction == .never }
            || hardRequirements.contains(.glutenFree)
    }
}
