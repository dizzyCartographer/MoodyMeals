import SwiftUI

// Domain models — shape follows README §State Management (sketch).

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

struct Meal: Identifiable, Equatable {
    let id: String
    var name: String
    var effort: Int            // 1–3, shown as ●○○
    var isFallback: Bool = false
    /// Short label for week magnets ("Tue tacos") — ids are internal and can
    /// read badly on screen ("Tue gfmac"), so surfaces use this instead.
    var keyword: String = ""
    var displayKeyword: String { keyword.isEmpty ? id : keyword }
    /// Safety badges are derived guarantees, not decorations. Every planned
    /// meal must carry all three for the demo household.
    var badges: [SafetyBadgeInfo] {
        [SafetyBadgeInfo(text: "Caddie GF ✓", slot: Palette.green),
         SafetyBadgeInfo(text: "Elsie plain ✓", slot: Palette.blue),
         SafetyBadgeInfo(text: "Chad ×2 ✓", slot: Palette.yellow)]
    }
}

struct SafetyBadgeInfo: Identifiable, Equatable {
    var text: String
    var slot: PaletteSlot
    var id: String { text }
}

enum Weekday: Int, CaseIterable, Identifiable {
    case mon, tue, wed, thu, fri, sat, sun
    var id: Int { rawValue }
    var short: String { ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][rawValue] }
    var long: String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][rawValue]
    }
}

enum DayKind: Equatable {
    case done          // cooked, gets ✓
    case tonight       // the anchor — yellow magnet, current
    case kidCook       // e.g. "Wed: CHAD 🍜"
    case joyCook       // e.g. "Sat: JOY 🍲"
    case planned       // future, meal committed
    case open          // dashed "?" — offer "deal me 3"
    case rest          // planned skip: streak intact, zero shame
}

struct DayPlan: Identifiable {
    var day: Weekday
    var kind: DayKind
    var meal: Meal?
    var locked: Bool = false
    var attendance: String = "everyone home"
    var id: Int { day.rawValue }
}

// MARK: - Streak (law 4: the string "0" must be unreachable)

struct Streak {
    var current: Int
    var personalBest: Int
    var freezeTokens: Int
    var state: StreakState

    enum StreakState { case active, rebuilding, returnPending }

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

struct ShoppingItem: Identifiable {
    let id = UUID()
    var name: String
    var category: String
    var low: Bool = false
}

struct ShoppingRun: Identifiable {
    let id: String
    var title: String
    var tier: Tier
    var items: [ShoppingItem]
    var protects: String          // the meals this run keeps safe
    var atRisk: String? = nil

    enum Tier { case tonightTopUp, weekly, bulk }
}

// MARK: - Thread

struct ThreadMessage: Identifiable {
    let id = UUID()
    var author: Author
    var text: String
    var kind: Kind = .normal
    var tapbacks: [String] = []   // e.g. ["♥ 2", "★ Chuck"]

    enum Author: Equatable {
        case persona(String)      // persona id
        case family(String)       // member id
        case ria
    }
    enum Kind { case normal, moment, aside }
}

// MARK: - Energy

enum Tank: String, CaseIterable, Identifiable {
    case fumes = "Fumes", steady = "Steady", full = "Full"
    var id: String { rawValue }
}
