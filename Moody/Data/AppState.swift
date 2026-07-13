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
        scheduleSave()        // widgets get the fresh projection promptly
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

    @Published var runs: [ShoppingRun] = [] {
        didSet {
            guard !isProjecting else { return }
            scheduleSave()
        }
    }

    /// B-4 in-store state: checked lines (keys "runID|display name") and
    /// Ria's own additions. Persisted in the snapshot; the ENGINE only ever
    /// sees completions (done runs + purchase records).
    @Published private(set) var checkedItems: Set<String> = []
    @Published private(set) var manualItems: [ManualShoppingItem] = []
    /// display name → raw ingredient name, rebuilt each projection — purchase
    /// records must carry the raw name or the guarantee never matches them.
    private var rawNameByRunItem: [String: String] = [:]

    private(set) var alwaysStocked: [ShoppingItem] = []

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
                            standardModification: recipe.standardModification ?? "")
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
        scheduleSave()
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
        scheduleSave()
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

    /// HC-7: reuse the catalog by (case-insensitive) name; a NEW ingredient
    /// enters UNVERIFIED (nil tri-state = unsafe for GF members until checked).
    private func resolveIngredient(named raw: String,
                                   perishability: Perishability) -> Ingredient? {
        guard let context else { return nil }
        let name = raw.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        if let existing = engineIngredients.first(where: {
            $0.name.compare(name, options: .caseInsensitive) == .orderedSame
        }) { return existing }
        let fresh = Ingredient(name: name, perishability: perishability)
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
            standardModification: recipe.standardModification ?? "")
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

    private func engineItem(_ id: UUID) -> RecipeItem? {
        engineMeals
            .flatMap { $0.recipes.flatMap(\.items) + $0.directItems }
            .first { $0.id == id }
    }

    private func saveAndReproject() {
        guard let context else { return }
        try? context.save()
        projectAll()
        scheduleSave()
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

    func updateRecipe(_ id: UUID, title: String, precise: Bool, stepsText: String) {
        guard let recipe = engineRecipe(id) else { return }
        let t = title.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { recipe.title = t }
        recipe.kind = precise ? .precise : .loose
        recipe.steps = stepsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
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
        scheduleSave()
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

        alwaysStocked = engineStaples.map { ShoppingItem(name: $0.name, category: "staple") }
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
        scheduleSave()
    }

    // MARK: - Shopping projection (their pure pipeline, presentation-mapped)

    private static func nextDate(calendarWeekday target: Int, onOrAfter date: Date) -> Date {
        let cal = Calendar.current
        let delta = (target - cal.component(.weekday, from: date) + 7) % 7
        return cal.date(byAdding: .day, value: delta, to: date) ?? date
    }

    private static func category(for perishability: Perishability) -> String {
        switch perishability {
        case .freshShort: return "fresh"
        case .refrigeratedLong: return "chilled"
        case .freezer: return "frozen"
        case .pantry: return "pantry"
        }
    }

    /// Presentation run ids are stable ("topup"/"weekly"/"bulk") — check-off
    /// keys, manual items, and routes all hang off them.
    private static func runID(for tier: RunTier) -> String {
        switch tier {
        case .midweek: "topup"
        case .weekly: "weekly"
        case .bulk: "bulk"
        }
    }
    static func engineTier(forRunID id: String) -> RunTier {
        switch id {
        case "topup": .midweek
        case "weekly": .weekly
        default: .bulk
        }
    }

    private func projectShopping() {
        guard let context, let weekEnd = weekDates.last,
              let horizon = Calendar.current.date(byAdding: .day, value: 1, to: weekEnd)
        else { runs = []; guaranteeLine = "shopping is on pause — engine offline"; return }

        let now = Date()
        let today = WeekPlan.dayAnchor(for: now)
        let entries = (try? ShoppingExplosion.entries(from: today, to: horizon, in: context)) ?? []
        rawNameByRunItem = [:]

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

        struct Bucket {
            var items: [ShoppingItem] = []
            var protects: [String] = []
            var seen: Set<String> = []
        }
        var buckets: [RunTier: Bucket] = [:]
        for entry in entries {
            guard let title = entry.meal?.title else { continue }
            for line in ShoppingExplosion.explode([entry]) {
                if purchasedCovers(line.ingredientName.lowercased(),
                                   mealDay: WeekPlan.dayAnchor(for: entry.date),
                                   perishability: line.perishability) { continue }
                guard case .routed(let index) = RunRouting.route(
                    perishability: line.perishability,
                    neededBy: entry.date,
                    preferredTier: line.preferredRunTier,
                    runs: candidateRuns.map { ($0.tier, $0.plannedDate) },
                    now: now) else { continue }   // violations surface via the guarantee
                let tier = candidateRuns[index].tier
                var bucket = buckets[tier] ?? Bucket()
                let display = RunRouting.exportText(for: line)
                if bucket.seen.insert(line.ingredientName.lowercased()).inserted {
                    bucket.items.append(ShoppingItem(
                        name: display,
                        category: Self.category(for: line.perishability)))
                    rawNameByRunItem["\(Self.runID(for: tier))|\(display)"] = line.ingredientName
                }
                if !bucket.protects.contains(title) { bucket.protects.append(title) }
                buckets[tier] = bucket
            }
        }

        // The guarantee, from their check: the proposed trio + every DONE run
        // (purchases cover inside their windows).
        let result = GuaranteeCheck.check(
            entries: entries,
            runs: candidateRuns.map {
                GuaranteeCheck.RunSnapshot(tier: $0.tier, plannedDate: $0.plannedDate,
                                           status: .confirmed)
            } + doneSnapshots,
            now: now)

        // A violation's missing items ride the top-up card (GT-2's addMiniRun
        // proposal, made concrete) and flag it — honestly, never red.
        var atRisk: String? = nil
        if let violation = result.violations.first {
            var topUp = buckets[.midweek] ?? Bucket()
            for missing in result.violations.flatMap(\.missingItems)
            where topUp.seen.insert(missing.lowercased()).inserted {
                topUp.items.append(ShoppingItem(name: missing, category: "top-up"))
            }
            if !topUp.protects.contains(violation.mealTitle) {
                topUp.protects.append(violation.mealTitle)
            }
            buckets[.midweek] = topUp
            let count = violation.missingItems.count
            atRisk = "\(violation.mealTitle) needs \(count) item\(count == 1 ? "" : "s") — on the top-up"
        }

        var projected: [ShoppingRun] = []
        if let bucket = buckets[.midweek], !bucket.items.isEmpty {
            projected.append(ShoppingRun(
                id: "topup", title: "Tonight top-up", tier: .tonightTopUp,
                items: bucket.items,
                protects: "protects \(bucket.protects.joined(separator: " + "))",
                atRisk: atRisk))
        }
        if let bucket = buckets[.weekly], !bucket.items.isEmpty {
            let day = Self.weekday(of: candidateRuns[1].plannedDate).long
            projected.append(ShoppingRun(
                id: "weekly", title: "\(day) weekly", tier: .weekly,
                items: bucket.items,
                protects: "covers \(bucket.protects.joined(separator: " + "))"))
        }
        if let bucket = buckets[.bulk], !bucket.items.isEmpty {
            let day = Self.weekday(of: candidateRuns[2].plannedDate).long
            projected.append(ShoppingRun(
                id: "bulk", title: "\(day) bulk", tier: .bulk,
                items: bucket.items,
                protects: "covers \(bucket.protects.joined(separator: " + "))"))
        }

        // Ria's own items ride their chosen run; a run that exists only
        // because of her additions still gets a card. B-4.
        for manual in manualItems {
            let item = ShoppingItem(name: manual.name, category: "yours")
            rawNameByRunItem["\(manual.runID)|\(manual.name)"] = manual.name
            if let index = projected.firstIndex(where: { $0.id == manual.runID }) {
                projected[index].items.append(item)
            } else {
                let (title, tier): (String, ShoppingRun.Tier) = switch manual.runID {
                case "topup": ("Tonight top-up", .tonightTopUp)
                case "weekly": ("\(Self.weekday(of: candidateRuns[1].plannedDate).long) weekly", .weekly)
                default: ("\(Self.weekday(of: candidateRuns[2].plannedDate).long) bulk", .bulk)
                }
                projected.append(ShoppingRun(id: manual.runID, title: title,
                                             tier: tier, items: [item],
                                             protects: "your additions"))
            }
        }
        let order = ["topup": 0, "weekly": 1, "bulk": 2]
        projected.sort { order[$0.id, default: 3] < order[$1.id, default: 3] }
        runs = projected

        if let violation = result.violations.first {
            let count = violation.missingItems.count
            // D-48: state the mechanic (the items ARE on the top-up card),
            // never minimize the errand ("a quick run" was judging the run).
            guaranteeLine = count == 1
                ? "\(violation.mealTitle) needs 1 item — it's on the top-up"
                : "\(violation.mealTitle) needs \(count) items — they're on the top-up"
        } else if entries.isEmpty {
            guaranteeLine = "no dinners planned yet — nothing to buy ✓"
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

    // MARK: - Shopping interactions (B-4)

    func isChecked(_ runID: String, _ itemName: String) -> Bool {
        checkedItems.contains("\(runID)|\(itemName)")
    }

    func toggleChecked(_ runID: String, _ itemName: String) {
        checkedItems.formSymmetricDifference(["\(runID)|\(itemName)"])
        scheduleSave()
    }

    func addManualItem(_ name: String, toRun runID: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        manualItems.append(ManualShoppingItem(name: trimmed, runID: runID))
        projectAll()
        scheduleSave()
    }

    func removeManualItem(named name: String, runID: String) {
        manualItems.removeAll { $0.runID == runID && $0.name == name }
        checkedItems.remove("\(runID)|\(name)")
        projectAll()
        scheduleSave()
    }

    func isManual(_ runID: String, _ itemName: String) -> Bool {
        manualItems.contains { $0.runID == runID && $0.name == itemName }
    }

    /// Finishing a run is the engine-true moment: a DONE ShoppingRun with a
    /// PurchaseRecord per checked line lands in the store, the guarantee
    /// recomputes over the new coverage window, and bought lines leave the
    /// remaining lists. Unchecked lines simply stay for a later run.
    func completeRun(_ runID: String) {
        guard let context,
              let run = runs.first(where: { $0.id == runID }) else { return }
        let checkedNames = run.items.map(\.name).filter { isChecked(runID, $0) }
        guard !checkedNames.isEmpty else { return }

        let now = Date()
        let engineRun = MoodyEngine.ShoppingRun(
            tier: Self.engineTier(forRunID: runID), plannedDate: now, status: .done)
        context.insert(engineRun)
        for display in checkedNames {
            let raw = rawNameByRunItem["\(runID)|\(display)"] ?? display
            context.insert(PurchaseRecord(
                itemName: raw, purchasedAt: now,
                ingredient: engineIngredients.first {
                    $0.name.compare(raw, options: .caseInsensitive) == .orderedSame
                },
                sourceRun: engineRun))
        }
        // Bought manual items leave the list; unchecked ones stay put.
        manualItems.removeAll { $0.runID == runID && checkedNames.contains($0.name) }
        checkedItems = checkedItems.filter { !$0.hasPrefix("\(runID)|") }
        saveAndReproject()
    }

    // MARK: - Persistence (App Group snapshot: widget contract + local state)

    private var saveTask: Task<Void, Never>?
    private var suppressSaves = false

    private func scheduleSaveUnlessProjecting() {
        guard !isProjecting else { return }
        scheduleSave()
    }

    /// Coalesces into one write ~0.5s after the last change. The snapshot is
    /// sourced from the projections, so widgets/Live Activity keep working
    /// exactly as before (P2 moves them onto richer projections).
    private func scheduleSave() {
        guard !suppressSaves else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }
            Persistence.save(MoodySnapshot(week: week, streak: streak, tank: tank,
                                           runs: runs, thread: thread,
                                           sassLevel: sassLevel, savedAt: Date(),
                                           checkedItems: checkedItems,
                                           manualItems: manualItems))
            syncCalendarIfEnabled()   // B-6: the device calendar follows the plan
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
        checkedItems = snapshot.checkedItems
        manualItems = snapshot.manualItems
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
