import XCTest
import SwiftData
@testable import MoodyEngine

// ── Mock store: what EventKit integration can't do on CI, the mock pins.
// The EKEventStore adapter itself is thin and exercised manually (RUNLOG). ──

@MainActor
private final class MockCalendarStore: CalendarStore {
    var authorization: CalendarAuthorization
    var calendars: [String: String] = [:]          // id → title
    var events: [String: (data: CalendarEventData, calendarID: String)] = [:]
    private var nextID = 0

    init(authorization: CalendarAuthorization) {
        self.authorization = authorization
    }

    func requestAccess() async -> Bool {
        if authorization == .notDetermined { authorization = .authorized }
        return authorization == .authorized
    }

    func ensureMoodyCalendar() throws -> String {
        guard authorization == .authorized else { throw CalendarStoreError.notAuthorized }
        if let existing = calendars.first(where: { $0.value == "Moody" }) {
            return existing.key
        }
        let id = "cal-\(calendars.count)"
        calendars[id] = "Moody"
        return id
    }

    func upsertEvent(id: String?, data: CalendarEventData, calendarID: String) throws -> String {
        guard authorization == .authorized else { throw CalendarStoreError.notAuthorized }
        let eventID = id ?? { nextID += 1; return "evt-\(nextID)" }()
        events[eventID] = (data, calendarID)
        return eventID
    }

    func removeEvent(id: String) throws {
        events.removeValue(forKey: id)
    }

    func eventData(id: String) -> CalendarEventData? { events[id]?.data }
}

/// M1-2 acceptance: TC-CAL-1..4 against the mockable seam.
final class CalendarSyncTests: XCTestCase {

    @MainActor
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(AppSchema.models),
                                           configurations: [config])
        return (container, container.mainContext)
    }

    @MainActor
    private func makePlannedEntry(in context: ModelContext) throws -> PlanEntry {
        let ria = FamilyMember(name: "Ria", isAdult: true)
        let tacos = Meal(title: "Tacos")
        context.insert(ria)
        context.insert(tacos)
        let entry = try WeekPlan.assign(tacos, on: .now, slot: .dinner,
                                        attendees: [ria], in: context)
        return entry
    }

    @MainActor
    func test_CAL1_syncCreatesEventOnMoodyCalendarOnly() throws {
        let (container, context) = try makeContext()
        _ = container
        let store = MockCalendarStore(authorization: .authorized)
        let sync = CalendarSyncService(store: store)

        let entry = try makePlannedEntry(in: context)
        sync.sync(entry, in: context)

        XCTAssertNotNil(entry.eventKitID, "the entry remembers its event")
        XCTAssertEqual(store.calendars.values.sorted(), ["Moody"],
                       "exactly one dedicated calendar")
        let event = try XCTUnwrap(store.events[entry.eventKitID!])
        XCTAssertEqual(store.calendars[event.calendarID], "Moody",
                       "events land on the Moody calendar ONLY (CAL-1)")
        XCTAssertEqual(event.data.title, "Dinner: Tacos")
        let hour = Calendar.current.component(.hour, from: event.data.start)
        XCTAssertEqual(hour, TuningDefaults.dinnerEventHour)
    }

    @MainActor
    func test_CAL2_editAndClear_updateAndRemoveEvent_noOrphans() throws {
        let (container, context) = try makeContext()
        _ = container
        let store = MockCalendarStore(authorization: .authorized)
        let sync = CalendarSyncService(store: store)

        let entry = try makePlannedEntry(in: context)
        sync.sync(entry, in: context)
        let originalID = try XCTUnwrap(entry.eventKitID)

        // Edit: swap the meal → same event updates in place.
        let burgers = Meal(title: "Burgers")
        context.insert(burgers)
        entry.meal = burgers
        try context.save()
        sync.sync(entry, in: context)
        XCTAssertEqual(entry.eventKitID, originalID, "edits update, never duplicate")
        XCTAssertEqual(store.eventData(id: originalID)?.title, "Burgers".isEmpty ? "" : "Dinner: Burgers")
        XCTAssertEqual(store.events.count, 1)

        // Clear: event removed, no orphans (CAL-2).
        sync.remove(entry, in: context)
        XCTAssertNil(entry.eventKitID)
        XCTAssertTrue(store.events.isEmpty, "no orphaned events")
    }

    @MainActor
    func test_CAL3_denied_appFullyFunctional_syncVisiblyDisabled() throws {
        let (container, context) = try makeContext()
        _ = container
        let store = MockCalendarStore(authorization: .denied)
        let sync = CalendarSyncService(store: store)

        XCTAssertFalse(sync.isAvailable)
        let reason = try XCTUnwrap(sync.unavailableReason,
                                   "denial must carry a visible explanation (CAL-3)")
        XCTAssertTrue(reason.localizedCaseInsensitiveContains("denied"))

        // The app keeps working: planning persists, sync is a graceful no-op.
        let entry = try makePlannedEntry(in: context)
        sync.sync(entry, in: context)
        XCTAssertNil(entry.eventKitID)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(entry.meal?.title, "Tacos", "the plan itself is untouched")
    }

    @MainActor
    func test_CAL4_shopWindows_neverOverlapBusyEvents() {
        let calendar = Calendar.current
        let dayStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
        let dayEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: .now)!
        let search = DateInterval(start: dayStart, end: dayEnd)

        // Busy: 10–11:30 and 13–15.
        let busy = [
            DateInterval(start: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: .now)!,
                         end: calendar.date(bySettingHour: 11, minute: 30, second: 0, of: .now)!),
            DateInterval(start: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: .now)!,
                         end: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!),
        ]
        let windows = ShopWindows.suggest(busy: busy, within: search,
                                          duration: 60 * 60)

        XCTAssertFalse(windows.isEmpty)
        XCTAssertLessThanOrEqual(windows.count, 3)
        // Strict overlap: a window may START exactly when a meeting ends —
        // touching is fine, overlapping is not.
        func overlaps(_ a: DateInterval, _ b: DateInterval) -> Bool {
            a.start < b.end && a.end > b.start
        }
        for window in windows {
            XCTAssertTrue(busy.allSatisfy { !overlaps($0, window) },
                          "a proposed window must never overlap a commitment (CAL-4)")
            XCTAssertGreaterThanOrEqual(window.start, search.start)
            XCTAssertLessThanOrEqual(window.end, search.end)
        }
        // The 11:30–12:30 gap between the two meetings is real and usable.
        XCTAssertTrue(windows.contains { Calendar.current.component(.minute, from: $0.start) == 30 },
                      "back-to-back-with-busy windows must not be discarded")
    }

    @MainActor
    func test_CAL2b_refillFlaggedEntry_removesItsEvent() throws {
        // D-37 × CAL-2: deleting a planned meal flags the entry; its event
        // must not linger showing a meal that no longer exists.
        let (container, context) = try makeContext()
        _ = container
        let store = MockCalendarStore(authorization: .authorized)
        let sync = CalendarSyncService(store: store)

        let entry = try makePlannedEntry(in: context)
        sync.sync(entry, in: context)
        XCTAssertEqual(store.events.count, 1)

        let meal = try XCTUnwrap(entry.meal)
        context.delete(meal)
        try context.save()
        sync.sync(entry, in: context) // entry.meal is now nil (needs refill)

        XCTAssertTrue(store.events.isEmpty, "flagged entries carry no stale event")
        XCTAssertNil(entry.eventKitID)
    }
}
