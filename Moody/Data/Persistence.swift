import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// App Group JSON snapshot — the shared-state contract between the app and
// MoodyWidgets. Rules: never crash, never block launch. A missing/corrupt
// file just means demo seeds (AppState's defaults) take over.

/// Everything the app persists (and widgets read). Cast/config (personas,
/// household, palette, candidate pool) is static and deliberately absent.
struct MoodySnapshot: Codable {
    var schemaVersion: Int = Persistence.schemaVersion
    var week: [DayPlan]
    var streak: Streak
    var tank: Tank
    var runs: [ShoppingRun]
    var thread: [ThreadMessage]
    var sassLevel: Double
    var savedAt: Date
    // B-4/SHOP-3 additions — decodeIfPresent below keeps older snapshots
    // loading (a missing key must never cost streak/thread state). Widgets
    // ignore all three.
    var checkedItems: Set<String> = []          // "runID|itemName"
    var manualItems: [ManualShoppingItem] = []
    var managedReminderTitles: Set<String> = [] // titles the Reminders mirror owns

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, week, streak, tank, runs, thread, sassLevel,
             savedAt, checkedItems, manualItems, managedReminderTitles
    }

    init(schemaVersion: Int = Persistence.schemaVersion, week: [DayPlan],
         streak: Streak, tank: Tank, runs: [ShoppingRun],
         thread: [ThreadMessage], sassLevel: Double, savedAt: Date,
         checkedItems: Set<String> = [], manualItems: [ManualShoppingItem] = [],
         managedReminderTitles: Set<String> = []) {
        self.schemaVersion = schemaVersion
        self.week = week
        self.streak = streak
        self.tank = tank
        self.runs = runs
        self.thread = thread
        self.sassLevel = sassLevel
        self.savedAt = savedAt
        self.checkedItems = checkedItems
        self.manualItems = manualItems
        self.managedReminderTitles = managedReminderTitles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        week = try c.decode([DayPlan].self, forKey: .week)
        streak = try c.decode(Streak.self, forKey: .streak)
        tank = try c.decode(Tank.self, forKey: .tank)
        runs = try c.decode([ShoppingRun].self, forKey: .runs)
        thread = try c.decode([ThreadMessage].self, forKey: .thread)
        sassLevel = try c.decode(Double.self, forKey: .sassLevel)
        savedAt = try c.decode(Date.self, forKey: .savedAt)
        checkedItems = try c.decodeIfPresent(Set<String>.self, forKey: .checkedItems) ?? []
        manualItems = try c.decodeIfPresent([ManualShoppingItem].self, forKey: .manualItems) ?? []
        managedReminderTitles = try c.decodeIfPresent(
            Set<String>.self, forKey: .managedReminderTitles) ?? []
    }
}

/// An item Ria added herself — not meal-driven, rides the chosen run's list
/// and becomes a real PurchaseRecord if checked when the run completes.
struct ManualShoppingItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var runID: String            // presentation run id: topup / weekly / bulk
}

enum Persistence {
    /// Bump when the snapshot shape changes incompatibly.
    /// v2 (unify): Meal carries derived per-attendee badges (D-35); week/runs
    /// are projections of the SwiftData engine store, not sources of truth.
    /// v1 snapshots fail decode on the new Meal shape and are discarded below
    /// (fresh projections rebuild everything except streak/thread/tank/sass —
    /// acceptable one-time loss at the graft).
    static let schemaVersion = 2
    static let appGroupID = "group.com.mariayarley.Moody"

    /// `snapshot.json` in the App Group container; Documents fallback keeps
    /// persistence working when the group container is nil (simulator/dev
    /// before entitlements are live).
    static var fileURL: URL {
        let fm = FileManager.default
        let dir = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("snapshot.json")
    }

    static func load() -> MoodySnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }   // first launch
        do {
            let snapshot = try decoder.decode(MoodySnapshot.self, from: data)
            // Written by a newer schema: skip (don't destroy) — the next save
            // overwrites it anyway.
            guard snapshot.schemaVersion <= schemaVersion else { return nil }
            return snapshot
        } catch {
            try? FileManager.default.removeItem(at: fileURL)   // corrupt → fresh seeds
            return nil
        }
    }

    static func save(_ snapshot: MoodySnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()   // widgets re-read the snapshot
        #endif
    }

    /// Deletes the snapshot (resetToDemo / MOODY_RESET=1 debug hook).
    static func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // ISO-8601 dates are part of the contract — the widget decoder must match.
    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
