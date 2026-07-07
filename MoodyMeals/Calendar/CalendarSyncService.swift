import Foundation
import SwiftData

// ── M1-2: PlanEntry ⇄ Moody-calendar sync ────────────────────
// The app owns its events; everything lands on the dedicated calendar
// (CAL-1), edits/deletes follow the entry (CAL-2), and denial leaves the
// app fully functional with a visible explanation (CAL-3).

@MainActor
@Observable
final class CalendarSyncService {
    private let store: CalendarStore
    private(set) var isAvailable = false
    /// CAL-3: shown in the UI whenever sync is off — never a silent failure.
    private(set) var unavailableReason: String?

    init(store: CalendarStore) {
        self.store = store
        refreshAvailability()
    }

    func refreshAvailability() {
        switch store.authorization {
        case .authorized:
            isAvailable = true
            unavailableReason = nil
        case .notDetermined:
            isAvailable = false
            unavailableReason = "Calendar sync is off until you grant access."
        case .denied:
            isAvailable = false
            unavailableReason = "Calendar access is denied. Moody works fully without it — planned meals just won't appear on your device calendar. You can enable access in Settings."
        }
    }

    func requestAccessIfNeeded() async {
        if store.authorization == .notDetermined {
            _ = await store.requestAccess()
        }
        refreshAvailability()
    }

    /// Upsert the entry's event on the Moody calendar (CAL-1/CAL-2).
    /// No-ops gracefully when unavailable — the app never depends on sync.
    func sync(_ entry: PlanEntry, in context: ModelContext) {
        guard isAvailable else { return }
        guard let meal = entry.meal else {
            // D-37 flag state: a refill-needed entry has nothing to show yet.
            remove(entry, in: context)
            return
        }
        do {
            let calendarID = try store.ensureMoodyCalendar()
            let id = try store.upsertEvent(id: entry.eventKitID,
                                           data: eventData(for: entry, meal: meal),
                                           calendarID: calendarID)
            if entry.eventKitID != id {
                entry.eventKitID = id
                try context.save()
            }
        } catch {
            // Sync is best-effort; the plan itself is already persisted.
        }
    }

    /// Remove the entry's event (CAL-2: no orphans).
    func remove(_ entry: PlanEntry, in context: ModelContext) {
        guard let id = entry.eventKitID else { return }
        try? store.removeEvent(id: id)
        entry.eventKitID = nil
        try? context.save()
    }

    /// Sync every entry that has a meal; used by the toolbar action.
    func syncAll(in context: ModelContext) {
        guard isAvailable,
              let entries = try? context.fetch(FetchDescriptor<PlanEntry>()) else { return }
        for entry in entries { sync(entry, in: context) }
    }

    private func eventData(for entry: PlanEntry, meal: Meal) -> CalendarEventData {
        let hour = entry.slot == .dinner
            ? TuningDefaults.dinnerEventHour
            : TuningDefaults.breakfastEventHour
        let start = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0,
                                          of: entry.date) ?? entry.date
        let end = start.addingTimeInterval(
            TimeInterval(TuningDefaults.planEventDurationMinutes * 60))
        let slotName = entry.slot == .dinner ? "Dinner" : "Breakfast"
        return CalendarEventData(title: "\(slotName): \(meal.title)",
                                 start: start, end: end,
                                 notes: meal.freeformNotes.isEmpty ? nil : meal.freeformNotes)
    }
}

// ── CAL-4: shop-window suggestion (pure logic, fully testable) ──

enum ShopWindows {
    /// Propose up to `limit` windows of `duration` inside `day`'s
    /// `searchRange` that do not overlap any busy interval.
    static func suggest(busy: [DateInterval],
                        within searchRange: DateInterval,
                        duration: TimeInterval,
                        limit: Int = 3) -> [DateInterval] {
        // STRICT overlap: DateInterval.intersects treats touching endpoints
        // as intersecting, which both rejects back-to-back windows AND stalls
        // the cursor (clash.end == cursor → no advance → infinite loop).
        func overlaps(_ a: DateInterval, _ b: DateInterval) -> Bool {
            a.start < b.end && a.end > b.start
        }
        var proposals: [DateInterval] = []
        var cursor = searchRange.start
        let sortedBusy = busy.sorted { $0.start < $1.start }
        while cursor.addingTimeInterval(duration) <= searchRange.end,
              proposals.count < limit {
            let candidate = DateInterval(start: cursor, duration: duration)
            if let clash = sortedBusy.first(where: { overlaps($0, candidate) }) {
                cursor = clash.end // strictly > candidate.start, so always advances
            } else {
                proposals.append(candidate)
                cursor = candidate.end
            }
        }
        return proposals
    }
}
