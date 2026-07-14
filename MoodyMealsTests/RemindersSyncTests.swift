import XCTest
@testable import MoodyEngine

/// SHOP-3 acceptance: the Reminders mirror — items push once (never
/// duplicated), completions flow both ways, the user's own Reminders
/// additions come back as app items, only managed reminders are ever
/// removed, and denial is visible, never silent (CAL-3 spirit).
@MainActor
final class RemindersSyncTests: XCTestCase {

    private final class MockStore: RemindersStore {
        var authorization: CalendarAuthorization
        var reminders: [ReminderItem] = []
        private var nextID = 0
        init(_ auth: CalendarAuthorization,
             reminders: [ReminderItem] = []) {
            authorization = auth
            self.reminders = reminders
        }
        func requestAccess() async -> Bool {
            if authorization == .notDetermined { authorization = .authorized }
            return authorization == .authorized
        }
        func addItem(_ title: String, toList listName: String) throws {
            nextID += 1
            reminders.append(ReminderItem(id: "r\(nextID)", title: title,
                                          isCompleted: false))
        }
        func items(inList listName: String) async throws -> [ReminderItem] {
            reminders
        }
        func setCompleted(_ completed: Bool, itemID: String) throws {
            guard let i = reminders.firstIndex(where: { $0.id == itemID })
            else { return }
            reminders[i].isCompleted = completed
        }
        func removeItem(itemID: String) throws {
            reminders.removeAll { $0.id == itemID }
        }
    }

    private func line(_ title: String, checked: Bool = false) -> RemindersSync.AppLine {
        .init(title: title, isChecked: checked)
    }

    func test_sync_pushesEachItemOnce_neverDuplicates() async throws {
        let store = MockStore(.authorized)
        let lines = [line("ground beef — 3 lb"), line("rice — 1 bag")]

        let first = await RemindersSync.sync(lines: lines, managedTitles: [],
                                             store: store)
        guard case .synced(let changes) = first else { return XCTFail("must sync") }
        XCTAssertEqual(changes.added, 2)
        XCTAssertEqual(changes.managedTitles,
                       ["ground beef — 3 lb", "rice — 1 bag"])

        // Same list again: nothing added, nothing duplicated.
        let second = await RemindersSync.sync(lines: lines,
                                              managedTitles: changes.managedTitles,
                                              store: store)
        guard case .synced(let again) = second else { return XCTFail("must sync") }
        XCTAssertEqual(again.added, 0)
        XCTAssertEqual(store.reminders.count, 2)
    }

    func test_completionInReminders_comesBackToTheApp() async {
        let store = MockStore(.authorized, reminders: [
            .init(id: "r1", title: "ground beef — 3 lb", isCompleted: true),
        ])
        let outcome = await RemindersSync.sync(
            lines: [line("ground beef — 3 lb")],
            managedTitles: ["ground beef — 3 lb"], store: store)
        guard case .synced(let changes) = outcome else { return XCTFail("must sync") }
        XCTAssertEqual(changes.checkedTitles, ["ground beef — 3 lb"])
    }

    func test_checkedInApp_completesTheReminder() async {
        let store = MockStore(.authorized, reminders: [
            .init(id: "r1", title: "ground beef — 3 lb", isCompleted: false),
        ])
        let outcome = await RemindersSync.sync(
            lines: [line("ground beef — 3 lb", checked: true)],
            managedTitles: ["ground beef — 3 lb"], store: store)
        guard case .synced(let changes) = outcome else { return XCTFail("must sync") }
        XCTAssertEqual(changes.completedInReminders, 1)
        XCTAssertEqual(store.reminders.first?.isCompleted, true)
    }

    func test_usersOwnReminder_isImported_neverDeleted() async {
        // "cat litter" went in via Siri — the mirror never pushed it.
        let store = MockStore(.authorized, reminders: [
            .init(id: "r1", title: "cat litter", isCompleted: false),
        ])
        let outcome = await RemindersSync.sync(
            lines: [line("ground beef — 3 lb")],
            managedTitles: [], store: store)
        guard case .synced(let changes) = outcome else { return XCTFail("must sync") }
        XCTAssertEqual(changes.importedTitles, ["cat litter"])
        XCTAssertEqual(changes.removed, 0)
        XCTAssertTrue(store.reminders.contains { $0.title == "cat litter" },
                      "the user's own reminder survives")
        XCTAssertTrue(changes.managedTitles.contains("cat litter"),
                      "once imported, the mirror manages it")
    }

    func test_itemLeftTheList_managedReminderIsCleared() async {
        // Bought last cycle (completed) + dropped from the plan (open):
        // both were OURS, both leave — a lingering completed reminder would
        // falsely check the same title on a future list.
        let store = MockStore(.authorized, reminders: [
            .init(id: "r1", title: "ground beef — 3 lb", isCompleted: true),
            .init(id: "r2", title: "cod — 1 lb", isCompleted: false),
        ])
        let outcome = await RemindersSync.sync(
            lines: [],
            managedTitles: ["ground beef — 3 lb", "cod — 1 lb"], store: store)
        guard case .synced(let changes) = outcome else { return XCTFail("must sync") }
        XCTAssertEqual(changes.removed, 2)
        XCTAssertTrue(store.reminders.isEmpty)
        XCTAssertTrue(changes.managedTitles.isEmpty)
    }

    func test_denied_isVisiblyUnavailable_neverSilent() async {
        let store = MockStore(.denied, reminders: [
            .init(id: "r1", title: "ground beef — 3 lb", isCompleted: false),
        ])
        let outcome = await RemindersSync.sync(
            lines: [line("rice — 1 bag")], managedTitles: [], store: store)
        guard case .unavailable(let reason) = outcome else {
            return XCTFail("denied must surface as unavailable, not silence")
        }
        XCTAssertTrue(reason.contains("Settings"),
                      "the way back is named — never a dead end")
        XCTAssertEqual(store.reminders.count, 1, "nothing touched while denied")
    }
}
