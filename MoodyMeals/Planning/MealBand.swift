import Foundation

// ── D-44 band derivation (FR-1) ──────────────────────────────
// The stored band is truth when set; legacy tri-state maps in when it isn't
// (pre-assessment stores). The MEAL wears its worst recipe band. This is
// DISPLAY/EDITING truth only until FR-2's §1 sign-off — the legacy
// verified-only gate (GlutenSafety / isGFVerifiedForCeliac) keeps guarding
// auto-fill and HC-5 unchanged underneath.

enum MealBand {

    /// Effective band for one recipe.
    /// Precedence: standard modification ⇒ SAFE (D-44: "documented sub ⇒
    /// fully safe, indicator gone") — unless Ria's manual band says
    /// otherwise (her overrides outrank everything, including her sub note);
    /// then the stored band; then the legacy tri-state mapping:
    /// any explicit gluten line ⇒ awaitingSubstitution (carriers are a calm
    /// question, not a wall); any unknown line ⇒ notCheckedYet; else safe.
    @MainActor
    static func band(for recipe: Recipe) -> GFBand {
        if recipe.gfBandSource == .manualOverride, let manual = recipe.gfBand {
            return manual
        }
        if let modification = recipe.standardModification,
           !modification.trimmingCharacters(in: .whitespaces).isEmpty {
            return .safe
        }
        if let stored = recipe.gfBand { return stored }
        return legacyBand(items: recipe.items)
    }

    /// Direct items have no recipe to carry a band — legacy mapping applies.
    @MainActor
    static func bandForDirectItems(_ items: [RecipeItem]) -> GFBand {
        legacyBand(items: items)
    }

    /// Worst-of across the meal's parts. Freeform-only meals (zero known
    /// ingredients) read notCheckedYet — same honesty as D-38's fail-safe.
    @MainActor
    static func band(for meal: Meal) -> GFBand {
        var bands = meal.recipes.map { band(for: $0) }
        if !meal.directItems.isEmpty {
            bands.append(bandForDirectItems(meal.directItems))
        }
        if bands.isEmpty {
            bands.append(meal.freeformNotes.isEmpty ? .safe : .notCheckedYet)
        }
        return bands.max(by: { severity($0) < severity($1) }) ?? .notCheckedYet
    }

    @MainActor
    private static func legacyBand(items: [RecipeItem]) -> GFBand {
        if items.isEmpty { return .notCheckedYet }
        if items.contains(where: { $0.ingredient.isGlutenFreeVerified == false }) {
            return .awaitingSubstitution
        }
        if items.contains(where: { $0.ingredient.isGlutenFreeVerified == nil }) {
            return .notCheckedYet
        }
        return .safe
    }

    /// Ordering for worst-of: safe < awaiting < notChecked < unsafe.
    private static func severity(_ band: GFBand) -> Int {
        switch band {
        case .safe: 0
        case .awaitingSubstitution: 1
        case .notCheckedYet: 2
        case .unsafe: 3
        }
    }
}
