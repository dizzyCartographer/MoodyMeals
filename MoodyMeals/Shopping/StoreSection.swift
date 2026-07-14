import Foundation

// ── SHOP-4 (Ria 2026-07-13): one flat list, grouped the way a store is ──
// The run math (routing / guarantee) stays internal; the list the user sees
// answers "what do we need?", grouped by where things live in the store.

enum StoreSection: String, Codable, CaseIterable {
    case produce, meat, dairy, pantry, frozen

    var title: String {
        switch self {
        case .produce: "Produce"
        case .meat: "Meat & fish"
        case .dairy: "Dairy & eggs"
        case .pantry: "Pantry"
        case .frozen: "Frozen"
        }
    }

    /// Display order — Ria's list order from the directive.
    static let walkOrder: [StoreSection] = [.produce, .meat, .dairy, .pantry, .frozen]

    /// Best-effort placement: perishability decides the temperature zone;
    /// name words split the fresh zones (meat vs dairy vs produce). A wrong
    /// guess is cosmetic — the item is still on the list, still counted.
    static func infer(name: String, perishability: Perishability) -> StoreSection {
        switch perishability {
        case .pantry: return .pantry
        case .freezer: return .frozen
        case .freshShort, .refrigeratedLong:
            // Whole-word matching: "eggplant" must not read as "egg".
            let words = Set(name.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty })
            if !words.isDisjoint(with: TuningDefaults.meatSectionWords) { return .meat }
            if !words.isDisjoint(with: TuningDefaults.dairySectionWords) { return .dairy }
            // Fresh defaults to produce; other chilled goods live with dairy.
            return perishability == .freshShort ? .produce : .dairy
        }
    }
}
