import XCTest

// Real tap-through coverage, not just a build+screenshot: after two rounds
// of "extra items don't work" reports that survived code review and a
// static screenshot, the only way to actually know is to drive the
// simulator and check the fields respond, the Add button fires, the item
// shows up, edit opens on tap, and swipe-to-delete removes it.
//
// The app's SwiftData store is real and persists across launches (this
// isn't an in-memory test double) — every fixture this test creates gets a
// run-unique name and a teardown block that removes it best-effort, so a
// failed run doesn't leave a duplicate behind to confuse the next one.
final class ExtraItemsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_addEditDelete_extraItem_endToEnd() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MOODY_SCREEN"] = "mealdetail"
        app.launch()

        let itemName = "UITest Wine Pairing \(UUID().uuidString.prefix(8))"
        let editedName = "\(itemName) (edited)"
        addTeardownBlock {
            app.deleteExtraItem(named: itemName)
            app.deleteExtraItem(named: editedName)
        }

        let nameField = app.textFields["addItemName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5),
                      "the 'add an item' field never appeared on the meal page")
        app.scrollToHittable(nameField)
        XCTAssertTrue(nameField.isHittable,
                      "the 'add an item' field isn't reachable near the top of its section")
        nameField.tap()
        nameField.typeText(itemName)

        let addButton = app.buttons["addItemAddButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        XCTAssertTrue(addButton.isEnabled,
                      "Add stayed disabled after a non-empty name was typed")
        addButton.tap()

        let newRow = app.staticTexts[itemName]
        XCTAssertTrue(newRow.waitForExistence(timeout: 5),
                      "typing a name and tapping Add did not add the item to the list")

        // The name field should be clear again, ready for the next add.
        XCTAssertNotEqual(nameField.value as? String, itemName,
                          "name field didn't reset after Add (still showed the typed text)")

        // Tap-to-edit: opens the edit sheet pre-filled with this item's name.
        app.scrollToHittable(newRow)
        newRow.tap()
        let editNameField = app.textFields["editItemName"]
        XCTAssertTrue(editNameField.waitForExistence(timeout: 5),
                      "tapping the row never opened the edit sheet")
        XCTAssertEqual(editNameField.value as? String, itemName,
                       "edit sheet didn't pre-fill the existing name")

        editNameField.tap()
        editNameField.clearText()
        editNameField.typeText(editedName)
        let saveButton = app.buttons["editItemSaveButton"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        let editedRow = app.staticTexts[editedName]
        XCTAssertTrue(editedRow.waitForExistence(timeout: 5),
                      "editing the name and tapping Save didn't update the list")

        // Swipe-to-delete removes it for good.
        XCTAssertTrue(app.deleteExtraItem(named: editedName),
                      "swiping the row never revealed a working Remove action")
        XCTAssertFalse(app.staticTexts[editedName].waitForExistence(timeout: 3),
                       "item was still in the list after Remove")
    }
}

private extension XCUIElement {
    /// `typeText` appends — clear a field by selecting all and deleting,
    /// which works whether or not the field currently has focus.
    func clearText() {
        guard let value = value as? String, !value.isEmpty else { return }
        tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
        typeText(deleteString)
    }
}

private extension XCUIApplication {
    /// Swipes up a bounded number of times until `element` is on-screen and
    /// tappable, or gives up — a real user scrolls too, so this isn't
    /// cheating the test, it's the same thing a thumb would do.
    func scrollToHittable(_ element: XCUIElement, maxAttempts: Int = 5) {
        var attempts = 0
        while !element.isHittable, attempts < maxAttempts {
            swipeUp()
            attempts += 1
        }
    }

    /// Best-effort swipe-to-delete by exact row name. Returns whether it
    /// actually found and removed something — used both as the test's own
    /// delete step and as teardown cleanup, so a run-unique fixture name
    /// never lingers to confuse the next run with a duplicate label.
    @discardableResult
    func deleteExtraItem(named name: String) -> Bool {
        let row = staticTexts[name]
        guard row.exists else { return false }
        scrollToHittable(row)
        guard row.isHittable else { return false }
        row.swipeLeft()
        let removeButton = buttons["Remove"].firstMatch
        guard removeButton.waitForExistence(timeout: 2) else { return false }
        removeButton.tap()
        return true
    }
}
