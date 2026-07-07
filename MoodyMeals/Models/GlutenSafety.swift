import Foundation

// ── Celiac safety evaluation (TEST_CASES §1) ──────────────────
// The rule everything builds on (spec §2 note 5): `isGlutenFreeVerified` is
// tri-state, and nil (unverified) = UNSAFE for any GF member. Amounts are
// irrelevant to safety (HC-6).

extension Ingredient {
    /// True ONLY on a positive label verification — nil/unverified is unsafe.
    var isVerifiedGlutenFree: Bool { isGlutenFreeVerified == true }
}

extension Recipe {
    /// A recipe is GF-verified only if EVERY ingredient is label-verified.
    /// One unverified item poisons the whole recipe (HC-6), regardless of
    /// amounts or recipe kind. Fail-safe standalone: a ZERO-item recipe is
    /// unknown composition and never reads verified — this property is the
    /// per-recipe API future scheduler filters (HC-1/HC-2) will call, so it
    /// must not rely on callers pre-filtering.
    var allIngredientsGFVerified: Bool {
        !items.isEmpty && items.allSatisfy { $0.ingredient.isVerifiedGlutenFree }
    }
}

extension Meal {
    /// HC-6: unverified status propagates to the meal — GF-verified only if
    /// every ingredient across all recipes and direct items is verified.
    ///
    /// CONSERVATIVE DEFAULTS (F16 + F16b, flagged for Ria, reversible):
    /// - No known ingredients at all (freeform-only, "Chipotle takeout") →
    ///   NOT verified: unknown composition = unverified composition.
    /// - Non-empty freeformNotes alongside known items → NOT verified either:
    ///   the notes are an unknown chunk ("Chipotle takeout" + GF chips must
    ///   not read safe because of the chips). If Ria rules notes are
    ///   commentary-not-composition, this is a one-line flip.
    /// Fail-safe for celiac; manual override stays possible via HC-5's
    /// confirm flow when scheduling lands.
    var isGFVerifiedForCeliac: Bool {
        guard freeformNotes.isEmpty else { return false }   // F16b
        let hasKnownComposition = !recipes.isEmpty || !directItems.isEmpty
        guard hasKnownComposition else { return false }     // F16
        return recipes.allSatisfy(\.allIngredientsGFVerified) // covers zero-item recipes
            && directItems.allSatisfy { $0.ingredient.isVerifiedGlutenFree }
    }
}
