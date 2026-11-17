import XCTest

final class FocusCheckInUITests: XCTestCase {
    @MainActor
    func testRingOpensCheckInAndTimerWheelKeepsItsRange() {
        let app = isolatedApp()
        app.launch()

        selectFocusTab(app)
        XCTAssertTrue(app.staticTexts["Tap the ball to check in"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Start my session"].exists)
        openCheckIn(app)
        XCTAssertTrue(app.staticTexts["How’s your energy today?"].exists)

        XCTAssertEqual(hours(app).value as? String, "00 o’clock")
        XCTAssertEqual(minutes(app).value as? String, "45 minutes")
        XCTAssertFalse(app.buttons["Start my session"].isEnabled, "Energy is a model input: no start before choosing it")
        app.buttons["Steady"].tap()
        XCTAssertTrue(app.buttons["Start my session"].isEnabled)

        // The wheel loops through 00:00 and up to 23:45: it has to come back to 15 minutes...
        minutes(app).adjust(toPickerWheelValue: "00")
        XCTAssertTrue(waitForValues(app, hours: "00 o’clock", minutes: "15 minutes"), "\(String(describing: hours(app).value)) \(String(describing: minutes(app).value))")
        // ...and to 3 hours.
        hours(app).adjust(toPickerWheelValue: "05")
        XCTAssertTrue(waitForValues(app, hours: "03 o’clock", minutes: "00 minutes"), "\(String(describing: hours(app).value)) \(String(describing: minutes(app).value))")
        // Going around midnight, the nearest end is 15 minutes.
        hours(app).adjust(toPickerWheelValue: "23")
        XCTAssertTrue(waitForValues(app, hours: "00 o’clock", minutes: "15 minutes"), "\(String(describing: hours(app).value)) \(String(describing: minutes(app).value))")
    }

    @MainActor
    func testCountdownMatchesTheWheelAfterTheFirstSpin() {
        let app = isolatedApp()
        app.launch()
        openCheckIn(app)
        app.buttons["Steady"].tap()
        hours(app).adjust(toPickerWheelValue: "01")
        minutes(app).adjust(toPickerWheelValue: "30")
        app.buttons["Start my session"].tap()

        let remaining = app.descendants(matching: .any)["Time remaining"].firstMatch
        XCTAssertTrue(remaining.waitForExistence(timeout: 5))
        let value = remaining.value as? String ?? ""
        XCTAssertTrue(value.hasPrefix("90 minutes") || value.hasPrefix("89 minutes"), value)
    }

    @MainActor
    func testEarlyStopAndFeedbackSurviveRelaunchWithoutSleep() {
        let app = isolatedApp()
        app.launch()
        openCheckIn(app)
        app.buttons["Charged"].tap()
        app.buttons["Start my session"].tap()

        app.terminate()
        app.launch()
        let stop = app.buttons["End early"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(app.buttons["I felt tired"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.buttons["I felt tired"].tap()
        XCTAssertTrue(app.buttons["ringButton"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.tabBars.buttons["Insights"].tap()
        let pilot = app.buttons["Pilot check"]
        XCTAssertTrue(pilot.waitForExistence(timeout: 5))
        pilot.tap()
        let count = app.descendants(matching: .any)["pilotSessionCount"].firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.value as? String, "1")
        // The bundled synthetic-v1 model gives 80.7% for 45 min with high energy; the outcome is 0, so Brier = 0.807².
        let brier = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Starting model'")).firstMatch
        XCTAssertTrue(brier.exists)
        XCTAssertTrue(brier.label.contains("0.651") || (brier.value as? String)?.contains("0.651") == true,
                      "\(brier.label) | \(String(describing: brier.value))")
    }

    @MainActor
    func testTimerOpensCompletionFeedbackAtDeadline() {
        let app = isolatedApp()
        app.launchArguments += ["-focusTestNearDeadline", "YES"]
        app.launch()

        let finished = app.buttons["The length felt right"]
        XCTAssertTrue(finished.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["I could have kept going"].exists)
        XCTAssertFalse(app.buttons["I felt tired"].exists)
        finished.tap()
        XCTAssertTrue(app.buttons["ringButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func isolatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                                "-focusTestHistory", UUID().uuidString, "-readsSleepFromHealth", "NO",
                                "-userName", "Tester"]
        return app
    }

    /// A launch has sometimes opened on another tab (seen on "Block" in 2 of 4 runs, not reproduced by hand): start from Focus.
    @MainActor
    private func selectFocusTab(_ app: XCUIApplication) {
        let focus = app.tabBars.buttons["Focus"]
        if focus.waitForExistence(timeout: 5), !focus.isSelected { focus.tap() }
    }

    @MainActor
    private func hours(_ app: XCUIApplication) -> XCUIElement { app.pickerWheels.element(boundBy: 0) }

    @MainActor
    private func minutes(_ app: XCUIApplication) -> XCUIElement { app.pickerWheels.element(boundBy: 1) }

    /// The wheel snaps back a moment after the finger leaves it.
    @MainActor
    private func waitForValues(_ app: XCUIApplication, hours expectedHours: String, minutes expectedMinutes: String) -> Bool {
        let deadline = Date.now.addingTimeInterval(5)
        while Date.now < deadline {
            if hours(app).value as? String == expectedHours, minutes(app).value as? String == expectedMinutes { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    @MainActor
    private func openCheckIn(_ app: XCUIApplication) {
        selectFocusTab(app)
        let ring = app.buttons["ringButton"]
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        ring.tap()
        XCTAssertTrue(app.staticTexts["How’s your energy today?"].waitForExistence(timeout: 5))
    }
}
