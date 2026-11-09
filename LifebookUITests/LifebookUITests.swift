import XCTest

/// Taps through the real UI on a simulator.
final class LifebookUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func button(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetState"] + args
        app.launch()
        return app
    }

    /// Regression: "Switch person" used to crash while the day screen was still on its way out.
    func testSwitchPersonThenRejoin() {
        let app = launch(["-demo", "Deb K."])
        XCTAssertTrue(app.staticTexts["One thing needs attention."].waitForExistence(timeout: 5))

        app.buttons["Who's logging"].tap()
        app.buttons["Switch person"].tap()

        XCTAssertTrue(app.staticTexts["What's your name?"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningForeground)

        // Tap an existing name to log as them.
        button(app, containing: "Ana R.").tap()
        XCTAssertTrue(app.staticTexts["One thing needs attention."].waitForExistence(timeout: 3))

        // Or type a brand-new name — no one has to have added you.
        app.buttons["Who's logging"].tap()
        app.buttons["Switch person"].tap()
        let field = app.textFields["joinName"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Sam")
        button(app, containing: "I'm Sam").tap()
        XCTAssertTrue(app.staticTexts["One thing needs attention."].waitForExistence(timeout: 3))
        app.buttons["Who's logging"].tap()
        XCTAssertTrue(app.staticTexts["Sam"].waitForExistence(timeout: 2))
    }

    /// Start → log → close & send, with no "who's next" anywhere.
    func testShiftWithoutPickingWhosNext() {
        let app = launch(["-demo", "Deb K."])
        button(app, containing: "Start my session").tap()
        XCTAssertFalse(app.staticTexts["HANDING OFF TO"].exists)
        let start = button(app, containing: "until")
        XCTAssertTrue(start.waitForExistence(timeout: 3), app.debugDescription)
        start.tap()

        XCTAssertTrue(app.staticTexts["Your shift"].waitForExistence(timeout: 3))
        let allGood = app.buttons.matching(identifier: "All good")
        for i in 0..<allGood.count { allGood.element(boundBy: i).tap() }

        button(app, containing: "Hand off").tap()
        app.buttons["Close & send my notes"].tap()
        XCTAssertTrue(app.staticTexts["Shift closed.\nNow send your notes."].waitForExistence(timeout: 3)
                      || app.otherElements["ActivityListView"].waitForExistence(timeout: 3))
    }
}
