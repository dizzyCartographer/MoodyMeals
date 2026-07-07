import Foundation
import SwiftData

// ── People & needs (build-spec §2) ────────────────────────────

/// HARD dietary constraints — the scheduler MUST never violate these.
/// e.g. [.glutenFree] for Caddie.
enum DietaryRequirement: String, Codable {
    case glutenFree, dairyFree, nutFree, vegetarian /* extensible */
}

/// SOFT goals the scheduler optimizes toward.
/// e.g. Ria: [.hemeIron, .antiInflammatory]; Chad: [.highCalorie]
enum FoodNeedGoal: String, Codable {
    case hemeIron, antiInflammatory, highCalorie, highProtein
    case proteinVegStarch /* full-plate goal (D-35: generic case, no one hardcoded) */ /* extensible */
}

@Model
final class FamilyMember {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var name: String
    var isAdult: Bool
    /// Hard dietary requirements — scheduler MUST never violate.
    var hardRequirements: [DietaryRequirement]
    /// Soft goals the scheduler optimizes toward.
    var softGoals: [FoodNeedGoal]
    var notes: String                 // "meat-averse; needs protein+veg+starch"
    var currentBreakfast: Meal?       // the set-and-forget daily default
    var appetiteBase: Double          // servings multiplier (Chad ≈ 1.5; others 1.0)
    var appetiteFavoriteBoost: Double // extra when liking == +2 (Chad → up to 2.0). D-5
    /// D-28: CookMethod.rawValue → -2…+2. Ria: grill +2, oven -2.
    /// Not a mild preference — a 7:1 revealed law. Weighted hard.
    /// (String keys per SwiftData dictionary storage; canonical keys are CookMethod raw values — F12.)
    var methodAffinity: [String: Int]

    @Relationship(deleteRule: .cascade, inverse: \MemberMealScore.member)
    var mealScores: [MemberMealScore]

    @Relationship(inverse: \Snack.favoriteOf)
    var favoriteSnacks: [Snack]

    /// F17 (correctness-forced deviation, logged in QUESTIONS): explicit
    /// inverse for `Meal.coreMemoryOwner`. Without it, SwiftData silently
    /// paired coreMemoryOwner↔currentBreakfast as inverses (the only mutual
    /// Meal↔FamilyMember to-one pair), so setting one corrupted the other.
    @Relationship(inverse: \Meal.coreMemoryOwner)
    var coreMemoryMeals: [Meal]

    // ── D-37 delete-rule inverses (canon 2026-07-07) ──
    /// A deleted member simply drops out of attendee lists (D-5 subset semantics).
    @Relationship(inverse: \PlanEntry.attendees)
    var attendingEntries: [PlanEntry]
    /// A deleted member's cook-night assignments nil out.
    @Relationship(inverse: \PlanEntry.assignedCook)
    var cookNights: [PlanEntry]

    init(
        name: String,
        isAdult: Bool,
        hardRequirements: [DietaryRequirement] = [],
        softGoals: [FoodNeedGoal] = [],
        notes: String = "",
        currentBreakfast: Meal? = nil,
        appetiteBase: Double = 1.0,
        appetiteFavoriteBoost: Double = 0.0,
        methodAffinity: [String: Int] = [:]
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.name = name
        self.isAdult = isAdult
        self.hardRequirements = hardRequirements
        self.softGoals = softGoals
        self.notes = notes
        self.currentBreakfast = currentBreakfast
        self.appetiteBase = appetiteBase
        self.appetiteFavoriteBoost = appetiteFavoriteBoost
        self.methodAffinity = methodAffinity
        self.mealScores = []
        self.favoriteSnacks = []
        self.coreMemoryMeals = []
        self.attendingEntries = []
        self.cookNights = []
    }
}

// ── Per-member relationship to a meal (the two axes + safety) ─

@Model
final class MemberMealScore {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var member: FamilyMember
    var meal: Meal
    var liking: Int          // -2 (dislike) ... +2 (big hit), 0 default
    var fit: Int             // -2 ... +2 : how good it is FOR THEM (auto-suggested from goals+nutrition, user-overridable)
    var isSafeFood: Bool     // per-member denotation — never household-wide
    var notTodayUntil: Date? // per-person temporary hide
    var likesToCook: Bool    // D-6: kid cook-nights — likes to MAKE it, not just eat it

    init(
        member: FamilyMember,
        meal: Meal,
        liking: Int = 0,
        fit: Int = 0,
        isSafeFood: Bool = false,
        notTodayUntil: Date? = nil,
        likesToCook: Bool = false
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.member = member
        self.meal = meal
        self.liking = liking
        self.fit = fit
        self.isSafeFood = isSafeFood
        self.notTodayUntil = notTodayUntil
        self.likesToCook = likesToCook
    }
}
