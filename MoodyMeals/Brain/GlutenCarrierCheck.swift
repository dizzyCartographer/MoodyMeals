import Foundation

// ── Gluten-carrier flagging for recipe import ─────────────────────────
// D-44 canon: "gluten carriers (seeded: flour, bread, pasta, crackers,
// beer, regular soy sauce; extendable) are the only class that raises
// anything — whole foods safe with no marking." This is that list,
// extended a bit further (the seed was illustrative, not exhaustive) and
// kept strictly DETERMINISTIC — a word-list match, never an AI judgment
// call about food safety. The generative per-recipe assessment (FR-3b,
// D-45's per-rule annotation sweep) is separate, larger, PROMPT-REVIEW
// gated work; this is a much smaller, auditable assist layered on top of
// the exact same signal the app already trusts (`Ingredient.
// isGlutenFreeVerified` — see MealBand.legacyBand). A match here never
// applies a substitution on its own — HC-7's "never silently safe" cuts
// both ways: it never silently changes either.

enum GlutenCarrierCheck {
    struct Match: Equatable {
        var keyword: String
        var suggestion: String
    }

    /// keyword → a plain-language substitute suggestion. Single-word
    /// keywords match whole words only (so "buckwheat" never matches
    /// "wheat", "bunch" never matches "bun"); multi-word phrases match as
    /// substrings, which is safe since they're specific enough on their own.
    private static let carriers: [String: String] = [
        "flour": "a 1:1 gluten-free flour blend",
        "bread": "gluten-free bread",
        "breadcrumbs": "gluten-free breadcrumbs or panko",
        "panko": "gluten-free panko",
        "pasta": "gluten-free pasta",
        "spaghetti": "gluten-free spaghetti",
        "noodles": "gluten-free noodles",
        "macaroni": "gluten-free macaroni",
        "penne": "gluten-free penne",
        "lasagna": "gluten-free lasagna sheets",
        "ramen": "gluten-free ramen noodles",
        "udon": "gluten-free noodles (udon is usually wheat)",
        "orzo": "gluten-free orzo or rice",
        "couscous": "quinoa or gluten-free couscous",
        "crackers": "gluten-free crackers",
        "pretzels": "gluten-free pretzels",
        "croutons": "gluten-free croutons",
        "stuffing": "a gluten-free stuffing mix",
        "beer": "a gluten-free beer, or swap for broth",
        "soy sauce": "tamari or coconut aminos",
        "teriyaki": "a gluten-free teriyaki sauce",
        "hoisin": "a gluten-free hoisin sauce",
        "worcestershire": "a gluten-free worcestershire sauce",
        "barley": "a gluten-free grain (rice, quinoa)",
        "malt": "a gluten-free sweetener or extract",
        "wheat": "a gluten-free substitute",
        "farro": "quinoa or rice",
        "seitan": "a gluten-free protein (tofu, tempeh)",
        "cake mix": "a gluten-free cake mix",
        "pancake mix": "a gluten-free pancake mix",
        "tortilla": "a gluten-free tortilla",
        "pita": "gluten-free pita or flatbread",
        "bun": "a gluten-free bun",
        "buns": "gluten-free buns",
        "cereal": "a gluten-free cereal",
        "cookie": "gluten-free cookies",
        "cookies": "gluten-free cookies",
        "biscuit": "a gluten-free biscuit mix",
        "graham cracker": "gluten-free graham crackers",
        "gravy": "a cornstarch-thickened gluten-free gravy",
        "roux": "a cornstarch or gluten-free-flour roux",
        "wonton": "gluten-free wonton wrappers",
        "dumpling": "gluten-free dumpling wrappers",
        "dumplings": "gluten-free dumpling wrappers",
        "oats": "certified gluten-free oats",
        "oatmeal": "certified gluten-free oatmeal",
    ]

    /// Multi-word keywords match as plain substrings — extracted once so
    /// the tokenized path below only has to handle single words.
    private static let phraseKeywords: [(phrase: String, suggestion: String)] =
        carriers.filter { $0.key.contains(" ") }.map { ($0.key, $0.value) }
    private static let wordKeywords: [String: String] =
        carriers.filter { !$0.key.contains(" ") }

    /// The name reads as already handled — an explicit GF claim on the
    /// label means the shopper already solved it, so nothing to flag.
    private static func alreadyMarkedGF(_ lowered: String) -> Bool {
        lowered.contains("gluten free") || lowered.contains("gluten-free")
            || lowered == "gf" || lowered.hasPrefix("gf ") || lowered.hasSuffix(" gf")
            || lowered.contains(" gf ")
    }

    /// Nil for whole foods and anything not on the list — produce, meat,
    /// dairy, herbs, spices never match because they're simply not here.
    static func match(for ingredientName: String) -> Match? {
        let lowered = ingredientName.lowercased()
        guard !alreadyMarkedGF(lowered) else { return nil }

        for (phrase, suggestion) in phraseKeywords where lowered.contains(phrase) {
            return Match(keyword: phrase, suggestion: suggestion)
        }
        let words = Set(lowered.split(whereSeparator: { !$0.isLetter }).map(String.init))
        for (keyword, suggestion) in wordKeywords where words.contains(keyword) {
            return Match(keyword: keyword, suggestion: suggestion)
        }
        return nil
    }

    static func isLikelyCarrier(_ ingredientName: String) -> Bool {
        match(for: ingredientName) != nil
    }
}
