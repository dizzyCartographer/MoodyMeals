import SwiftData

/// Scaffold model so the SwiftData container has a valid schema at M0-1.
/// The real domain models (`FamilyMember`, `Meal`, …) arrive in M0-2 and get
/// added to `AppSchema.models`; `AppInfo` can be retired once they exist.
@Model
final class AppInfo {
    var key: String
    var value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// Single source of truth for the SwiftData schema. Grows as models land.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        AppInfo.self,
        // People & needs (M0-2)
        FamilyMember.self,
        MemberMealScore.self,
        // Food (M0-3)
        Ingredient.self,
        Recipe.self,
        RecipeItem.self,
        // Meals & planning (M0-4)
        Meal.self,
        PlanEntry.self,
        ThemeAnchor.self,
        // Staged: Snack completes at M0-5
        Snack.self,
    ]
}
