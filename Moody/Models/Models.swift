import SwiftUI

// Domain models — shape follows README §State Management (sketch).
// Persisted types (Meal, DayPlan, Weekday, Streak, Tank, ShoppingItem,
// ShoppingRun, ThreadMessage) are Codable for the App Group snapshot
// (Data/Persistence.swift). PaletteSlot/Persona/HouseholdMember stay
// non-persisted — static cast/config.

// MARK: - Household

enum DietaryNeed {
    case celiac          // HARD constraint: every meal must show "Caddie GF ✓"
    case safeFoodsOnly   // Elsie: her safe option must exist for tonight
    case doubleVolume    // Chad: ×2 batch
}

struct HouseholdMember: Identifiable {
    let id: String
    var name: String
    var need: DietaryNeed?
    var blobColor: Color
    var blobVariant: Int
    var cookNight: Weekday?   // Chad cooks Wednesdays in the demo
}

// MARK: - Personas (fictional cast — text like real people, never lecture)

enum NoticerDuty { case slump, comeback }

struct Persona: Identifiable {
    let id: String
    var name: String
    var role: String          // "snarky best friend", "chef", "ND whip-smart"
    var slot: PaletteSlot     // name color in thread
    var blobVariant: Int
    var duty: NoticerDuty
}

// MARK: - Meals & plan

struct Meal: Identifiable, Equatable, Codable {
    let id: String             // stable slug derived from the engine meal's title
    var name: String
    var effort: Int            // 1–3, shown as ●○○ (engine noCook|assembly→1, simple→2, involved→3)
    var isFallback: Bool = false
    /// Short label for week magnets ("Tue tacos") — ids are internal and can
    /// read badly on screen ("Tue gfmac"), so surfaces use this instead.
    var keyword: String = ""
    var displayKeyword: String { keyword.isEmpty ? id : keyword }
    /// Safety badges are derived guarantees, not decorations. D-35: derived
    /// per ATTENDING member from data (GF verdict, MemberMealScore.isSafeFood,
    /// appetiteBase) at projection time — no member is ever hardcoded. Cold
    /// start legitimately has no safe-food badges (zero scores exist, PT-1).
    var badges: [SafetyBadgeInfo] = []
}

struct SafetyBadgeInfo: Identifiable, Equatable {
    var text: String
    var slot: PaletteSlot
    var id: String { text }
}

// MARK: - Meal library (B-1: the full-truth browse/detail projection —
// engine identity, engine vocabulary; the card-sized `Meal` stays for widgets)

struct LibraryMeal: Identifiable, Equatable {
    let id: UUID                  // engine identity — mutations round-trip on it
    var name: String
    var notes: String
    var effortLabel: String       // engine terms: no cook / assembly / simple / involved
    var effortDots: Int           // 1–3 card mapping
    var slots: [String]
    var tags: [String]
    var isAllTimer: Bool
    var isEatingOut: Bool
    var requiresCalmDay: Bool
    var rotation: String          // active / resting / retired
    var gfLabel: String           // "GF ✓" / "GF — check" / "not GF"
    var gfSafe: Bool
    var badges: [SafetyBadgeInfo]
    var recipes: [LibraryRecipe]
    var directItems: [LibraryRecipeItem]
    var isRetired: Bool { rotation == "retired" }
    var hasComposition: Bool { !recipes.isEmpty || !directItems.isEmpty }
}

struct LibraryRecipe: Identifiable, Equatable {
    let id: UUID
    var title: String
    var kindLabel: String         // "loose" / "precise"
    var items: [LibraryRecipeItem]
    var steps: [String]
    // FR-1 (D-44): the band this recipe wears + where it came from.
    var bandRaw: String = "notCheckedYet"
    var bandSourceRaw: String = "derived"
    var standardModification: String = ""
    /// Where it came from — a URL or a cookbook title/page. "" = none on file.
    var source: String = ""
}

/// Navigation-path value for pushing the read-only recipe screen — a
/// distinct type from the plain `UUID` meals already push with, so both
/// can live on the same `NavigationStack`.
struct RecipeRoute: Hashable, Identifiable {
    var id: UUID
}

/// D-44 band → surface language. Yellow is the ceiling (law 4); unsafe is
/// words-with-weight, never red.
enum BandStyle {
    static func label(_ raw: String) -> String {
        switch raw {
        case "safe": "GF safe"
        case "awaitingSubstitution": "awaiting sub"
        case "unsafe": "unsafe for GF"
        default: "not checked yet"
        }
    }
    static func isGreen(_ raw: String) -> Bool { raw == "safe" }
}

/// First-class recipe browsing (Ria 2026-07-13: "a meal is a collection of
/// recipes") — every recipe in the box, attached or standalone.
struct RecipeSummary: Identifiable, Equatable {
    let id: UUID
    var title: String
    var kindLabel: String
    var itemCount: Int
    var usedIn: [String]          // meal names; empty = standalone
}

struct LibraryRecipeItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var amountText: String        // "2 cups" — empty when amount-less (D-36 valid)
    var gfLabel: String           // "GF ✓" / "not GF" / "check label"
    var gfSafe: Bool
    /// Raw amount/unit, separate from `amountText`'s combined display
    /// string — an edit form needs these apart to prefill its own fields.
    var rawAmount: Double?
    var rawUnit: String = ""
}

// MARK: - Plan calendar (NB: any date from today forward — the real planner)

struct PlanDay: Identifiable, Equatable {
    let id: Date                  // day anchor
    var weekdayLabel: String      // "Mon"
    var dayLabel: String          // "13"
    var monthLabel: String?       // "Jul" on the 1st and on today's row
    var isToday: Bool
    var dinner: PlanSlotInfo?
    var lunch: PlanSlotInfo?
}

/// Month-grid lookup: what's on a given day (any date, not just the window).
struct PlanCell: Equatable {
    var dinner: PlanSlotInfo?
    var lunch: PlanSlotInfo?
}

struct PlanSlotInfo: Equatable {
    var mealID: UUID?             // nil = D-37 needs-refill flag state
    var name: String
    var pinned: Bool
    var needsRefill: Bool
    var gfBadge: String?          // truthful chip when a celiac member is home
    var gfSafe: Bool
}

// MARK: - Settings (B-5: household/profile doors)

struct SettingsMember: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isAdult: Bool
    var isGFHard: Bool          // the celiac hard requirement — deliberate weight
    var appetiteBase: Double    // servings multiplier
}

struct SettingsStaple: Identifiable, Equatable {
    let id: UUID
    var name: String
    var minOnHand: String
}

/// D-58: a member's restriction record, surfaced. Levels wear Ria's words.
struct MemberRule: Identifiable, Equatable {
    let id: UUID
    let memberID: UUID
    var memberName: String
    var directionLabel: String   // "never" / "infrequent" / "increased"
    var subject: String          // category display name (legacy: subject text)
    var reason: String
    var windowText: String?      // "≤1× per 7 days"
    var isGluten: Bool           // removal carries deliberate weight
}

/// Form state for create/edit — plain types only (views never see engine enums).
struct MealDraft: Equatable {
    var title = ""
    var notes = ""
    var effortRaw = 2             // EffortLevel rawValue; 2 = simple
    var slots: Set<String> = ["dinner"]
    var tagsText = ""
    var isAllTimer = false
    var isEatingOut = false
    var requiresCalmDay = false
}

/// A recipe MoodyBrain parsed from pasted text (typed or photographed),
/// before she's reviewed it — nothing saves until she taps Add. GF band
/// starts notCheckedYet, same as any hand-typed recipe (M3-2 parse-only
/// slice; the full D-44 assessment is a separate pass) — `substituteSuggestion`
/// is a deterministic word-list nudge (`GlutenCarrierCheck`), never applied
/// on its own.
struct RecipePastePreview: Equatable {
    struct Item: Identifiable, Equatable {
        var id = UUID()
        var name: String
        var amount: Double?
        var unit: String?
        var substituteSuggestion: String?
    }
    var title: String
    var items: [Item]
    var steps: [String]
    /// Where it came from — she types this in on the paste screen itself;
    /// MoodyBrain never infers it. "" = none given.
    var source: String = ""
}

// Codable via the slot's stable id ("her-1"…): PaletteSlot itself is design
// system (not persisted); decode re-binds to the live palette so badge tints
// follow palette swaps (law 6). Unknown ids degrade to green, never crash.
extension SafetyBadgeInfo: Codable {
    private enum CodingKeys: String, CodingKey { case text, slotID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        let slotID = try c.decode(String.self, forKey: .slotID)
        slot = Palette.slots.first { $0.id == slotID } ?? Palette.green
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(text, forKey: .text)
        try c.encode(slot.id, forKey: .slotID)
    }
}

enum Weekday: Int, CaseIterable, Identifiable, Codable {
    case mon, tue, wed, thu, fri, sat, sun
    var id: Int { rawValue }
    var short: String { ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][rawValue] }
    var long: String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][rawValue]
    }
}

enum DayKind: String, Equatable, Codable {
    case done          // cooked, gets ✓
    case tonight       // the anchor — yellow magnet, current
    case kidCook       // e.g. "Wed: CHAD 🍜"
    case joyCook       // e.g. "Sat: JOY 🍲"
    case planned       // future, meal committed
    case open          // dashed "?" — offer "deal me 3"
    case rest          // planned skip: streak intact, zero shame
}

struct DayPlan: Identifiable, Codable {
    var day: Weekday
    var kind: DayKind
    var meal: Meal?
    var locked: Bool = false
    var attendance: String = "everyone home"
    var id: Int { day.rawValue }
}

// MARK: - Streak (law 4: the string "0" must be unreachable)

struct Streak: Codable {
    var current: Int
    var personalBest: Int
    var freezeTokens: Int
    var state: StreakState

    enum StreakState: String, Codable { case active, rebuilding, returnPending }

    /// Headline number — never zero. Day counts start at 1 ("day 1 of the
    /// rebuild" begins the moment a streak breaks).
    var displayDay: String { "day \(max(1, current))" }

    /// PB fragments clamp the same way displayDay does: a brand-new user has
    /// personalBest 0 and the string "PB 0" must be as unreachable as "day 0".
    private var pbFragment: String? { personalBest >= 1 ? "PB \(personalBest)" : nil }

    /// Sticker copy ("PB: 23") — nil when there is no PB yet; hide the sticker.
    var pbBadge: String? { personalBest >= 1 ? "PB: \(personalBest)" : nil }

    var subline: String {
        switch state {
        case .active: return pbFragment ?? "first streak in progress"
        case .rebuilding: return pbFragment.map { "\($0) · the rebuild" } ?? "the rebuild starts now"
        case .returnPending: return "THE RETURN — 1 dinner away"
        }
    }
}

// MARK: - Shopping

struct ShoppingItem: Identifiable, Codable {
    var id = UUID()   // stored var (not `let = …`) so persisted ids survive relaunch
    var name: String
    var category: String          // row detail ("always stocked"); "" = none
    var low: Bool = false
    var deadline: String? = nil   // freshness chip ("by Wed") — SHOP-4
}

/// SHOP-4: the list the user sees — one flat checklist grouped the way a
/// store is walked. Run math stays internal to the engine projection.
struct ShoppingSection: Identifiable, Codable {
    let id: String                // StoreSection rawValue, or "extras"
    var title: String             // "Produce" … "Anything else"
    var items: [ShoppingItem]
}

/// Legacy shape (pre-SHOP-4 three-run cards) — still part of the snapshot
/// contract so older `snapshot.json` files keep decoding; written empty now.
struct ShoppingRun: Identifiable, Codable {
    let id: String
    var title: String
    var tier: Tier
    var items: [ShoppingItem]
    var protects: String          // the meals this run keeps safe
    var atRisk: String? = nil

    enum Tier: String, Codable { case tonightTopUp, weekly, bulk }
}

// MARK: - Thread

struct ThreadMessage: Identifiable, Codable {
    var id = UUID()   // stored var (not `let = …`) so persisted ids survive relaunch
    var author: Author
    var text: String
    var kind: Kind = .normal
    var tapbacks: [String] = []   // e.g. ["♥ 2", "★ Chuck"]

    enum Author: Equatable, Codable {
        case persona(String)      // persona id
        case family(String)       // member id
        case ria
    }
    enum Kind: String, Codable { case normal, moment, aside }
}

// MARK: - Energy

enum Tank: String, CaseIterable, Identifiable, Codable {
    case fumes = "Fumes", steady = "Steady", full = "Full"
    var id: String { rawValue }
}
