import SwiftUI

// Central observable state + demo data matching the mockups (Taco Tuesday,
// day 2 of the rebuild, PB 23, covered thru Friday). Personas are scripted
// in v1 — swap MessageBank for a live generator later without touching views.
//
// Persistence: demo seeds below are the first-launch state; a saved
// MoodySnapshot overlays them on init, and every mutation (didSet on the
// persisted @Published vars — direct view edits included) schedules a
// debounced save. See Data/Persistence.swift for the snapshot contract.

@MainActor
final class AppState: ObservableObject {

    init() {
        // Debug hook: MOODY_RESET=1 wipes the snapshot and launches from seeds.
        if ProcessInfo.processInfo.environment["MOODY_RESET"] == "1" {
            resetToDemo()
        } else if let snapshot = Persistence.load() {
            apply(snapshot)   // overlay persisted state onto the demo defaults
        }
    }

    // MARK: Cast

    let household: [HouseholdMember] = [
        HouseholdMember(id: "ria", name: "Ria", need: nil,
                        blobColor: Palette.pink.color, blobVariant: 0, cookNight: nil),
        HouseholdMember(id: "chuck", name: "Chuck", need: nil,
                        blobColor: Palette.purple.color, blobVariant: 1, cookNight: nil),
        HouseholdMember(id: "caddie", name: "Caddie", need: .celiac,
                        blobColor: Palette.green.color, blobVariant: 2, cookNight: nil),
        HouseholdMember(id: "elsie", name: "Elsie", need: .safeFoodsOnly,
                        blobColor: Palette.blue.color, blobVariant: 3, cookNight: nil),
        HouseholdMember(id: "chad", name: "Chad", need: .doubleVolume,
                        blobColor: Palette.yellow.color, blobVariant: 4, cookNight: .wed),
    ]

    let personas: [Persona] = [
        Persona(id: "hannah", name: "Hannah", role: "snarky best friend",
                slot: Palette.pink, blobVariant: 1, duty: .slump),
        Persona(id: "cat", name: "Cat", role: "chef · world's best aunt energy",
                slot: Palette.blue, blobVariant: 2, duty: .slump),
        Persona(id: "julie", name: "Julie", role: "ND · whip-smart",
                slot: Palette.purple, blobVariant: 3, duty: .comeback),
    ]

    // Benign fallbacks instead of force-unwraps: a typo'd id in demo/scripted
    // content should never crash the thread.
    func persona(_ id: String) -> Persona { personas.first { $0.id == id } ?? personas[0] }
    func member(_ id: String) -> HouseholdMember { household.first { $0.id == id } ?? household[0] }

    // MARK: Plan

    @Published var week: [DayPlan] = DemoSeed.week { didSet { scheduleSave() } }

    var tonight: DayPlan { week.first { $0.kind == .tonight } ?? week[1] }
    var tonightLabel: String { "TONIGHT · TACO TUESDAY" }

    // Candidate pool for decide-for-me / swap (constraint-solved in spirit:
    // everything here already satisfies the three safety guarantees).
    let candidates: [Meal] = [
        Meal(id: "fajitas", name: "Sheet-pan fajitas", effort: 2, keyword: "fajitas"),
        Meal(id: "gfmac", name: "GF mac & peas", effort: 1, keyword: "GF mac"),
        Meal(id: "bfd", name: "Breakfast for dinner", effort: 1, keyword: "brekkie"),
        Meal(id: "stirfry", name: "Chicken rice bowls", effort: 2, keyword: "bowls"),
        Meal(id: "quesadillas", name: "Cupboard quesadillas", effort: 1, isFallback: true, keyword: "quesadillas"),
    ]

    /// The fallback is always cookable from the ALWAYS-STOCKED shelf.
    var fallbackMeal: Meal { candidates.first { $0.isFallback } ?? candidates[candidates.count - 1] }

    // MARK: Energy / streak / guarantee

    @Published var tank: Tank = DemoSeed.tank { didSet { scheduleSave() } }
    @Published var streak: Streak = DemoSeed.streak { didSet { scheduleSave() } }
    @Published var sassLevel: Double = DemoSeed.sassLevel { didSet { scheduleSave() } }   // 0 mild … 10 full chaos

    var guaranteeLine: String { "groceries covered thru Friday ✓" }

    // MARK: Shopping

    @Published var runs: [ShoppingRun] = DemoSeed.runs { didSet { scheduleSave() } }

    let alwaysStocked: [ShoppingItem] = [
        ShoppingItem(name: "tortillas", category: "staple"),
        ShoppingItem(name: "cheese", category: "staple"),
        ShoppingItem(name: "black beans", category: "staple"),
        ShoppingItem(name: "rice", category: "staple"),
        ShoppingItem(name: "frozen corn", category: "staple"),
        ShoppingItem(name: "oat milk", category: "staple", low: true),
        ShoppingItem(name: "eggs", category: "staple"),
    ]

    // MARK: Thread (scripted demo — voices per README cast section)

    @Published var thread: [ThreadMessage] = DemoSeed.thread { didSet { scheduleSave() } }

    /// Today's noticer for the home sticky (Hannah/Cat alternate slump duty;
    /// Julie owns comebacks). Demo pins Hannah per the chosen mockup.
    var homeNote: (author: Persona, text: String, more: String) {
        (persona("hannah"), "\u{201C}fixings in the fridge. you literally just chop.\u{201D}", "+2 more · open thread →")
    }

    // MARK: Interactions

    /// One tap → instantly commits (no confirmation modal; undo = swap).
    func decideForMe() {
        let effortCap = tank == .fumes ? 1 : (tank == .steady ? 2 : 3)
        let pick = candidates.first { $0.effort <= effortCap && !$0.isFallback } ?? fallbackMeal
        commitTonight(pick)
    }

    /// Exactly 3 alternatives (law 2: ~3 options per choice). The pool is the
    /// 5 candidates minus tonight's meal (≥4), so 3 is guaranteed; on Fumes we
    /// sort low-effort first instead of filtering, which used to leave only 2.
    func swapOptions() -> [Meal] {
        let pool = candidates.filter { $0.id != tonight.meal?.id }
        let ranked = tank == .fumes ? pool.sorted { $0.effort < $1.effort } : pool
        return Array(ranked.prefix(3))
    }

    func commitTonight(_ meal: Meal) {
        guard let i = week.firstIndex(where: { $0.kind == .tonight }) else { return }
        week[i].meal = meal
    }

    /// Fumes re-plans tonight to lowest effort / fallback; answers persist.
    func setTank(_ t: Tank) {
        tank = t
        if t == .fumes, let current = tonight.meal, current.effort > 1 {
            commitTonight(fallbackMeal)
        }
    }

    // MARK: Persistence

    private var saveTask: Task<Void, Never>?
    private var suppressSaves = false   // apply()/resetToDemo() must not re-save

    /// Every mutation lands here via the @Published didSets above — direct
    /// view edits (week[i].locked, thread.append) included — and coalesces
    /// into one write ~0.5s after the last change.
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

    private func apply(_ snapshot: MoodySnapshot) {
        suppressSaves = true
        defer { suppressSaves = false }
        week = snapshot.week
        streak = snapshot.streak
        tank = snapshot.tank
        runs = snapshot.runs
        thread = snapshot.thread
        sassLevel = snapshot.sassLevel
    }

    /// Deletes the snapshot and restores the demo seeds. Not surfaced in UI;
    /// invoked by the MOODY_RESET=1 debug hook.
    func resetToDemo() {
        saveTask?.cancel()   // a pending save must not resurrect the file
        Persistence.reset()
        suppressSaves = true
        defer { suppressSaves = false }
        week = DemoSeed.week
        streak = DemoSeed.streak
        tank = DemoSeed.tank
        runs = DemoSeed.runs
        thread = DemoSeed.thread
        sassLevel = DemoSeed.sassLevel
    }
}

// MARK: - Demo seeds (first-launch state + resetToDemo() restore point)

enum DemoSeed {

    static let week: [DayPlan] = [
        DayPlan(day: .mon, kind: .done, meal: Meal(id: "forage", name: "Fridge forage", effort: 1)),
        DayPlan(day: .tue, kind: .tonight, meal: Meal(id: "tacos", name: "Build-your-own tacos", effort: 2)),
        DayPlan(day: .wed, kind: .kidCook, meal: Meal(id: "ramen", name: "Chad's ramen night", effort: 1)),
        DayPlan(day: .thu, kind: .planned, meal: Meal(id: "gnocchi", name: "Sheet-pan gnocchi", effort: 2)),
        DayPlan(day: .fri, kind: .planned, meal: Meal(id: "pizza", name: "GF pizza night", effort: 2)),
        DayPlan(day: .sat, kind: .joyCook, meal: Meal(id: "birria", name: "Birria (joy cook)", effort: 3)),
        DayPlan(day: .sun, kind: .open, meal: nil),
    ]

    static let tank: Tank = .steady
    static let streak = Streak(current: 2, personalBest: 23, freezeTokens: 2, state: .rebuilding)
    static let sassLevel: Double = 6

    static let runs: [ShoppingRun] = [
        ShoppingRun(id: "topup", title: "Tonight top-up", tier: .tonightTopUp,
                    items: [ShoppingItem(name: "corn tortillas (GF)", category: "grains"),
                            ShoppingItem(name: "limes", category: "produce")],
                    protects: "protects tonight's tacos + Thu gnocchi"),
        ShoppingRun(id: "weekly", title: "Wednesday weekly", tier: .weekly,
                    items: (1...12).map { i in
                        ShoppingItem(name: ["milk", "eggs", "chicken thighs", "rice", "black beans",
                                            "cheddar", "spinach", "apples", "GF pasta", "salsa",
                                            "yogurt", "carrots"][i - 1],
                                     category: ["dairy", "dairy", "meat", "grains", "pantry",
                                                "dairy", "produce", "produce", "grains", "pantry",
                                                "dairy", "produce"][i - 1])
                    },
                    protects: "covers Wed–Fri dinners + school lunches"),
        ShoppingRun(id: "costco", title: "Saturday Costco", tier: .bulk,
                    items: [ShoppingItem(name: "beef chuck (birria)", category: "meat"),
                            ShoppingItem(name: "GF flour 5lb", category: "pantry"),
                            ShoppingItem(name: "oat milk case", category: "dairy"),
                            ShoppingItem(name: "frozen fruit", category: "frozen")],
                    protects: "bulk + Saturday's joy cook",
                    atRisk: "Sat's birria depends on the Costco run"),
    ]

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
