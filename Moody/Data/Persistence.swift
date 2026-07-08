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
}

enum Persistence {
    /// Bump when the snapshot shape changes incompatibly.
    static let schemaVersion = 1
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
