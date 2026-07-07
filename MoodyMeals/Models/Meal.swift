import Foundation
import SwiftData

// ── Meal: the atomic plannable unit (build-spec §2) ───────────
// Completed to full §2 shape at M0-4 (identity fields M0-2, composition M0-3).

enum EffortLevel: Int, Codable { case noCook = 0, assembly, simple, involved }

enum CookMethod: String, Codable {
    case grill, griddle, stovetop, oven, airFryer, slowCooker, instantPot,
         microwave, noCook, smoker
}

enum SlotKind: String, Codable { case dinner, breakfast, lunch /* D-40 */ }

enum FrequencyTarget: String, Codable { case weekly, biweekly, monthly, quarterly, occasionally }

enum RotationState: String, Codable { case active, resting /* cooldown */, retired /* rare */ }

extension SlotKind {
    var displayName: String {
        switch self {
        case .dinner: "Dinner"
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        }
    }
}

@Model
final class Meal {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var title: String
    var freeformNotes: String         // "Snack plate dinner", "Chipotle takeout"
    var recipes: [Recipe]             // zero or more
    @Relationship(deleteRule: .cascade) var directItems: [RecipeItem] // ingredients not via a recipe
    var effort: EffortLevel
    var themeTags: [String]           // "mexican", "italian", "sheet-pan"
    var slots: [SlotKind]             // multi-slot (D-1): breakfast-for-dinner is real
    var requiresCalmDay: Bool         // D-1: only schedulable on peaceful/clean-kitchen days
    // Scheduling knobs
    var frequencyTarget: FrequencyTarget?   // nil = no target, scheduler free
    var rotationState: RotationState
    var cooldownUntil: Date?          // set by "everybody's sick of this"
    var lastEatenAt: Date?
    var lastScheduledAt: Date?
    // Leftover chains (D-4): intentional overproduction feeding later meals
    var producesComponents: [String]  // e.g. ["cooked rice"] — cook extra on purpose
    var requiresComponents: [String]  // e.g. ["cooked rice"] — leftover-DEPENDENT meal
    var componentFreshnessDays: Int   // consumer must run within N days of producer
    var moodTags: [String]            // "cozy", "griddle-day", "celebration" (D-8)
    var methods: [CookMethod]         // D-28: how it's made — grill, stovetop, oven, etc.
    var isEatingOut: Bool             // D-7: NEVER auto-scheduled; emergency/manual only
    var isAllTimeFavorite: Bool       // exempt from ALL fatigue mechanics
    var coreMemoryNote: String?       // "Elsie's first-day-of-school dinner"
    var coreMemoryOwner: FamilyMember?
    // Occasions
    var occasionTag: String?          // "thanksgiving", "caddie-birthday"

    // ── D-37 delete-rule inverses (canon 2026-07-07; deviations authorized) ──
    /// DM-5: a deleted meal takes its per-member scores with it.
    @Relationship(deleteRule: .cascade, inverse: \MemberMealScore.meal)
    var memberScores: [MemberMealScore]
    /// DM-6: a deleted meal gracefully nils any member's breakfast default.
    @Relationship(deleteRule: .nullify, inverse: \FamilyMember.currentBreakfast)
    var breakfastDefaultFor: [FamilyMember]
    /// D-40: lunch gets the same per-person-default treatment as breakfast.
    @Relationship(deleteRule: .nullify, inverse: \FamilyMember.currentLunch)
    var lunchDefaultFor: [FamilyMember]
    /// D-37: plan entries survive meal deletion with `meal == nil` — the
    /// needs-refill flag (CD-1/HC-8 spirit); they never silently vanish.
    @Relationship(deleteRule: .nullify, inverse: \PlanEntry.meal)
    var planEntries: [PlanEntry]

    init(
        title: String,
        freeformNotes: String = "",
        effort: EffortLevel = .simple,
        themeTags: [String] = [],
        slots: [SlotKind] = [.dinner],
        requiresCalmDay: Bool = false,
        frequencyTarget: FrequencyTarget? = nil,
        rotationState: RotationState = .active,
        producesComponents: [String] = [],
        requiresComponents: [String] = [],
        componentFreshnessDays: Int = TuningDefaults.componentFreshnessDays,
        moodTags: [String] = [],
        methods: [CookMethod] = [],
        isEatingOut: Bool = false,
        isAllTimeFavorite: Bool = false,
        coreMemoryNote: String? = nil,
        coreMemoryOwner: FamilyMember? = nil,
        occasionTag: String? = nil
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.title = title
        self.freeformNotes = freeformNotes
        self.recipes = []
        self.directItems = []
        self.effort = effort
        self.themeTags = themeTags
        self.slots = slots
        self.requiresCalmDay = requiresCalmDay
        self.frequencyTarget = frequencyTarget
        self.rotationState = rotationState
        self.cooldownUntil = nil
        self.lastEatenAt = nil
        self.lastScheduledAt = nil
        self.producesComponents = producesComponents
        self.requiresComponents = requiresComponents
        self.componentFreshnessDays = componentFreshnessDays
        self.moodTags = moodTags
        self.methods = methods
        self.isEatingOut = isEatingOut
        self.isAllTimeFavorite = isAllTimeFavorite
        self.coreMemoryNote = coreMemoryNote
        self.coreMemoryOwner = coreMemoryOwner
        self.occasionTag = occasionTag
        self.memberScores = []
        self.breakfastDefaultFor = []
        self.lunchDefaultFor = []
        self.planEntries = []
    }
}
