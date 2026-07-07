import Foundation
import SwiftData

// ── Meal: the atomic plannable unit (build-spec §2) ───────────
// STAGED BUILD-OUT (not deviation): M0-2 seeded the identity fields;
// M0-3 adds the food-composition fields (needed for HC-6 meal-level
// safety propagation); the planning knobs land at M0-4.

@Model
final class Meal {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    var title: String
    var freeformNotes: String         // "Snack plate dinner", "Chipotle takeout"
    var recipes: [Recipe]             // zero or more
    @Relationship(deleteRule: .cascade) var directItems: [RecipeItem] // ingredients not via a recipe

    init(title: String, freeformNotes: String = "") {
        self.id = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.title = title
        self.freeformNotes = freeformNotes
        self.recipes = []
        self.directItems = []
    }
}
