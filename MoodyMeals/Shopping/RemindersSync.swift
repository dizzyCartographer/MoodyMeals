import Foundation

// ── SHOP-3 (Ria 2026-07-13): the Reminders mirror ─────────────
// The shopping list lives in Apple Reminders too — that puts it on a watch,
// in family sharing, and within Siri's reach. The app pushes its list;
// completions flow both ways; items added straight into the Reminders list
// (Siri, watch, a family member) come back as the user's own additions.
// CAL-3 spirit: denial is visible, never silent, and the in-app list works
// fully without it.

/// A reminder as the mirror sees it.
struct ReminderItem: Equatable {
    var id: String
    var title: String
    var isCompleted: Bool
}

@MainActor
enum RemindersSync {

    /// The one list the mirror owns. Sharing it from Reminders once puts the
    /// groceries in front of the whole family.
    static let listName = "Moody Groceries"

    struct AppLine: Equatable {
        var title: String          // display text (the builder's export text)
        var isChecked: Bool        // checked in the app
    }

    struct Changes: Equatable {
        var added = 0                          // pushed to Reminders
        var completedInReminders = 0           // app check-offs pushed out
        var removed = 0                        // managed leftovers cleared
        var checkedTitles: [String] = []       // completed out there → check here
        var importedTitles: [String] = []      // added out there → app list
        var managedTitles: Set<String> = []    // persist these for the next sync
    }

    enum Outcome: Equatable {
        case synced(Changes)
        case unavailable(reason: String)       // CAL-3: visible, never silent
    }

    /// Mirror the app's current list into the Reminders list, then read the
    /// user's edits back.
    /// - `managedTitles`: titles a previous sync pushed — only these are ever
    ///   removed from Reminders; any other reminder in the list is the user's
    ///   own and is imported, never deleted.
    /// - Completion is sticky in v1 (no per-side timestamps): whichever side
    ///   completed an item wins over the side that hasn't.
    static func sync(
        lines: [AppLine],
        managedTitles: Set<String>,
        store: RemindersStore
    ) async -> Outcome {
        if store.authorization == .notDetermined {
            _ = await store.requestAccess()
        }
        guard store.authorization == .authorized else {
            return .unavailable(reason:
                "Reminders access is off — the list here keeps working; access lives in iOS Settings.")
        }
        guard let existing = try? await store.items(inList: listName) else {
            return .unavailable(reason:
                "Reminders didn't answer — the list here keeps working.")
        }

        var changes = Changes()
        var byTitle: [String: ReminderItem] = [:]
        for item in existing where byTitle[item.title] == nil {
            byTitle[item.title] = item
        }

        for line in lines {
            if let reminder = byTitle[line.title] {
                switch (line.isChecked, reminder.isCompleted) {
                case (true, false):
                    try? store.setCompleted(true, itemID: reminder.id)
                    changes.completedInReminders += 1
                case (false, true):
                    changes.checkedTitles.append(line.title)
                default:
                    break
                }
            } else if !line.isChecked {
                if (try? store.addItem(line.title, toList: listName)) != nil {
                    changes.added += 1
                }
            }
        }

        let appTitles = Set(lines.map(\.title))
        for item in existing where !appTitles.contains(item.title) {
            if managedTitles.contains(item.title) {
                // It left the app's list (bought, re-merged, or no longer
                // needed). Remove even when completed: a lingering completed
                // reminder would mark the SAME title checked when it returns
                // on a future list (next week's beef isn't bought yet).
                try? store.removeItem(itemID: item.id)
                changes.removed += 1
            } else if !item.isCompleted {
                changes.importedTitles.append(item.title)   // Siri/watch/family add
            }
        }

        changes.managedTitles = appTitles.union(changes.importedTitles)
        return .synced(changes)
    }
}
