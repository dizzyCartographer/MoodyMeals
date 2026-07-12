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

    @Published var week: [DayPlan] = [] {
        didSet {
            guard !isProjecting else { return }
            reconcileWeekEdits(old: oldValue)   // direct view edits → engine
            scheduleSave()
        }
    }

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

    private(set) var alwaysStocked: [ShoppingItem] = []

    // MARK: Thread (scripted v1 — swap MessageBank for a live generator later)

    @Published var thread: [ThreadMessage] = DemoSeed.thread { didSet { scheduleSaveUnlessProjecting() } }

    /// Today's noticer for the home sticky (Hannah/Cat alternate slump duty;
    /// Julie owns comebacks). Scripted in v1.
    var homeNote: (author: Persona, text: String, more: String) {
        (persona("hannah"), "\u{201C}fixings in the fridge. you literally just chop.\u{201D}", "+2 more · open thread →")
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
    }

    private func refreshEngineCaches() {
        guard let context else { return }
        engineMembers = (try? context.fetch(FetchDescriptor<FamilyMember>(
            sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)]))) ?? []
        engineMeals = (try? context.fetch(FetchDescriptor<MoodyEngine.Meal>(
            sortBy: [SortDescriptor(\.title)]))) ?? []
        engineStaples = (try? context.fetch(FetchDescriptor<StapleItem>(
            sortBy: [SortDescriptor(\.name)]))) ?? []

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

        // Fallback: staple-cookable if any, else lowest-effort verified-GF.
        let stapleNames = Set(engineStaples.map { $0.name.lowercased() })
        let pool = engineMeals.filter { !$0.isEatingOut }
        let fallback = pool.first(where: { meal in
            let ingredients = Self.allIngredients(of: meal)
            return !ingredients.isEmpty
                && ingredients.allSatisfy { stapleNames.contains($0.name.lowercased()) }
        }) ?? pool
            .filter { Self.gfVerdict($0) == .verified }
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
        if member.hardRequirements.contains(.glutenFree) { return .celiac }
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

    /// Tri-state per HC-6: verified (their GlutenSafety verdict) /
    /// contains gluten (an ingredient is explicitly not GF) / unverified.
    private enum GFVerdict { case verified, containsGluten, unverified }

    private static func gfVerdict(_ meal: MoodyEngine.Meal) -> GFVerdict {
        if meal.isGFVerifiedForCeliac { return .verified }
        if allIngredients(of: meal).contains(where: { $0.isGlutenFreeVerified == false }) {
            return .containsGluten
        }
        return .unverified
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
            if member.hardRequirements.contains(.glutenFree) {
                switch Self.gfVerdict(meal) {
                case .verified:
                    out.append(SafetyBadgeInfo(text: "\(member.name) GF ✓", slot: Palette.green))
                case .unverified:   // yellow, never red — check the label
                    out.append(SafetyBadgeInfo(text: "\(member.name) GF — check", slot: Palette.yellow))
                case .containsGluten:   // excluded from decide/swap entirely;
                    // manual surfaces still need the honest read (no red).
                    out.append(SafetyBadgeInfo(text: "\(member.name) — not GF", slot: Palette.yellow))
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
    /// eating out (D-7), never retired, celiac attendee ⇒ GF-VERIFIED only
    /// (contains-gluten AND unverified both excluded — no HC-5 in auto paths),
    /// per-member "not today" windows honored.
    private func decidePool() -> [MoodyEngine.Meal] {
        let now = Date()
        let celiacAttending = engineMembers.contains { $0.hardRequirements.contains(.glutenFree) }
        return engineMeals.filter { meal in
            guard !meal.isEatingOut,
                  meal.slots.contains(.dinner),
                  meal.rotationState != .retired else { return false }
            if celiacAttending, Self.gfVerdict(meal) != .verified { return false }
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

    /// Direct view edits on `week` (WeekPlanView writes `week[i].meal` /
    /// `.locked` in place) flow through to the engine, then the canonical
    /// projection wins. Locks on entry-less days stay view-local (there is
    /// nothing to lock yet) until the next projection.
    private func reconcileWeekEdits(old: [DayPlan]) {
        guard let context else { return }
        var engineChanged = false
        for plan in week {
            guard let before = old.first(where: { $0.day == plan.day }),
                  let date = weekDates.first(where: { Self.weekday(of: $0) == plan.day })
            else { continue }
            if plan.meal?.id != before.meal?.id, let slug = plan.meal?.id,
               let engineMeal = engineMeal(forSlug: slug) {
                _ = try? WeekPlan.assign(engineMeal, on: date, slot: .dinner,
                                         attendees: engineMembers, in: context)
                engineChanged = true
            }
            if plan.locked != before.locked,
               let entry = try? WeekPlan.entry(on: date, slot: .dinner, in: context) {
                try? WeekPlan.setLocked(plan.locked, entry: entry, in: context)
                engineChanged = true
            }
        }
        if engineChanged { projectAll() }
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

    private func projectShopping() {
        guard let context, let weekEnd = weekDates.last,
              let horizon = Calendar.current.date(byAdding: .day, value: 1, to: weekEnd)
        else { runs = []; guaranteeLine = "shopping is on pause — engine offline"; return }

        let now = Date()
        let today = WeekPlan.dayAnchor(for: now)
        let entries = (try? ShoppingExplosion.entries(from: today, to: horizon, in: context)) ?? []

        // Three proposed runs: top-up today, weekly Wednesday, bulk Saturday
        // (run cadence is a placeholder until real run scheduling lands —
        // routing/guarantee treat them as this week's shopping plan).
        let candidateRuns: [(tier: RunTier, plannedDate: Date)] = [
            (.midweek, today),
            (.weekly, Self.nextDate(calendarWeekday: 4, onOrAfter: today)),
            (.bulk, Self.nextDate(calendarWeekday: 7, onOrAfter: today)),
        ]

        struct Bucket {
            var items: [ShoppingItem] = []
            var protects: [String] = []
            var seen: Set<String> = []
        }
        var buckets: [RunTier: Bucket] = [:]
        for entry in entries {
            guard let title = entry.meal?.title else { continue }
            for line in ShoppingExplosion.explode([entry]) {
                guard case .routed(let index) = RunRouting.route(
                    perishability: line.perishability,
                    neededBy: entry.date,
                    preferredTier: line.preferredRunTier,
                    runs: candidateRuns.map { ($0.tier, $0.plannedDate) },
                    now: now) else { continue }   // violations surface via the guarantee
                let tier = candidateRuns[index].tier
                var bucket = buckets[tier] ?? Bucket()
                if bucket.seen.insert(line.ingredientName.lowercased()).inserted {
                    bucket.items.append(ShoppingItem(
                        name: RunRouting.exportText(for: line),
                        category: Self.category(for: line.perishability)))
                }
                if !bucket.protects.contains(title) { bucket.protects.append(title) }
                buckets[tier] = bucket
            }
        }

        // The guarantee, from their check. The proposed trio doubles as the
        // horizon: "covered thru X" = shop per these runs and every planned
        // dinner through X is cookable.
        let result = GuaranteeCheck.check(
            entries: entries,
            runs: candidateRuns.map {
                GuaranteeCheck.RunSnapshot(tier: $0.tier, plannedDate: $0.plannedDate,
                                           status: .confirmed)
            },
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
                                           sassLevel: sassLevel, savedAt: Date()))
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
                      text: "fixings in the fridge. you literally just chop.",
                      kind: .moment, tapbacks: ["♥ 2", "★ Chuck"]),
        ThreadMessage(author: .persona("cat"),
                      text: "warm the tortillas in a dry pan, 30 sec a side. game changer, I promise.",
                      kind: .aside),
        ThreadMessage(author: .persona("julie"),
                      text: "day 2 of the rebuild!! task re-initiation costs more dopamine than the task. you paid it. respect."),
        ThreadMessage(author: .family("chuck"),
                      text: "I can do pickup if the lime situation is dire"),
        ThreadMessage(author: .persona("hannah"),
                      text: "the lime situation is always dire, Chuck. it's called being a household."),
    ]
}
