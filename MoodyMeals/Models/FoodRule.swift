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
}

@Model
final class FoodRule {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var member: FamilyMember?
    var directionRaw: String
    /// Human-readable subject, e.g. "red meat & pork", "iron-rich foods".
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

    init(member: FamilyMember?, direction: RuleDirection,
         subject: String, reason: String, frequencyWindowDays: Int? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.member = member
        self.directionRaw = direction.rawValue
        self.subject = subject
        self.reason = reason
        self.frequencyWindowDays = frequencyWindowDays
    }
}
