import Foundation
import EventKit

// ── M1-2: the seam between sync logic and EventKit ───────────
// CAL-1..4 test against `CalendarStore`; `EventKitCalendarStore` is the thin
// real adapter (integration is simulator-limited — exercised manually).

enum CalendarAuthorization { case notDetermined, denied, authorized }

struct CalendarEventData: Equatable {
    var title: String
    var start: Date
    var end: Date
    var notes: String?
}

@MainActor
protocol CalendarStore {
    var authorization: CalendarAuthorization { get }
    func requestAccess() async -> Bool
    /// The dedicated "Moody" calendar's identifier, creating it if needed.
    func ensureMoodyCalendar() throws -> String
    /// Upsert: nil id creates, existing id updates. Returns the event id.
    func upsertEvent(id: String?, data: CalendarEventData, calendarID: String) throws -> String
    func removeEvent(id: String) throws
    func eventData(id: String) -> CalendarEventData?
}

enum CalendarStoreError: Error { case notAuthorized, calendarUnavailable, eventNotFound }

// ── Real adapter ─────────────────────────────────────────────

@MainActor
final class EventKitCalendarStore: CalendarStore {
    private let store = EKEventStore()
    static let calendarTitle = "Moody"

    var authorization: CalendarAuthorization {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func ensureMoodyCalendar() throws -> String {
        guard authorization == .authorized else { throw CalendarStoreError.notAuthorized }
        if let existing = store.calendars(for: .event)
            .first(where: { $0.title == Self.calendarTitle }) {
            return existing.calendarIdentifier
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle
        guard let source = store.defaultCalendarForNewEvents?.source
                ?? store.sources.first(where: { $0.sourceType == .local }) else {
            throw CalendarStoreError.calendarUnavailable
        }
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar.calendarIdentifier
    }

    func upsertEvent(id: String?, data: CalendarEventData, calendarID: String) throws -> String {
        guard authorization == .authorized else { throw CalendarStoreError.notAuthorized }
        let event: EKEvent
        if let id, let existing = store.event(withIdentifier: id) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
            guard let calendar = store.calendar(withIdentifier: calendarID) else {
                throw CalendarStoreError.calendarUnavailable
            }
            event.calendar = calendar
        }
        event.title = data.title
        event.startDate = data.start
        event.endDate = data.end
        event.notes = data.notes
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    func removeEvent(id: String) throws {
        guard authorization == .authorized else { throw CalendarStoreError.notAuthorized }
        guard let event = store.event(withIdentifier: id) else { return } // already gone
        try store.remove(event, span: .thisEvent, commit: true)
    }

    func eventData(id: String) -> CalendarEventData? {
        guard let event = store.event(withIdentifier: id) else { return nil }
        return CalendarEventData(title: event.title, start: event.startDate,
                                 end: event.endDate, notes: event.notes)
    }
}

// ── M2-4: Reminders adapter (same thin-seam pattern) ─────────

@MainActor
final class EventKitRemindersStore: RemindersStore {
    private let store = EKEventStore()

    var authorization: CalendarAuthorization {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    func addItem(_ title: String, toList listName: String) throws {
        guard authorization == .authorized else { throw CalendarStoreError.notAuthorized }
        let calendar: EKCalendar
        if let existing = store.calendars(for: .reminder)
            .first(where: { $0.title == listName }) {
            calendar = existing
        } else {
            let created = EKCalendar(for: .reminder, eventStore: store)
            created.title = listName
            guard let source = store.defaultCalendarForNewReminders()?.source
                    ?? store.sources.first(where: { $0.sourceType == .local }) else {
                throw CalendarStoreError.calendarUnavailable
            }
            created.source = source
            try store.saveCalendar(created, commit: true)
            calendar = created
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = calendar
        try store.save(reminder, commit: true)
    }
}
