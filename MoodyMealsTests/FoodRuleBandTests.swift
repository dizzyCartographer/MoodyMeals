import XCTest
import SwiftData
@testable import MoodyEngine

/// FR-1 acceptance: D-44 bands (stored + legacy mapping + overrides + the
/// quiche move) and D-45 structured FoodRules. The legacy §1 gate is
/// deliberately untouched — pinned here so FR-1 stays additive until the
/// FR-2 sign-off (D-57).
final class FoodRuleBandTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(AppSchema.models)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// House style: SAVE before traversing — this OS's SwiftData traps on
    /// deep reads of unsaved graphs (every green suite in this repo saves
    /// first, usually via the engine services' internal saves).
    @MainActor
    private func recipe(_ title: String = "r",
                        items: [(String, Bool?)],
                        in context: ModelContext) -> Recipe {
        let recipe = Recipe(title: title, kind: .loose)
        context.insert(recipe)
        for (name, gf) in items {
            let ingredient = Ingredient(name: name, perishability: .pantry,
                                        isGlutenFreeVerified: gf)
            context.insert(ingredient)
            let item = RecipeItem(ingredient: ingredient)
            context.insert(item)
            recipe.items.append(item)
        }
        try? context.save()
        return recipe
    }

    // MARK: Legacy mapping (no stored band)

    @MainActor
    func test_FR1_legacyMapping_carrierLine_readsAwaitingSubstitution() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let r = recipe(items: [("pasta", false), ("cheese", true)], in: context)
        XCTAssertEqual(MealBand.band(for: r), .awaitingSubstitution,
                       "a carrier is a calm question, never a wall (D-44)")
    }

    @MainActor
    func test_FR1_legacyMapping_unknownLine_readsNotCheckedYet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let r = recipe(items: [("mystery sauce", nil), ("rice", true)], in: context)
        XCTAssertEqual(MealBand.band(for: r), .notCheckedYet)
    }

    @MainActor
    func test_FR1_legacyMapping_allVerified_readsSafe() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let r = recipe(items: [("rice", true), ("beans", true)], in: context)
        XCTAssertEqual(MealBand.band(for: r), .safe)
    }

    // MARK: Stored bands + overrides

    @MainActor
    func test_FR1_storedBand_beatsLegacyMapping() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let r = recipe(items: [("rice", true)], in: context)   // legacy: safe
        r.gfBand = .unsafe
        r.gfBandSource = .assessment
        try context.save()
        XCTAssertEqual(MealBand.band(for: r), .unsafe)
    }

    @MainActor
    func test_FR1_manualOverride_beatsStandardModification() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let r = recipe(items: [("flour", false)], in: context)
        r.standardModification = "corn starch"
        r.gfBand = .unsafe
        r.gfBandSource = .manualOverride
        try context.save()
        XCTAssertEqual(MealBand.band(for: r), .unsafe,
                       "her overrides outrank everything, forever (D-44)")
    }

    @MainActor
    func test_FR1_quicheMove_standardModification_clearsToSafe() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let r = recipe("quiche", items: [("pie crust", false)], in: context)
        r.gfBand = .awaitingSubstitution
        r.gfBandSource = .assessment
        r.standardModification = "King Arthur gf pie crust mix"
        try context.save()
        XCTAssertEqual(MealBand.band(for: r), .safe,
                       "documented sub ⇒ fully safe, indicator gone (D-44)")
    }

    @MainActor
    func test_FR1_bandPersists_acrossFreshContext() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let r = recipe(items: [("rice", true)], in: context)
        r.gfBand = .awaitingSubstitution
        r.gfBandSource = .manualOverride
        r.standardModification = nil
        try context.save()
        let fresh = ModelContext(container)
        let fetched = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Recipe>()).first)
        XCTAssertEqual(fetched.gfBand, .awaitingSubstitution)
        XCTAssertEqual(fetched.gfBandSource, .manualOverride)
    }

    // MARK: Meal = worst of its parts

    @MainActor
    func test_FR1_mealBand_worstOfRecipes_unsafeWins() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let meal = Meal(title: "combo")
        context.insert(meal)
        let safe = recipe("a", items: [("rice", true)], in: context)
        let bad = recipe("b", items: [("bread", false)], in: context)
        bad.gfBand = .unsafe
        bad.gfBandSource = .manualOverride
        meal.recipes = [safe, bad]
        try context.save()
        XCTAssertEqual(MealBand.band(for: meal), .unsafe)
    }

    @MainActor
    func test_FR1_freeformOnlyMeal_readsNotCheckedYet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let meal = Meal(title: "Chipotle takeout", freeformNotes: "the usual order")
        context.insert(meal)
        try context.save()
        XCTAssertEqual(MealBand.band(for: meal), .notCheckedYet,
                       "unknown composition stays honest (D-38 fail-safe spirit)")
    }

    // MARK: FR-1 is ADDITIVE — the legacy §1 gate is untouched (D-57 gates)

    @MainActor
    func test_FR1_legacyGFGate_unaffectedByBands() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let meal = Meal(title: "banded but unverified")
        context.insert(meal)
        let r = recipe(items: [("mystery flour", nil)], in: context)
        r.gfBand = .safe                 // band says safe...
        r.gfBandSource = .manualOverride
        meal.recipes = [r]
        try context.save()
        XCTAssertFalse(meal.isGFVerifiedForCeliac,
                       "...but the OLD conservative gate still guards auto-fill until the §1 sign-off")
    }

    // MARK: FoodRules (D-45 structure)

    @MainActor
    func test_FR1_foodRule_roundTrips_structured() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let chuck = FamilyMember(name: "Chuck", isAdult: true)
        context.insert(chuck)
        context.insert(FoodRule(member: chuck, direction: .limit,
                                subject: "red meat & pork",
                                reason: "high cholesterol",
                                frequencyWindowDays: 7))
        try context.save()
        let fresh = ModelContext(container)
        let rule = try XCTUnwrap(try fresh.fetch(FetchDescriptor<FoodRule>()).first)
        XCTAssertEqual(rule.direction, .limit)
        XCTAssertEqual(rule.subject, "red meat & pork")
        XCTAssertEqual(rule.reason, "high cholesterol")
        XCTAssertEqual(rule.frequencyWindowDays, 7)
        XCTAssertEqual(rule.member?.name, "Chuck")
    }

    @MainActor
    func test_FR1_seed_rulesPresent_elsieAndCaddieHaveNone() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.loadIfNeeded(into: context)
        let rules = try context.fetch(FetchDescriptor<FoodRule>())
        XCTAssertEqual(rules.count, 5)
        let byMember = Dictionary(grouping: rules, by: { $0.member?.name ?? "?" })
        XCTAssertEqual(byMember["Chuck"]?.count, 1)
        XCTAssertEqual(byMember["Ria"]?.count, 3)
        XCTAssertEqual(byMember["Chad"]?.count, 1)
        XCTAssertNil(byMember["Elsie"], "Elsie has NO rule (D-35/D-44)")
        XCTAssertNil(byMember["Caddie"], "Caddie = the band model, not a rule row")
    }

    @MainActor
    func test_FR1_seed_idempotent_rulesDontDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedData.loadIfNeeded(into: context)
        try SeedData.loadIfNeeded(into: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodRule>()).count, 5)
    }

    @MainActor
    func test_FR1_backfill_preFRStoreGetsRulesOnce_deletionRespected() throws {
        let container = try makeContainer()
        let context = container.mainContext
        // A pre-FR-1 store: members exist, zero rules, no marker.
        context.insert(FamilyMember(name: "Ria", isAdult: true))
        context.insert(FamilyMember(name: "Chuck", isAdult: true))
        context.insert(FamilyMember(name: "Chad", isAdult: false))
        try context.save()

        try SeedData.loadIfNeeded(into: context)   // members present → backfill path
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodRule>()).count, 5)

        // Deliberately deleting rules is a DECISION — never resurrected.
        try context.fetch(FetchDescriptor<FoodRule>()).forEach { context.delete($0) }
        try context.save()
        try SeedData.loadIfNeeded(into: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodRule>()).count, 0)
    }

    @MainActor
    func test_FR1_backfill_renamedMembersSkipQuietly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(FamilyMember(name: "Somebody Else", isAdult: true))
        try context.save()
        try SeedData.loadIfNeeded(into: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodRule>()).count, 0,
                       "no name match ⇒ no backfill; the rules editor is their path")
        try SeedData.loadIfNeeded(into: context)   // marker set — never retries
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodRule>()).count, 0)
    }
}
