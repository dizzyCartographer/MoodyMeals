import SwiftUI
import SwiftData
// Engine API is internal until the public-API pass (BACKLOG P5-1); the
// project.yml builds MoodyEngine with ENABLE_TESTABILITY for exactly this.
@testable import MoodyEngine

// AppState — the FACADE over MoodyEngine (the unification graft, P1).
//
// The @Published/API surface the screens bind to is unchanged; everything
// behind it is now a projection of the SwiftData engine store:
//   week        ← this calendar week's DINNER PlanEntries (WeekPlan date math)
//   tonight     ← today's dinner entry (nil meal = honest cold start, PT-1)
//   candidates  ← engine Meals minus eating-out (D-7: never auto-scheduled)
//   badges      ← derived per ATTENDING member from data (D-35: no member
//                 is ever hardcoded — GF verdict, isSafeFood, appetiteBase)
//   runs        ← ShoppingExplosion → RunRouting onto three proposed runs
//   guarantee   ← GuaranteeCheck.coveredThrough / violations, honest voice
// Streak/thread/tank/sass keep their v1 mechanics: persisted in the App Group
// MoodySnapshot, which is still emitted on every mutation (now sourced from
// the projections) so widgets and the Live Activity keep working.

@MainActor
final class AppState: ObservableObject {

    // MARK: Engine bootstrap

    private let container: ModelContainer?
    private var context: ModelContext? { container?.mainContext }

    /// Store lives in the App Group container (U-1); a store found in the old
    /// Application Support home is moved there on first resolve — data
    /// survives. Widgets still read the snapshot, never the store, so nothing
    /// cross-process opens SwiftData.
    private static var storeURL: URL {
        StoreLocation.resolve(
            groupContainer: FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Persistence.appGroupID),
            legacyDirectory: legacyStoreDirectory)
    }

    /// Pre-U-1 home; migration source and the no-entitlement fallback.
    private static var legacyStoreDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Moody", isDirectory: true)
    }

    private static func destroyStore() {
        // Both homes — a reset must not let a stale legacy store resurrect
        // through the migration on the next launch.
        let fm = FileManager.default
        var targets = StoreLocation.allFiles(
            of: StoreLocation.legacyStoreURL(directory: legacyStoreDirectory))
        if let group = fm.containerURL(
            forSecurityApplicationGroupIdentifier: Persistence.appGroupID) {
            targets += StoreLocation.allFiles(
                of: StoreLocation.groupStoreURL(container: group))
        }
        targets.forEach { try? fm.removeItem(at: $0) }
    }

    /// Never crash, never block launch: corrupt/unmigratable store → rebuild
    /// from seeds; total failure → in-memory so the app still opens.
    private static func makeContainer() -> ModelContainer? {
        let schema = Schema(AppSchema.models)
        if ProcessInfo.processInfo.environment["MOODY_RESET"] == "1" {
            destroyStore()   // MOODY_RESET=1 now wipes the SwiftData store too
        }
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, url: storeURL))
        } catch {
            destroyStore()
            return (try? ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, url: storeURL)))
                ?? (try? ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(schema: schema,
                                                       isStoredInMemoryOnly: true)))
        }
    }

    init() {
        container = Self.makeContainer()
        if let context {
            // First launch runs their real SeedData (idempotent, test-pinned).
            try? SeedData.loadIfNeeded(into: context)
        }
        if ProcessInfo.processInfo.environment["MOODY_RESET"] == "1" {
            Persistence.reset()
        } else if let snapshot = Persistence.load() {
            apply(snapshot)   // local-only state: streak / tank / thread / sass
        }
        projectAll()
        // syncExternal: true — once per launch, so a completion made on the
        // watch or by family overnight reconciles (CAL-3 drift spirit).
        scheduleSave(syncExternal: true)
    }

    // MARK: Cast (projected from engine FamilyMembers — D-35: names come from
    // data, never code; palette/blob assignment keys off seed order, not names)

    private static let castSlots: [(slot: PaletteSlot, variant: Int)] = [
        (Palette.pink, 0), (Palette.purple, 1), (Palette.green, 2),
        (Palette.blue, 3), (Palette.yellow, 4),
    ]

    private(set) var household: [HouseholdMember] = []

    let personas: [Persona] = [
        Persona(id: "hannah", name: "Hannah", role: "snarky best friend",
                slot: Palette.pink, blobVariant: 1, duty: .slump),
        Persona(id: "cat", name: "Cat", role: "chef · world's best aunt energy",
                slot: Palette.blue, blobVariant: 2, duty: .slump),
        Persona(id: "julie", name: "Julie", role: "ND · whip-smart",
                slot: Palette.purple, blobVariant: 3, duty: .comeback),
    ]

    // Benign fallbacks instead of force-unwraps: a typo'd id in scripted
    // content should never crash the thread — and neither should an empty
    // household (engine bootstrap failure).
    func persona(_ id: String) -> Persona { personas.first { $0.id == id } ?? personas[0] }
    func member(_ id: String) -> HouseholdMember {
        household.first { $0.id == id } ?? household.first
            ?? HouseholdMember(id: "", name: "—", need: nil,
                               blobColor: Palette.pink.color, blobVariant: 0, cookNight: nil)
    }

    // MARK: Plan (projection of this week's dinner PlanEntries)

    /// Pure projection now (widget snapshot + Today). The legacy write-back
    /// (`reconcileWeekEdits`) is GONE: its weekday→date diff mapping produced
    /// phantom entries (Sat Jul 11 / Tue Jul 14 — exact weekDates hits) after
    /// its writer views moved to the attic. Plan mutations go through
    /// assignMeal/clearPlan/togglePin exclusively.
    @Published private(set) var week: [DayPlan] = []

    /// Today's row. Cold start is canon (PT-1): no entry ⇒ `meal == nil` and
    /// the home door renders the honest empty state — never fallback-as-plan.
    var tonight: DayPlan {
        let today = Self.weekday(of: .now)
        return week.first { $0.day == today }
            ?? DayPlan(day: today, kind: .open, meal: nil)
    }

    var tonightLabel: String {
        guard tonight.meal != nil else { return "TONIGHT" }
        return "TONIGHT · \(tonight.day.long.uppercased())"
    }

    /// All engine meals EXCLUDING eating out (D-7: nuclear, never dealt or
    /// auto-scheduled). Dinner-slot meals lead, lowest effort first, so
    /// "deal me 3"'s prefix stays dinner-appropriate.
    private(set) var candidates: [Meal] = []

    /// A meal cookable entirely from the ALWAYS-STOCKED shelf if one exists,
    /// else the lowest-effort verified-GF meal (dinner slot preferred).
    var fallbackMeal: Meal {
        fallbackPresentation ?? candidates.first
            ?? Meal(id: "none", name: "—", effort: 1)
    }

    // MARK: Energy / streak / guarantee

    @Published var tank: Tank = DemoSeed.tank { didSet { scheduleSaveUnlessProjecting() } }
    @Published var streak: Streak = DemoSeed.streak { didSet { scheduleSaveUnlessProjecting() } }
    @Published var sassLevel: Double = DemoSeed.sassLevel { didSet { scheduleSaveUnlessProjecting() } }   // 0 mild … 10 full chaos

    /// GuaranteeCheck's verdict in home-door voice — quiet, honest, no shame.
    private(set) var guaranteeLine: String = ""

    // MARK: Shopping (projection: explosion → routing → guarantee)

    /// SHOP-4: one flat list grouped by store section. The run math still
    /// drives routing + the guarantee INTERNALLY; the user just sees "what
    /// we need", grouped for the store.
    @Published private(set) var sections: [ShoppingSection] = []
    /// The guarantee flagged something tight (colors the guarantee line).
    private(set) var guaranteeAtRisk = false

    /// B-4 in-store state: checked lines (keyed by display name) and Ria's
    /// own additions. Persisted in the snapshot; the ENGINE only ever sees
    /// completions (done runs + purchase records).
    @Published private(set) var checkedItems: Set<String> = []
    @Published private(set) var manualItems: [ManualShoppingItem] = []
    /// display name → raw ingredient name, rebuilt each projection — purchase
    /// records must carry the raw name or the guarantee never matches them.
    private var rawNameByItem: [String: String] = [:]

    // MARK: Thread (scripted v1 — swap MessageBank for a live generator later)

    @Published var thread: [ThreadMessage] = DemoSeed.thread { didSet { scheduleSaveUnlessProjecting() } }

    /// Today's noticer for the home sticky (Hannah/Cat alternate slump duty;
    /// Julie owns comebacks). Scripted in v1.
    var homeNote: (author: Persona, text: String, more: String) {
        // D-55: no effort minimizers — "just" tells her the job is beneath
        // explanation; stating the whole job respects it.
        (persona("hannah"), "\u{201C}fixings in the fridge. chopping is the whole job.\u{201D}", "+2 more · open thread →")
    }

    // MARK: Interactions

    /// One tap → instantly commits (no confirmation modal; undo = swap).
    /// The pick is attendee-safe (celiac attendee ⇒ GF-VERIFIED only; no HC-5
    /// override in the auto path), effort ≤ tank cap, never eating out (D-7),
    /// and prefers not-recently-eaten (lastEatenAt / cooldownUntil).
    func decideForMe() {
        let cap = effortCap
        let pool = decidePool().filter { Self.mappedEffort($0.effort) <= cap }
        let now = Date()
        let pick = pool.min { Self.decideRank($0, at: now) < Self.decideRank($1, at: now) }
            ?? engineMeal(forSlug: fallbackMeal.id)
        guard let pick else { return }
        commitTonightEngine(pick, viaSwap: false)   // decide = WeekPlan.assign
    }

    /// Exactly 3 alternatives (law 2), same safety filter as decide (never an
    /// unverified meal for a celiac attendee), fumes ranks low-effort first.
    /// A thin verified pool pads with the fallback, then next-lowest-effort
    /// verified meals — 3 stays 3 for any realistic library.
    func swapOptions() -> [Meal] {
        let tonightSlug = tonight.meal?.id
        let now = Date()
        var pool = decidePool().filter { slugForMeal[$0.id] != tonightSlug }
        pool.sort {
            if tank == .fumes, Self.mappedEffort($0.effort) != Self.mappedEffort($1.effort) {
                return Self.mappedEffort($0.effort) < Self.mappedEffort($1.effort)
            }
            return Self.decideRank($0, at: now) < Self.decideRank($1, at: now)
        }
        var picks = Array(pool.prefix(3))
        if picks.count < 3 {   // pad: fallback first, then by effort
            let padding = ([engineMeal(forSlug: fallbackMeal.id)].compactMap { $0 } + pool)
                .filter { meal in slugForMeal[meal.id] != tonightSlug
                    && !picks.contains(where: { $0.id == meal.id }) }
            picks += padding.prefix(3 - picks.count)
        }
        return picks.map { presentationMeal($0, attendees: engineMembers) }
    }

    func commitTonight(_ meal: Meal) {
        guard let engine = engineMeal(forSlug: meal.id) else { return }
        commitTonightEngine(engine, viaSwap: true)   // user pick = Tonight.swap
    }

    /// Fumes re-plans tonight to lowest effort / fallback; answers persist.
    func setTank(_ t: Tank) {
        tank = t
        if t == .fumes, let current = tonight.meal, current.effort > 1 {
            commitTonight(fallbackMeal)
        }
    }

    // MARK: - Engine caches (refreshed on every projection)

    private var engineMembers: [FamilyMember] = []
    private var engineMeals: [MoodyEngine.Meal] = []
    private var engineStaples: [StapleItem] = []
    private var engineIngredients: [Ingredient] = []
    private var engineDoneRuns: [MoodyEngine.ShoppingRun] = []
    private var engineRecipes: [MoodyEngine.Recipe] = []
    private var slugForMeal: [UUID: String] = [:]
    private var mealForSlug: [String: UUID] = [:]
    private var fallbackEngineID: UUID?
    private var fallbackPresentation: Meal?
    private var weekDates: [Date] = []

    /// Plan-header chip ("JUL 6–12"), derived from the projected week — the
    /// mockup's hardcoded date was fiction after its one true week.
    var weekSpanLabel: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
        let start = DateFormatter(); start.dateFormat = "MMM d"
        let sameMonth = Calendar.current.isDate(first, equalTo: last, toGranularity: .month)
        let end = DateFormatter(); end.dateFormat = sameMonth ? "d" : "MMM d"
        return "\(start.string(from: first))–\(end.string(from: last))".uppercased()
    }
    private var isProjecting = false

    private func engineMeal(forSlug slug: String) -> MoodyEngine.Meal? {
        guard let id = mealForSlug[slug] else { return nil }
        return engineMeals.first { $0.id == id }
    }

    // MARK: - Projections

    /// Monday-first week (the designed plan runs Mon→Sun, "JUL 6–12").
    private static var mondayFirstCalendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    private static func weekday(of date: Date) -> Weekday {
        Weekday(rawValue: (Calendar.current.component(.weekday, from: date) + 5) % 7) ?? .mon
    }

    private func projectAll() {
        isProjecting = true
        defer { isProjecting = false }
        refreshEngineCaches()
        projectWeekAndHousehold()
        projectShopping()
        projectLibrary()
        projectSettings()
        projectPlan()
        projectRecipes()
    }

    // MARK: - Meal library (B-1: browse/detail/add/edit/retire — the doors
    // to the engine's meals that the graft retired with the old UI)

    @Published private(set) var library: [LibraryMeal] = []

    private static func effortLabel(_ e: EffortLevel) -> String {
        switch e {
        case .noCook: "no cook"
        case .assembly: "assembly"
        case .simple: "simple"
        case .involved: "involved"
        }
    }

    private static func libraryItem(_ item: RecipeItem) -> LibraryRecipeItem {
        let amount: String
        if let value = item.amount {
            let number = value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value)) : String(value)
            amount = [number, item.unit].compactMap { $0 }.joined(separator: " ")
        } else {
            amount = ""
        }
        let gf = item.ingredient.isGlutenFreeVerified
        return LibraryRecipeItem(
            id: item.id,
            name: item.ingredient.name,
            amountText: amount,
            gfLabel: gf == true ? "GF ✓" : gf == false ? "not GF" : "check label",
            gfSafe: gf == true)
    }

    private func projectLibrary() {
        library = engineMeals.map { meal in
            return LibraryMeal(
                id: meal.id,
                name: meal.title,
                notes: meal.freeformNotes,
                effortLabel: Self.effortLabel(meal.effort),
                effortDots: Self.mappedEffort(meal.effort),
                slots: meal.slots.map(\.rawValue),
                tags: meal.themeTags,
                isAllTimer: meal.isAllTimeFavorite,
                isEatingOut: meal.isEatingOut,
                requiresCalmDay: meal.requiresCalmDay,
                rotation: meal.rotationState.rawValue,
                // FR-1: the meal wears its worst band (display truth; the
                // legacy verified gate still guards auto-fill until D-57).
                gfLabel: BandStyle.label(MealBand.band(for: meal).rawValue),
                gfSafe: MealBand.band(for: meal) == .safe,
                badges: badges(for: meal, attendees: engineMembers),
                recipes: meal.recipes
                    .sorted { $0.createdAt < $1.createdAt }
                    .map { recipe in
                        LibraryRecipe(
                            id: recipe.id,
                            title: recipe.title,
                            kindLabel: recipe.kind.rawValue,
                            items: recipe.items
                                .sorted { $0.createdAt < $1.createdAt }
                                .map(Self.libraryItem),
                            steps: recipe.steps,
                            bandRaw: MealBand.band(for: recipe).rawValue,
                            bandSourceRaw: recipe.gfBandSource.rawValue,
                            standardModification: recipe.standardModification ?? "",
                            source: recipe.source ?? "")
                    },
                directItems: meal.directItems
                    .sorted { $0.createdAt < $1.createdAt }
                    .map(Self.libraryItem))
        }
    }

    func draft(for id: UUID) -> MealDraft? {
        guard let meal = engineMeals.first(where: { $0.id == id }) else { return nil }
        return MealDraft(
            title: meal.title,
            notes: meal.freeformNotes,
            effortRaw: meal.effort.rawValue,
            slots: Set(meal.slots.map(\.rawValue)),
            tagsText: meal.themeTags.joined(separator: ", "),
            isAllTimer: meal.isAllTimeFavorite,
            isEatingOut: meal.isEatingOut,
            requiresCalmDay: meal.requiresCalmDay)
    }

    /// dinner-first stable order; an empty selection degrades to dinner —
    /// a slotless meal would be silently unschedulable.
    private static func slots(from raw: Set<String>) -> [SlotKind] {
        let ordered: [SlotKind] = [.dinner, .breakfast, .lunch]
        let picked = ordered.filter { raw.contains($0.rawValue) }
        return picked.isEmpty ? [.dinner] : picked
    }

    private static func parseTags(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func createMeal(from draft: MealDraft) {
        guard let context else { return }
        let title = draft.title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        context.insert(MoodyEngine.Meal(
            title: title,
            freeformNotes: draft.notes,
            effort: EffortLevel(rawValue: draft.effortRaw) ?? .simple,
            themeTags: Self.parseTags(draft.tagsText),
            slots: Self.slots(from: draft.slots),
            requiresCalmDay: draft.requiresCalmDay,
            isEatingOut: draft.isEatingOut,
            isAllTimeFavorite: draft.isAllTimer))
        try? context.save()
        projectAll()
        scheduleSave(syncExternal: true)
    }

    func updateMeal(_ id: UUID, from draft: MealDraft) {
        guard let context,
              let meal = engineMeals.first(where: { $0.id == id }) else { return }
        let title = draft.title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        meal.title = title
        meal.freeformNotes = draft.notes
        meal.effort = EffortLevel(rawValue: draft.effortRaw) ?? meal.effort
        meal.themeTags = Self.parseTags(draft.tagsText)
        meal.slots = Self.slots(from: draft.slots)
        meal.requiresCalmDay = draft.requiresCalmDay
        meal.isEatingOut = draft.isEatingOut
        meal.isAllTimeFavorite = draft.isAllTimer
        meal.updatedAt = .now   // F15 interim: touch on edit
        try? context.save()
        projectAll()
        scheduleSave(syncExternal: true)
    }

    // MARK: - Recipe editing (B-2: composition doors — live edits, no staging)

    enum ItemTarget {
        case recipe(UUID)   // recipe id
        case direct(UUID)   // meal id
    }

    func ingredientSuggestions(for query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return Array(engineIngredients
            .filter { $0.name.localizedCaseInsensitiveContains(q) }
            .prefix(6).map(\.name))
    }

    func isKnownIngredient(_ name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        return engineIngredients.contains {
            $0.name.compare(n, options: .caseInsensitive) == .orderedSame
        }
    }

    /// HC-7: reuse the catalog by (case-insensitive) name; a manually-typed
    /// NEW ingredient (`importVerification: nil`, `AddItemFields`'s path)
    /// enters fully UNVERIFIED — unchanged behavior. The import pipeline
    /// (paste/OCR) instead runs every line through `GlutenCarrierCheck`
    /// first and passes its verdict here: a carrier match → `false` (not
    /// GF, same state a manual "not GF" mark leaves); no match → `true`,
    /// per D-44 canon ("whole foods safe with no marking" — Ria's own
    /// approved policy, not a new call). Either way this only ever fills
    /// in a genuinely UNKNOWN ingredient (new, or existing with `nil`) —
    /// an ingredient someone already verified true or false, by hand or by
    /// a prior import, is never silently touched (HC-6: her calls persist).
    private func resolveIngredient(named raw: String,
                                   perishability: Perishability,
                                   importVerification: Bool? = nil) -> Ingredient? {
        guard let context else { return nil }
        let name = raw.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        if let existing = engineIngredients.first(where: {
            $0.name.compare(name, options: .caseInsensitive) == .orderedSame
        }) {
            if let importVerification, existing.isGlutenFreeVerified == nil {
                existing.isGlutenFreeVerified = importVerification
            }
            return existing
        }
        let fresh = Ingredient(name: name, perishability: perishability,
                               isGlutenFreeVerified: importVerification)
        context.insert(fresh)
        return fresh
    }

    /// All recipes — attached or standalone (the cache covers orphans too).
    private func engineRecipe(_ id: UUID) -> MoodyEngine.Recipe? {
        engineRecipes.first { $0.id == id }
    }

    // MARK: Recipes as first-class citizens (Ria 2026-07-13)

    @Published private(set) var recipesAll: [RecipeSummary] = []

    private func projectRecipes() {
        var usedIn: [UUID: [String]] = [:]
        for meal in engineMeals {
            for recipe in meal.recipes {
                usedIn[recipe.id, default: []].append(meal.title)
            }
        }
        recipesAll = engineRecipes.map { recipe in
            RecipeSummary(id: recipe.id, title: recipe.title,
                          kindLabel: recipe.kind.rawValue,
                          itemCount: recipe.items.count,
                          usedIn: (usedIn[recipe.id] ?? []).sorted())
        }
    }

    /// Editor projection for any recipe, attached or standalone.
    func libraryRecipe(_ id: UUID) -> LibraryRecipe? {
        guard let recipe = engineRecipe(id) else { return nil }
        return LibraryRecipe(
            id: recipe.id, title: recipe.title,
            kindLabel: recipe.kind.rawValue,
            items: recipe.items.sorted { $0.createdAt < $1.createdAt }
                .map(Self.libraryItem),
            steps: recipe.steps,
            bandRaw: MealBand.band(for: recipe).rawValue,
            bandSourceRaw: recipe.gfBandSource.rawValue,
            standardModification: recipe.standardModification ?? "",
            source: recipe.source ?? "")
    }

    /// Sets or clears the recipe's source (a URL or a cookbook title/page).
    func setRecipeSource(_ recipeID: UUID, text: String) {
        guard let recipe = engineRecipe(recipeID) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        recipe.source = trimmed.isEmpty ? nil : trimmed
        saveAndReproject()
    }

    // MARK: FR-1 band mutations (D-44: her calls are permanent)

    /// Manual banding — outranks any future re-assessment, forever.
    func setRecipeBand(_ recipeID: UUID, bandRaw: String) {
        guard let recipe = engineRecipe(recipeID),
              let band = GFBand(rawValue: bandRaw) else { return }
        recipe.gfBand = band
        recipe.gfBandSource = .manualOverride
        recipe.updatedAt = .now
        saveAndReproject()
    }

    /// The quiche move: a documented sub makes the recipe SAFE (indicator
    /// gone). Clearing the text restores the underlying band.
    func setStandardModification(_ recipeID: UUID, text: String) {
        guard let recipe = engineRecipe(recipeID) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        recipe.standardModification = trimmed.isEmpty ? nil : trimmed
        recipe.updatedAt = .now
        saveAndReproject()
    }

    /// Backfill for recipes imported before the carry-through fix landed:
    /// `resolveIngredient` now writes the import's carrier check into a
    /// brand-new ingredient, but anything captured earlier still sits at
    /// `nil` ("check label") even though the import already looked at it.
    /// This re-runs the same deterministic check on every still-unverified
    /// line in one recipe — never touches a line someone (or a prior
    /// import) already verified true or false (HC-6).
    func recheckGlutenCarriers(inRecipe recipeID: UUID) {
        guard let recipe = engineRecipe(recipeID) else { return }
        for item in recipe.items where item.ingredient.isGlutenFreeVerified == nil {
            item.ingredient.isGlutenFreeVerified = !GlutenCarrierCheck.isLikelyCarrier(item.ingredient.name)
        }
        saveAndReproject()
    }

    @discardableResult
    func createStandaloneRecipe(title: String, precise: Bool) -> UUID? {
        guard let context else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let recipe = MoodyEngine.Recipe(title: trimmed,
                                        kind: precise ? .precise : .loose)
        context.insert(recipe)
        saveAndReproject()
        return recipe.id
    }

    func attachRecipe(_ recipeID: UUID, toMeal mealID: UUID) {
        guard let recipe = engineRecipe(recipeID),
              let meal = engineMeals.first(where: { $0.id == mealID }),
              !meal.recipes.contains(where: { $0.id == recipeID }) else { return }
        meal.recipes.append(recipe)
        meal.updatedAt = .now
        saveAndReproject()
    }

    /// Detaches a recipe from ONE meal without deleting it (D-39 spirit) —
    /// the recipe survives, still usable standalone or in any other meal
    /// it's part of. Distinct from `deleteRecipe`, which removes the recipe
    /// everywhere and was previously (wrongly) reused for this.
    func detachRecipe(_ recipeID: UUID, fromMeal mealID: UUID) {
        guard let meal = engineMeals.first(where: { $0.id == mealID }) else { return }
        meal.recipes.removeAll { $0.id == recipeID }
        meal.updatedAt = .now
        saveAndReproject()
    }

    private func engineItem(_ id: UUID) -> RecipeItem? {
        engineMeals
            .flatMap { $0.recipes.flatMap(\.items) + $0.directItems }
            .first { $0.id == id }
    }

    private func saveAndReproject() {
        guard let context else { return }
        try? context.save()
        projectAll()
        scheduleSave(syncExternal: true)
    }

    @discardableResult
    func addRecipe(toMeal mealID: UUID, title: String, precise: Bool) -> UUID? {
        guard let context,
              let meal = engineMeals.first(where: { $0.id == mealID }) else { return nil }
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        let recipe = MoodyEngine.Recipe(title: t, kind: precise ? .precise : .loose)
        context.insert(recipe)
        meal.recipes.append(recipe)
        meal.updatedAt = .now
        saveAndReproject()
        return recipe.id
    }

    func updateRecipe(_ id: UUID, title: String, precise: Bool, stepsText: String,
                      sourceText: String = "") {
        guard let recipe = engineRecipe(id) else { return }
        let t = title.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { recipe.title = t }
        recipe.kind = precise ? .precise : .loose
        recipe.steps = stepsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let trimmedSource = sourceText.trimmingCharacters(in: .whitespaces)
        recipe.source = trimmedSource.isEmpty ? nil : trimmedSource
        recipe.updatedAt = .now
        saveAndReproject()
    }

    func deleteRecipe(_ id: UUID) {
        guard let context, let recipe = engineRecipe(id) else { return }
        context.delete(recipe)   // items cascade with it; the meal survives
        saveAndReproject()
    }

    func addItem(_ target: ItemTarget, name: String,
                 amount: Double?, unit: String?, perishabilityRaw: String) {
        guard let context else { return }
        let perishability = Perishability(rawValue: perishabilityRaw) ?? .pantry
        guard let ingredient = resolveIngredient(named: name,
                                                 perishability: perishability) else { return }
        let cleanUnit = unit?.trimmingCharacters(in: .whitespaces)
        let item = RecipeItem(ingredient: ingredient, amount: amount,
                              unit: cleanUnit?.isEmpty == false ? cleanUnit : nil)
        context.insert(item)
        switch target {
        case .recipe(let id):
            guard let recipe = engineRecipe(id) else { return }
            recipe.items.append(item)
            recipe.updatedAt = .now
        case .direct(let mealID):
            guard let meal = engineMeals.first(where: { $0.id == mealID }) else { return }
            meal.directItems.append(item)
            meal.updatedAt = .now
        }
        saveAndReproject()
    }

    func removeItem(_ id: UUID) {
        guard let context, let item = engineItem(id) else { return }
        context.delete(item)
        saveAndReproject()
    }

    // MARK: - Recipe paste import (M3-1 MoodyBrain + scoped M3-2: parse
    // only — the D-44 GF-band assessment is a separate PROMPT-REVIEW-gated
    // pass; a pasted recipe lands notCheckedYet, same as any hand-typed one
    // (HC-7: never silently safe). What IS included: deterministic gluten-
    // carrier flagging (`GlutenCarrierCheck`, D-44's seeded/extendable word
    // list) — a calm nudge, never an auto-applied substitution — and photo
    // import (`RecipeOCR`, on-device Vision) feeding the exact same parser.

    enum RecipePasteError: Error, Equatable {
        case notConfigured   // no ANTHROPIC_API_KEY in the environment
        case failed          // offline, API error, or an unreadable response
    }

    func parsePastedRecipe(_ text: String) async -> Result<RecipePastePreview, RecipePasteError> {
        do {
            let parsed = try await MoodyBrain.parseRecipe(from: text)
            let items = parsed.items.map {
                RecipePastePreview.Item(name: $0.name, amount: $0.amount, unit: $0.unit,
                                        substituteSuggestion: GlutenCarrierCheck.match(for: $0.name)?.suggestion)
            }
            return .success(RecipePastePreview(title: parsed.title, items: items, steps: parsed.steps))
        } catch MoodyBrainError.notConfigured {
            return .failure(.notConfigured)
        } catch {
            return .failure(.failed)
        }
    }

    /// Vision OCR on one or more recipe photos/screenshots, joined into one
    /// text block — the result feeds the SAME `parsePastedRecipe` above, so
    /// a photographed recipe and a typed one carry identical guarantees.
    func recognizeRecipeText(fromImageData datas: [Data]) async -> Result<String, RecipePasteError> {
        do {
            let text = try await RecipeOCR.recognizedText(fromImageData: datas)
            return .success(text)
        } catch {
            return .failure(.failed)
        }
    }

    /// Creates a standalone recipe straight from a reviewed paste/photo
    /// preview — matches every other recipe-creation path in the app (a
    /// meal is a collection of recipes, per Ria 2026-07-13; recipes are
    /// first-class on their own). Kind is precise only when every line
    /// carries an amount (D-36: mixed or amount-less lines stay loose,
    /// with per-item amounts riding where the text gave them either way).
    /// Returns the RECIPE id — pair with `createMeal(wrappingRecipe:)` to
    /// make it schedulable.
    @discardableResult
    func createStandaloneRecipe(fromPastedRecipe preview: RecipePastePreview) -> UUID? {
        guard let context else { return nil }
        let title = preview.title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }
        let allHaveAmounts = !preview.items.isEmpty && preview.items.allSatisfy { $0.amount != nil }
        let trimmedSource = preview.source.trimmingCharacters(in: .whitespaces)
        let recipe = MoodyEngine.Recipe(title: title, kind: allHaveAmounts ? .precise : .loose,
                                        steps: preview.steps,
                                        source: trimmedSource.isEmpty ? nil : trimmedSource)
        context.insert(recipe)
        for item in preview.items {
            // Every import line gets a real (if simple) assessment — carrier
            // match -> false; no match -> true, D-44's whole-food default —
            // so the meal page reflects what the import actually found
            // instead of everything reading as untouched notCheckedYet.
            let verified = !GlutenCarrierCheck.isLikelyCarrier(item.name)
            guard let ingredient = resolveIngredient(named: item.name, perishability: .pantry,
                                                      importVerification: verified)
            else { continue }
            let recipeItem = RecipeItem(ingredient: ingredient, amount: item.amount, unit: item.unit)
            context.insert(recipeItem)
            recipe.items.append(recipeItem)
        }
        saveAndReproject()
        return recipe.id
    }

    /// Wraps an existing recipe (standalone, or already in another meal —
    /// a recipe can ride in more than one, same as `attachRecipe`) in a
    /// brand-new schedulable meal. This is the door from "just a recipe"
    /// to "something on the plan" — the same door recipe import and the
    /// standalone Recipes list were both missing.
    @discardableResult
    func createMeal(wrappingRecipe recipeID: UUID) -> UUID? {
        guard let context, let recipe = engineRecipe(recipeID) else { return nil }
        let meal = MoodyEngine.Meal(title: recipe.title)
        context.insert(meal)
        meal.recipes.append(recipe)
        saveAndReproject()
        return meal.id
    }

    /// Retire, never delete, from the library (D-39's spirit for meals too:
    /// hidden from pickers, history intact). Plan entries keep their D-37
    /// flag-and-refill rails; reactivating is the same one tap.
    func setMealRetired(_ id: UUID, _ retired: Bool) {
        guard let context,
              let meal = engineMeals.first(where: { $0.id == id }) else { return }
        meal.rotationState = retired ? .retired : .active
        meal.updatedAt = .now
        try? context.save()
        projectAll()
        scheduleSave(syncExternal: true)
    }

    private func refreshEngineCaches() {
        guard let context else { return }
        engineMembers = (try? context.fetch(FetchDescriptor<FamilyMember>(
            sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)]))) ?? []
        engineMeals = (try? context.fetch(FetchDescriptor<MoodyEngine.Meal>(
            sortBy: [SortDescriptor(\.title)]))) ?? []
        engineStaples = (try? context.fetch(FetchDescriptor<StapleItem>(
            sortBy: [SortDescriptor(\.name)]))) ?? []
        engineIngredients = (try? context.fetch(FetchDescriptor<Ingredient>(
            sortBy: [SortDescriptor(\.name)]))) ?? []
        engineDoneRuns = ((try? context.fetch(FetchDescriptor<MoodyEngine.ShoppingRun>(
            sortBy: [SortDescriptor(\.plannedDate)]))) ?? [])
            .filter { $0.status == .done }
        engineRecipes = (try? context.fetch(FetchDescriptor<MoodyEngine.Recipe>(
            sortBy: [SortDescriptor(\.title)]))) ?? []

        // Stable slugs from titles; collisions get a numeric suffix.
        slugForMeal = [:]
        mealForSlug = [:]
        for meal in engineMeals {
            var slug = Self.slug(for: meal.title)
            var n = 2
            while mealForSlug[slug] != nil { slug = "\(Self.slug(for: meal.title))-\(n)"; n += 1 }
            slugForMeal[meal.id] = slug
            mealForSlug[slug] = meal.id
        }

        // Fallback: staple-cookable if any, else lowest-effort SAFE-band (D-57).
        let stapleNames = Set(engineStaples.map { $0.name.lowercased() })
        let pool = engineMeals.filter { !$0.isEatingOut }
        let fallback = pool.first(where: { meal in
            let ingredients = Self.allIngredients(of: meal)
            return !ingredients.isEmpty
                && ingredients.allSatisfy { stapleNames.contains($0.name.lowercased()) }
        }) ?? pool
            .filter { MealBand.band(for: $0) == .safe }
            .min { a, b in
                (a.slots.contains(.dinner) ? 0 : 1, Self.mappedEffort(a.effort), a.title)
                    < (b.slots.contains(.dinner) ? 0 : 1, Self.mappedEffort(b.effort), b.title)
            }
        fallbackEngineID = fallback?.id
        fallbackPresentation = fallback.map { presentationMeal($0, attendees: engineMembers) }

        // Candidate surface: everything except eating out (D-7), dinner first.
        candidates = engineMeals
            .filter { !$0.isEatingOut }
            .sorted { a, b in
                (a.slots.contains(.dinner) ? 0 : 1, Self.mappedEffort(a.effort), a.title)
                    < (b.slots.contains(.dinner) ? 0 : 1, Self.mappedEffort(b.effort), b.title)
            }
            .map { presentationMeal($0, attendees: engineMembers) }
    }

    private func projectWeekAndHousehold() {
        guard let context else { week = []; household = []; return }
        let now = Date()
        weekDates = WeekPlan.weekDays(containing: now, calendar: Self.mondayFirstCalendar)
        let todayAnchor = WeekPlan.dayAnchor(for: now)

        var projected: [DayPlan] = []
        var cookNights: [UUID: Weekday] = [:]
        for date in weekDates {
            let day = Self.weekday(of: date)
            let entry = try? WeekPlan.entry(on: date, slot: .dinner, in: context)
            if let cook = entry?.assignedCook { cookNights[cook.id] = day }
            guard let entry, let engineMeal = entry.meal else {
                // No entry — or a D-37 needs-refill entry — reads as open.
                projected.append(DayPlan(day: day, kind: .open, meal: nil,
                                         locked: entry?.isLocked ?? false))
                continue
            }
            let anchor = WeekPlan.dayAnchor(for: entry.date)
            var kind: DayKind
            switch entry.status {
            case .eaten: kind = .done
            case .skipped: kind = .rest    // planned skip: streak intact, zero shame
            default: kind = anchor == todayAnchor ? .tonight : .planned
            }
            if kind == .planned, let cook = entry.assignedCook, !cook.isAdult {
                kind = .kidCook            // D-6, from data — never a named constant
            }
            projected.append(DayPlan(day: day, kind: kind,
                                     meal: presentationMeal(engineMeal, attendees: entry.attendees),
                                     locked: entry.isLocked,
                                     attendance: attendanceLine(for: entry)))
        }
        week = projected

        household = engineMembers.enumerated().map { index, m in
            let cast = Self.castSlots[index % Self.castSlots.count]
            return HouseholdMember(id: Self.slug(for: m.name), name: m.name,
                                   need: Self.need(of: m),
                                   blobColor: cast.slot.color, blobVariant: cast.variant,
                                   cookNight: cookNights[m.id])
        }
    }

    private func attendanceLine(for entry: PlanEntry) -> String {
        guard !entry.attendees.isEmpty else { return "everyone home" }
        let attending = Set(entry.attendees.map(\.id))
        let away = engineMembers.filter { !attending.contains($0.id) }.map(\.name)
        return away.isEmpty ? "everyone home" : "\(away.joined(separator: ", ")) away"
    }

    /// AM strip line, derived per member (D-35 — no name ever hardcoded).
    /// Members without a default just don't appear (DM-6's graceful nil);
    /// none on file ⇒ nil and the strip hides until M7 lands breakfasts.
    var amBreakfastLine: String? {
        let lines = engineMembers.compactMap { member -> String? in
            guard let breakfast = member.currentBreakfast else { return nil }
            return "\(member.name) \(breakfast.title)"
        }
        return lines.isEmpty ? nil : lines.joined(separator: " · ")
    }

    private static func need(of member: FamilyMember) -> DietaryNeed? {
        if member.isGFGuaranteed { return .celiac }
        if !member.staples.isEmpty { return .safeFoodsOnly }   // lifeline on file (D-6)
        if member.appetiteBase > 1 { return .doubleVolume }
        return nil
    }

    // MARK: - Meal projection (slug / effort / keyword / badges)

    /// noCook|assembly → 1 dot, simple → 2, involved → 3.
    private static func mappedEffort(_ effort: EffortLevel) -> Int {
        switch effort {
        case .noCook, .assembly: return 1
        case .simple: return 2
        case .involved: return 3
        }
    }

    private static func slug(for title: String) -> String {
        let cleaned = String(title.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " })
        return cleaned.split(separator: " ").joined(separator: "-")
    }

    /// Magnet keyword: first theme tag, else the title's first word — with a
    /// second word when the first is a ≤2-char qualifier ("GF mac", not the
    /// "Thu gf" magnet HANDOFF warned about). D-4: sheet-pan framing never
    /// surfaces, even if a tag sneaks into data.
    private static func keyword(for meal: MoodyEngine.Meal) -> String {
        if let tag = meal.themeTags.first(where: {
            !$0.isEmpty && !$0.localizedCaseInsensitiveContains("sheet")
        }) { return tag }
        let words = meal.title.split(separator: " ").map { $0.lowercased() }
        guard let first = words.first else { return "" }
        if first.count <= 2, words.count > 1 { return "\(first) \(words[1])" }
        return first
    }

    private static func allIngredients(of meal: MoodyEngine.Meal) -> [Ingredient] {
        meal.recipes.flatMap(\.items).map(\.ingredient) + meal.directItems.map(\.ingredient)
    }

    private func presentationMeal(_ meal: MoodyEngine.Meal,
                                  attendees: [FamilyMember]) -> Meal {
        Meal(id: slugForMeal[meal.id] ?? Self.slug(for: meal.title),
             name: meal.title,
             effort: Self.mappedEffort(meal.effort),
             isFallback: meal.id == fallbackEngineID,
             keyword: Self.keyword(for: meal),
             badges: badges(for: meal, attendees: attendees))
    }

    /// D-35 fixed at the root: every badge derives from an ATTENDING member's
    /// DATA — GF hard requirement × the meal's verdict, isSafeFood scores,
    /// appetiteBase — zero hardcoded names. Cold start has zero scores by
    /// canon (PT-1), so safe-food badges are legitimately absent until the
    /// swipe-rating pass creates them; nothing is faked.
    private func badges(for meal: MoodyEngine.Meal,
                        attendees: [FamilyMember]) -> [SafetyBadgeInfo] {
        // SwiftData to-many arrays don't guarantee order — re-rank attendees
        // by the household roster so the GF guarantee always leads the row.
        let attending = Set(attendees.map(\.id))
        let ordered = engineMembers.filter { attending.contains($0.id) }
        var out: [SafetyBadgeInfo] = []
        for member in (ordered.isEmpty ? attendees : ordered) {
            if member.isGFGuaranteed {
                switch MealBand.band(for: meal) {   // D-57: band vocabulary
                case .safe:
                    out.append(SafetyBadgeInfo(text: "\(member.name) GF ✓", slot: Palette.green))
                case .awaitingSubstitution:   // schedulable; cook-time reminder
                    out.append(SafetyBadgeInfo(text: "\(member.name) — sub needed", slot: Palette.yellow))
                case .notCheckedYet:
                    out.append(SafetyBadgeInfo(text: "\(member.name) — not checked", slot: Palette.yellow))
                case .unsafe:   // yellow ceiling, words carry the weight (law 4)
                    out.append(SafetyBadgeInfo(text: "\(member.name) — unsafe", slot: Palette.yellow))
                }
            }
            if meal.memberScores.first(where: { $0.member.id == member.id })?.isSafeFood == true {
                out.append(SafetyBadgeInfo(text: "\(member.name) ✓", slot: Palette.blue))
            }
            if member.appetiteBase > 1 {
                out.append(SafetyBadgeInfo(text: "\(member.name) ×\(member.appetiteBase.formatted())",
                                           slot: Palette.yellow))
            }
        }
        return out
    }

    // MARK: - Decide / swap machinery

    private var effortCap: Int { tank == .fumes ? 1 : (tank == .steady ? 2 : 3) }

    /// The attendee-safe pool decide and swap draw from: dinner-slot, never
    /// eating out (D-7), never retired, per-member "not today" honored.
    /// D-57 (HC-1): with a GF-guaranteed member home, UNSAFE and
    /// NOT-CHECKED-YET are excluded; SAFE and AWAITING-SUBSTITUTION fill
    /// freely — the awaiting badge rides as a cook-time reminder.
    private func decidePool() -> [MoodyEngine.Meal] {
        let now = Date()
        let celiacAttending = engineMembers.contains(where: \.isGFGuaranteed)
        return engineMeals.filter { meal in
            guard !meal.isEatingOut,
                  meal.slots.contains(.dinner),
                  meal.rotationState != .retired else { return false }
            if celiacAttending {
                let band = MealBand.band(for: meal)
                if band == .unsafe || band == .notCheckedYet { return false }
            }
            if engineMembers.contains(where: { Tonight.isHidden(meal, for: $0, at: now) }) {
                return false
            }
            return true
        }
    }

    /// Prefer not-recently-eaten: active cooldowns sink, then oldest (or
    /// never) lastEatenAt, then effort, then title for stability.
    private static func decideRank(_ meal: MoodyEngine.Meal,
                                   at now: Date) -> (Int, Date, Int, String) {
        let coolingDown = (meal.cooldownUntil ?? .distantPast) > now ? 1 : 0
        return (coolingDown, meal.lastEatenAt ?? .distantPast,
                mappedEffort(meal.effort), meal.title)
    }

    private func commitTonightEngine(_ meal: MoodyEngine.Meal, viaSwap: Bool) {
        guard let context else { return }
        if viaSwap, let entry = try? Tonight.todaysDinner(in: context) {
            try? Tonight.swap(entry, to: meal, in: context)   // status records the swap
        } else {
            _ = try? WeekPlan.assign(meal, on: .now, slot: .dinner,
                                     attendees: engineMembers, in: context)
        }
        projectAll()
        scheduleSave(syncExternal: true)
    }

    // MARK: - Shopping projection (their pure pipeline, presentation-mapped)

    private static func nextDate(calendarWeekday target: Int, onOrAfter date: Date) -> Date {
        let cal = Calendar.current
        let delta = (target - cal.component(.weekday, from: date) + 7) % 7
        return cal.date(byAdding: .day, value: delta, to: date) ?? date
    }

    private func projectShopping() {
        guard let context, let weekEnd = weekDates.last,
              let horizon = Calendar.current.date(byAdding: .day, value: 1, to: weekEnd)
        else {
            sections = []
            guaranteeAtRisk = false
            guaranteeLine = "the list can't load right now"
            return
        }

        let now = Date()
        let today = WeekPlan.dayAnchor(for: now)
        let entries = (try? ShoppingExplosion.entries(from: today, to: horizon, in: context)) ?? []
        rawNameByItem = [:]

        // Three proposed runs: top-up today, weekly Wednesday, bulk Saturday
        // (run cadence is a placeholder until real run scheduling lands —
        // routing/guarantee treat them as this week's shopping plan).
        let candidateRuns: [(tier: RunTier, plannedDate: Date)] = [
            (.midweek, today),
            (.weekly, Self.nextDate(calendarWeekday: 4, onOrAfter: today)),
            (.bulk, Self.nextDate(calendarWeekday: 7, onOrAfter: today)),
        ]

        // Completed runs cover their cycle window (mirrors GuaranteeCheck's
        // doneWindows) — a bought item leaves the LISTS too, not just the
        // violation math. B-4.
        let doneSnapshots: [GuaranteeCheck.RunSnapshot] = engineDoneRuns.map { run in
            GuaranteeCheck.RunSnapshot(
                tier: run.tier, plannedDate: run.plannedDate, status: .done,
                purchasedNames: Set(run.purchaseRecords.map { $0.itemName.lowercased() }))
        }
        let allRunDays = (candidateRuns.map { WeekPlan.dayAnchor(for: $0.plannedDate) }
            + engineDoneRuns.map { WeekPlan.dayAnchor(for: $0.plannedDate) })
            .sorted()
        let doneWindows: [(names: Set<String>, start: Date, end: Date)] = doneSnapshots.map {
            let start = WeekPlan.dayAnchor(for: $0.plannedDate)
            let end = allRunDays.first { $0 > start } ?? .distantFuture
            return ($0.purchasedNames, start, end)
        }
        func purchasedCovers(_ name: String, mealDay: Date,
                             perishability: Perishability) -> Bool {
            doneWindows.contains { window in
                guard window.names.contains(name),
                      mealDay >= window.start, mealDay <= window.end else { return false }
                guard perishability == .freshShort else { return true }
                let age = Calendar.current.dateComponents(
                    [.day], from: window.start, to: mealDay).day ?? .max
                return age <= TuningDefaults.freshShortShelfDays
            }
        }

        // The engine's builder owns the merge (SL-6/PT-7): one line per
        // ingredient, amounts re-summed across every meal that needs it,
        // strictest need-by — the projection just presents its groups.
        // (Was a per-entry explode with first-wins dedup: two dinners sharing
        // an ingredient silently dropped the second dinner's amount.)
        let built = ShoppingListBuilder.build(
            entries: entries,
            // Always-on (Ria 2026-07-13): every staple rides every list
            // unless this cycle already brought it home — the check happens
            // at the pantry, not the store; unneeded ones ride as a net.
            staples: engineStaples.map {
                ShoppingListBuilder.Staple(
                    name: $0.name, minOnHand: $0.minOnHand,
                    perishability: $0.ingredient?.perishability ?? .pantry)
            },
            runs: candidateRuns,
            covered: { name, perishability, mealDate in
                purchasedCovers(name, mealDay: WeekPlan.dayAnchor(for: mealDate),
                                perishability: perishability)
            },
            now: now)

        // The guarantee, from their check: the proposed trio + every DONE run
        // (purchases cover inside their windows). The run trio stays INTERNAL
        // from here on — the user sees one flat list (SHOP-4).
        let result = GuaranteeCheck.check(
            entries: entries,
            runs: candidateRuns.map {
                GuaranteeCheck.RunSnapshot(tier: $0.tier, plannedDate: $0.plannedDate,
                                           status: .confirmed)
            } + doneSnapshots,
            now: now)

        // One flat list, grouped the way the store is walked. At-risk lines
        // (nothing scheduled can carry them in time) stay ON the list — they
        // still need buying; the guarantee line carries the warning.
        var bySection: [StoreSection: [ShoppingItem]] = [:]
        var seen: Set<String> = []
        for line in built.groups.flatMap(\.lines) + built.atRisk {
            guard seen.insert(line.ingredientName.lowercased()).inserted else { continue }
            let section = StoreSection.infer(name: line.ingredientName,
                                             perishability: line.perishability)
            // Freshness deadline as a small chip — fresh items only.
            var deadline: String? = nil
            if line.perishability == .freshShort, let need = line.neededBy {
                deadline = "by \(Self.weekday(of: need).short)"
            }
            bySection[section, default: []].append(ShoppingItem(
                name: line.text,
                category: line.source == .staple ? "always stocked" : "",
                deadline: deadline))
            rawNameByItem[line.text] = line.ingredientName
        }

        var projected: [ShoppingSection] = StoreSection.walkOrder.compactMap {
            guard let items = bySection[$0], !items.isEmpty else { return nil }
            return ShoppingSection(id: $0.rawValue, title: $0.title, items: items)
        }
        // Ria's own additions always have a home — and the quick-add lives
        // here, so the section rides along even when empty. B-4.
        projected.append(ShoppingSection(
            id: "extras", title: "Anything else",
            items: manualItems.map { manual in
                rawNameByItem[manual.name] = manual.name
                return ShoppingItem(name: manual.name, category: "")
            }))
        sections = projected

        guaranteeAtRisk = !result.violations.isEmpty
        if let violation = result.violations.first {
            let count = violation.missingItems.count
            // D-48: state the mechanic (the items ARE on the list), never
            // minimize the errand.
            guaranteeLine = count == 1
                ? "\(violation.mealTitle) needs 1 item sooner than the next shop — it's on the list"
                : "\(violation.mealTitle) needs \(count) items sooner than the next shop — they're on the list"
        } else if entries.isEmpty {
            // No "no dinners planned yet" narration (Ria 2026-07-14): with
            // nothing to guarantee, the line just states what's true now —
            // the staples list (if any) speaks for itself underneath.
            guaranteeLine = bySection.isEmpty
                ? "nothing to buy ✓"
                : "always-stocked check ✓"
        } else if let covered = result.coveredThrough {
            guaranteeLine = "groceries covered thru \(Self.weekday(of: covered).long) ✓"
        } else {
            guaranteeLine = "every planned dinner is covered ✓"
        }
    }

    // MARK: - Plan calendar (NB: the in-app calendar — assign any future date)

    @Published private(set) var planDays: [PlanDay] = []
    /// Every planned day, unbounded — the month grid looks days up here.
    @Published private(set) var planByDay: [Date: PlanCell] = [:]
    private static let planHorizonDays = 28

    private func projectPlan() {
        guard let context else { planDays = []; planByDay = [:]; return }
        let calendar = Calendar.current
        let today = WeekPlan.dayAnchor(for: .now)
        guard let end = calendar.date(byAdding: .day, value: Self.planHorizonDays,
                                      to: today) else { planDays = []; return }
        let allEntries = (try? context.fetch(FetchDescriptor<PlanEntry>())) ?? []

        var byDayAll: [Date: [SlotKind: PlanEntry]] = [:]
        for entry in allEntries {
            byDayAll[WeekPlan.dayAnchor(for: entry.date), default: [:]][entry.slot] = entry
        }
        planByDay = byDayAll.mapValues {
            PlanCell(dinner: planSlotInfo($0[.dinner]), lunch: planSlotInfo($0[.lunch]))
        }

        let entries = allEntries.filter { $0.date >= today && $0.date < end }
        var bySlot: [Date: [SlotKind: PlanEntry]] = [:]
        for entry in entries {
            bySlot[WeekPlan.dayAnchor(for: entry.date), default: [:]][entry.slot] = entry
        }
        let weekdayFormat = DateFormatter(); weekdayFormat.dateFormat = "EEE"
        let monthFormat = DateFormatter(); monthFormat.dateFormat = "MMM"
        planDays = (0..<Self.planHorizonDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today)
            else { return nil }
            let slots = bySlot[day] ?? [:]
            let dayNumber = calendar.component(.day, from: day)
            return PlanDay(
                id: day,
                weekdayLabel: weekdayFormat.string(from: day),
                dayLabel: String(dayNumber),
                monthLabel: (offset == 0 || dayNumber == 1)
                    ? monthFormat.string(from: day) : nil,
                isToday: offset == 0,
                dinner: planSlotInfo(slots[.dinner]),
                lunch: planSlotInfo(slots[.lunch]))
        }
    }

    private func planSlotInfo(_ entry: PlanEntry?) -> PlanSlotInfo? {
        guard let entry else { return nil }
        guard let meal = entry.meal else {
            // D-37: a deleted meal leaves a flagged entry, never a silent gap.
            return PlanSlotInfo(mealID: nil, name: "needs a meal",
                                pinned: entry.isLocked, needsRefill: true,
                                gfBadge: nil, gfSafe: false)
        }
        let celiacHome = engineMembers.contains(where: \.isGFGuaranteed)
        let band = MealBand.band(for: meal)
        return PlanSlotInfo(
            mealID: meal.id, name: meal.title,
            pinned: entry.isLocked, needsRefill: false,
            gfBadge: celiacHome ? BandStyle.label(band.rawValue) : nil,
            gfSafe: band == .safe)
    }

    /// HC-5 surface check: nil ⇒ frictionless; names ⇒ the confirm copy
    /// (attending GF-hard members, from data — D-35).
    func gfConfirmationNames(forMeal id: UUID) -> [String]? {
        guard let meal = engineMeals.first(where: { $0.id == id }) else { return nil }
        let attendees = engineMembers   // D-5 default: everyone home
        return WeekPlan.requiresGFConfirmation(meal, attendees: attendees)
            ? WeekPlan.gfAttendeeNames(attendees) : nil
    }

    func assignMeal(_ mealID: UUID, on date: Date, slotRaw: String) {
        guard let context,
              let meal = engineMeals.first(where: { $0.id == mealID }),
              let slot = SlotKind(rawValue: slotRaw) else { return }
        _ = try? WeekPlan.assign(meal, on: date, slot: slot,
                                 attendees: engineMembers, in: context)
        saveAndReproject()
    }

    func clearPlan(on date: Date, slotRaw: String) {
        guard let context, let slot = SlotKind(rawValue: slotRaw),
              let entry = (try? WeekPlan.entry(on: date, slot: slot, in: context)) ?? nil
        else { return }
        try? WeekPlan.clear(entry: entry, in: context)
        saveAndReproject()
    }

    func togglePin(on date: Date, slotRaw: String) {
        guard let context, let slot = SlotKind(rawValue: slotRaw),
              let entry = (try? WeekPlan.entry(on: date, slot: slot, in: context)) ?? nil
        else { return }
        entry.isLocked.toggle()
        entry.updatedAt = .now
        saveAndReproject()
    }

    // MARK: - Settings (B-5 household/staples + B-6 calendar sync)

    @Published private(set) var settingsMembers: [SettingsMember] = []
    @Published private(set) var settingsStaples: [SettingsStaple] = []
    @Published private(set) var memberRules: [MemberRule] = []
    @Published private(set) var calendarSyncEnabled =
        UserDefaults.standard.bool(forKey: "calendarSyncEnabled")

    private lazy var calendarSync = CalendarSyncService(store: EventKitCalendarStore())

    /// Status line under the toggle — CAL-3: denial is visible, never silent.
    var calendarSyncStatus: String {
        if !calendarSyncEnabled { return "off — dinners stay in the app only" }
        calendarSync.refreshAvailability()
        if let reason = calendarSync.unavailableReason { return reason }
        return "planned dinners appear on the Moody calendar"
    }

    // MARK: - Claude API key (D-63) — Keychain-backed so recipe paste works
    // on a real installed build, not just from Xcode. Entered once here;
    // never leaves the device, never committed.

    var hasAnthropicAPIKey: Bool { APIKeyStore.hasKeychainKey }

    func saveAnthropicAPIKey(_ key: String) {
        APIKeyStore.save(key)
        objectWillChange.send()
    }

    func clearAnthropicAPIKey() {
        APIKeyStore.clear()
        objectWillChange.send()
    }

    private func projectSettings() {
        settingsMembers = engineMembers.map { member in
            SettingsMember(id: member.id, name: member.name, isAdult: member.isAdult,
                           isGFHard: member.isGFGuaranteed,
                           appetiteBase: member.appetiteBase)
        }
        settingsStaples = engineStaples.map {
            SettingsStaple(id: $0.id, name: $0.name, minOnHand: $0.minOnHand)
        }
        let rules = (try? context?.fetch(FetchDescriptor<FoodRule>(
            sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        memberRules = rules.map { rule in
            MemberRule(
                id: rule.id,
                memberID: rule.member?.id ?? UUID(),
                memberName: rule.member?.name ?? "household",
                directionLabel: rule.direction.levelLabel,   // D-58: her words
                subject: rule.displaySubject,
                reason: rule.reason,
                windowText: rule.frequencyWindowDays.map { days in
                    rule.direction == .limit ? "≤1× per \(days) days" : "≥1× per \(days) days"
                },
                isGluten: rule.category == .gluten)
        }
    }

    func updateMember(_ id: UUID, name: String, appetiteBase: Double) {
        guard let member = engineMembers.first(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { member.name = trimmed }
        member.appetiteBase = appetiteBase
        member.updatedAt = .now
        saveAndReproject()
    }

    // MARK: D-58 restriction records — the one record type, GF included

    /// Category picker options for views (engine enum stays behind the facade).
    static let ruleCategories: [(raw: String, name: String)] =
        RuleCategory.allCases.map { ($0.rawValue, $0.displayName) }
    /// Levels in Ria's words (stored raws stay stable).
    static let ruleLevels: [(raw: String, name: String)] = [
        ("never", "never"), ("limit", "infrequent"), ("boost", "increased"),
    ]

    func addRule(memberID: UUID, categoryRaw: String, levelRaw: String) {
        guard let context,
              let member = engineMembers.first(where: { $0.id == memberID }),
              let category = RuleCategory(rawValue: categoryRaw),
              let level = RuleDirection(rawValue: levelRaw) else { return }
        // One record per (member, category): re-adding replaces the level.
        if let existing = member.foodRules.first(where: { $0.category == category }) {
            existing.direction = level
            existing.frequencyWindowDays = level == .limit ? 7 : nil
            existing.updatedAt = .now
        } else {
            context.insert(FoodRule(
                member: member, direction: level,
                subject: category.displayName.lowercased(), reason: "",
                frequencyWindowDays: level == .limit ? 7 : nil,
                category: category))
        }
        // D-58: a Gluten·never record IS the guarantee — retire the legacy
        // flag so record-removal genuinely removes protection (no zombie).
        if category == .gluten {
            member.hardRequirements.removeAll { $0 == .glutenFree }
        }
        member.updatedAt = .now
        saveAndReproject()   // badges, pools, pickers re-derive everywhere
    }

    /// Removal is a decision (the gluten confirm lives UI-side, once).
    func removeRule(_ id: UUID) {
        guard let context,
              let rule = engineMembers.flatMap(\.foodRules).first(where: { $0.id == id })
        else { return }
        if rule.category == .gluten, let member = rule.member {
            // Removing the record removes the guarantee — the legacy flag
            // must not silently resurrect it.
            member.hardRequirements.removeAll { $0 == .glutenFree }
            member.updatedAt = .now
        }
        context.delete(rule)
        saveAndReproject()
    }

    func addStaple(_ name: String, minOnHand: String) {
        guard let context else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let amount = minOnHand.trimmingCharacters(in: .whitespaces)
        context.insert(StapleItem(name: trimmed,
                                  minOnHand: amount.isEmpty ? "1" : amount))
        saveAndReproject()
    }

    func removeStaple(_ id: UUID) {
        guard let context,
              let staple = engineStaples.first(where: { $0.id == id }) else { return }
        context.delete(staple)   // a list row, not the ingredient catalog (D-39 intact)
        saveAndReproject()
    }

    // MARK: SHOP-3 — the Reminders mirror (watch / family sharing / Siri)

    @Published private(set) var remindersSyncEnabled =
        UserDefaults.standard.bool(forKey: "remindersSyncEnabled")

    private lazy var remindersStore = EventKitRemindersStore()
    /// Titles the mirror pushed — only these may ever be removed from
    /// Reminders (anything else there is the user's own). Persisted.
    private var managedReminderTitles: Set<String> = []
    private var isSyncingReminders = false

    /// Status line under the toggle — CAL-3: denial is visible, never silent.
    var remindersSyncStatus: String {
        if !remindersSyncEnabled { return "off — the list stays in the app only" }
        if remindersStore.authorization == .denied {
            return "Reminders access is off — the list here keeps working; access lives in iOS Settings"
        }
        return "the list mirrors to \u{201C}\(RemindersSync.listName)\u{201D} in Reminders — watch, family sharing, and Siri all reach it there"
    }

    func setRemindersSync(_ enabled: Bool) {
        remindersSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "remindersSyncEnabled")
        guard enabled else { return }
        Task { @MainActor in
            await syncReminders()
            objectWillChange.send()   // status line refresh either way
        }
    }

    /// ShoppingView calls this on appear — completions made on the watch or
    /// by family land in the app without waiting for a local mutation.
    func refreshRemindersFromOutside() {
        guard remindersSyncEnabled else { return }
        Task { @MainActor in await syncReminders() }
    }

    /// The mirror's view of the list: every line with its checked state,
    /// titled exactly as displayed (and as check-off keys them).
    private var reminderLines: [RemindersSync.AppLine] {
        sections.flatMap { section in
            section.items.map {
                RemindersSync.AppLine(title: $0.name,
                                      isChecked: isChecked($0.name))
            }
        }
    }

    @MainActor
    private func syncReminders() async {
        guard remindersSyncEnabled, !isSyncingReminders else { return }
        isSyncingReminders = true
        defer { isSyncingReminders = false }
        let outcome = await RemindersSync.sync(
            lines: reminderLines,
            managedTitles: managedReminderTitles,
            store: remindersStore)
        guard case .synced(let changes) = outcome else { return }
        managedReminderTitles = changes.managedTitles
        var mutated = false
        // Completed out there → checked here.
        for title in changes.checkedTitles
        where sections.contains(where: { $0.items.contains { $0.name == title } }) {
            if checkedItems.insert(title).inserted { mutated = true }
        }
        // Added out there (Siri/watch/family) → the user's own items here.
        for title in changes.importedTitles
        where !manualItems.contains(where: { $0.name == title }) {
            manualItems.append(ManualShoppingItem(name: title, runID: "extras"))
            mutated = true
        }
        if mutated {
            projectAll()      // imported items enter the list surface
            scheduleSave()
        }
    }

    func setCalendarSync(_ enabled: Bool) {
        calendarSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "calendarSyncEnabled")
        guard enabled, let context else { return }
        Task { @MainActor in
            await calendarSync.requestAccessIfNeeded()
            if calendarSync.isAvailable { calendarSync.syncAll(in: context) }
            objectWillChange.send()   // status line refresh either way
        }
    }

    /// Keeps the device calendar current after any plan mutation (debounced
    /// alongside the snapshot save; a no-op when off or unavailable).
    private func syncCalendarIfEnabled() {
        guard calendarSyncEnabled, calendarSync.isAvailable, let context else { return }
        calendarSync.syncAll(in: context)
    }

    // MARK: - Shopping interactions (B-4, flat since SHOP-4)

    func isChecked(_ itemName: String) -> Bool {
        checkedItems.contains(itemName)
    }

    func toggleChecked(_ itemName: String) {
        checkedItems.formSymmetricDifference([itemName])
        scheduleSave(syncExternal: true)
    }

    func addManualItem(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              !manualItems.contains(where: { $0.name == trimmed }) else { return }
        manualItems.append(ManualShoppingItem(name: trimmed, runID: "extras"))
        projectAll()
        scheduleSave(syncExternal: true)
    }

    func removeManualItem(named name: String) {
        manualItems.removeAll { $0.name == name }
        checkedItems.remove(name)
        projectAll()
        scheduleSave(syncExternal: true)
    }

    func isManual(_ itemName: String) -> Bool {
        manualItems.contains { $0.name == itemName }
    }

    /// "Done shopping" is the engine-true moment: a DONE ShoppingRun with a
    /// PurchaseRecord per checked line lands in the store, the guarantee
    /// recomputes over the new coverage window, and bought lines leave the
    /// list. Unchecked lines simply stay for next time.
    func finishShopping() {
        guard let context else { return }
        let checkedNames = sections.flatMap(\.items).map(\.name)
            .filter { isChecked($0) }
        guard !checkedNames.isEmpty else { return }

        let now = Date()
        // Tier is bookkeeping here — coverage windows are tier-agnostic and
        // the visible list no longer wears run tiers (SHOP-4).
        let engineRun = MoodyEngine.ShoppingRun(
            tier: .midweek, plannedDate: now, status: .done)
        context.insert(engineRun)
        for display in checkedNames {
            let raw = rawNameByItem[display] ?? display
            context.insert(PurchaseRecord(
                itemName: raw, purchasedAt: now,
                ingredient: engineIngredients.first {
                    $0.name.compare(raw, options: .caseInsensitive) == .orderedSame
                },
                sourceRun: engineRun))
        }
        // Bought manual items leave the list; unchecked ones stay put.
        manualItems.removeAll { checkedNames.contains($0.name) }
        checkedItems.removeAll()
        saveAndReproject()
    }

    /// "Have it" (SHOP-4): the pantry check said it's already home — record
    /// it like a purchase made today, so the list AND the guarantee agree.
    /// Coverage runs until the next shop; after that the item can ride again.
    func markHaveIt(_ itemName: String) {
        guard let context else { return }
        if isManual(itemName) { return removeManualItem(named: itemName) }
        let raw = rawNameByItem[itemName] ?? itemName
        let now = Date()
        let today = WeekPlan.dayAnchor(for: now)
        // One "pantry check" run per day collects these records.
        let run = engineDoneRuns.first {
            WeekPlan.dayAnchor(for: $0.plannedDate) == today && $0.status == .done
        } ?? {
            let created = MoodyEngine.ShoppingRun(
                tier: .midweek, plannedDate: now, status: .done)
            context.insert(created)
            return created
        }()
        context.insert(PurchaseRecord(
            itemName: raw, purchasedAt: now,
            ingredient: engineIngredients.first {
                $0.name.compare(raw, options: .caseInsensitive) == .orderedSame
            },
            sourceRun: run))
        checkedItems.remove(itemName)
        saveAndReproject()
    }

    // MARK: - Persistence (App Group snapshot: widget contract + local state)

    private var saveTask: Task<Void, Never>?
    private var suppressSaves = false

    private func scheduleSaveUnlessProjecting() {
        guard !isProjecting else { return }
        scheduleSave()
    }

    /// Whether the coalesced save in flight should also push to EventKit.
    /// Mood/streak/thread saves don't touch the plan or the shopping list —
    /// syncing them anyway is what made Reminders/Calendar notify the family
    /// every time Ria adjusted her capacity tank or posted in the thread.
    private var pendingExternalSync = false

    /// Coalesces into one write ~0.5s after the last change. The snapshot is
    /// sourced from the projections, so widgets/Live Activity keep working
    /// exactly as before (P2 moves them onto richer projections).
    /// - `syncExternal`: true only for engine mutations that can change the
    ///   plan/shopping list (saveAndReproject, meal CRUD, shopping actions) —
    ///   never for the mood-tracking @Published properties.
    private func scheduleSave(syncExternal: Bool = false) {
        guard !suppressSaves else { return }
        if syncExternal { pendingExternalSync = true }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }
            // `runs: []` — the three-run cards retired at SHOP-4; the field
            // stays so older snapshot decoders keep working.
            Persistence.save(MoodySnapshot(week: week, streak: streak, tank: tank,
                                           runs: [], thread: thread,
                                           sassLevel: sassLevel, savedAt: Date(),
                                           checkedItems: checkedItems,
                                           manualItems: manualItems,
                                           managedReminderTitles: managedReminderTitles))
            guard self.pendingExternalSync else { return }
            self.pendingExternalSync = false
            syncCalendarIfEnabled()   // B-6: the device calendar follows the plan
            await syncReminders()     // SHOP-3: the Reminders list follows too
        }
    }

    /// Only the local-mechanics state overlays from disk — week/runs are
    /// projections of the engine store now and rebuild on every launch.
    private func apply(_ snapshot: MoodySnapshot) {
        suppressSaves = true
        defer { suppressSaves = false }
        streak = snapshot.streak
        tank = snapshot.tank
        thread = snapshot.thread
        sassLevel = snapshot.sassLevel
        // Pre-SHOP-4 checks were keyed "runID|name" — those runs are gone;
        // stale keys would never match and would silently inflate the count.
        checkedItems = Set(snapshot.checkedItems.filter { !$0.contains("|") })
        manualItems = snapshot.manualItems
        managedReminderTitles = snapshot.managedReminderTitles
    }
}

// MARK: - Local-state seeds (streak/tank/sass mechanics + the scripted thread
// are unchanged this pass; week/meals/shopping now come from SeedData)

enum DemoSeed {

    static let tank: Tank = .steady
    static let streak = Streak(current: 2, personalBest: 23, freezeTokens: 2, state: .rebuilding)
    static let sassLevel: Double = 6

    static let thread: [ThreadMessage] = [
        ThreadMessage(author: .persona("hannah"),
                      text: "fixings in the fridge. chopping is the whole job.",
                      kind: .moment, tapbacks: ["♥ 2", "★ Chuck"]),
        ThreadMessage(author: .persona("cat"),
                      text: "warm the tortillas in a dry pan, 30 sec a side. game changer, I promise.",
                      kind: .aside),
        ThreadMessage(author: .persona("julie"),
                      text: "day 2 of the rebuild. task re-initiation costs more dopamine than the task. you paid it. respect."),
        ThreadMessage(author: .family("chuck"),
                      text: "I can do pickup if the lime situation is dire"),
        ThreadMessage(author: .persona("hannah"),
                      text: "the lime situation is always dire, Chuck. it's called being a household."),
    ]
}
