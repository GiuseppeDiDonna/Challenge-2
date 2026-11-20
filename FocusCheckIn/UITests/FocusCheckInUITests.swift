import XCTest

final class FocusCheckInUITests: XCTestCase {
    @MainActor
    func testOneLongPressOpensEnergyThenTime() {
        let app = isolatedApp()
        app.launch()
        XCTAssertTrue(ring(app).waitForExistence(timeout: 8))
        ring(app).press(forDuration: 0.6)
        XCTAssertTrue(app.staticTexts["Hold the rings to check in"].waitForExistence(timeout: 2))

        // The long press opens the choice; it stays open after lifting, and Cancel closes it.
        let top = ring(app).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.1))
        let right = ring(app).coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.5))
        top.press(forDuration: 1.3)
        XCTAssertTrue(app.staticTexts["Touch and turn to choose"].waitForExistence(timeout: 2))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Hold the rings to check in"].waitForExistence(timeout: 2))

        // One long press, then a turn in a new touch sets the energy...
        top.press(forDuration: 1.3)
        right.press(forDuration: 0.1, thenDragTo: top, withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["Energy · Low"].waitForExistence(timeout: 5))
        // ...and the time is open at once, with no second long press.
        XCTAssertTrue(app.staticTexts["Touch and turn to set the time"].exists)
        XCTAssertEqual(ring(app).value as? String, "45 minutes")

        // Changing the energy keeps the choice open: turn again, no long press.
        app.buttons["Energy · Low"].tap()
        XCTAssertTrue(app.staticTexts["Touch and turn to choose"].waitForExistence(timeout: 2))
        top.press(forDuration: 0.1, thenDragTo: right, withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["Energy · Charged"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["End early"].exists)
    }

    @MainActor
    func testReleaseStartsSessionWithTurnedDuration() {
        let app = isolatedApp()
        app.launch()
        setEnergy(app, clockwise: nil, expect: "Steady")
        turnForTime(app, clockwise: true)
        let value = remaining(app)
        XCTAssertTrue(value.hasPrefix("75 minutes") || value.hasPrefix("74 minutes"), value)
    }

    @MainActor
    func testShortestDurationIsFifteenMinutes() {
        let app = isolatedApp()
        app.launch()
        setEnergy(app, clockwise: nil, expect: "Steady")
        turnForTime(app, clockwise: false)
        let value = remaining(app)
        XCTAssertTrue(value.hasPrefix("15 minutes") || value.hasPrefix("14 minutes"), value)
    }

    @MainActor
    func testEarlyStopAndFeedbackSurviveRelaunchWithoutSleep() {
        let app = isolatedApp()
        app.launch()
        setEnergy(app, clockwise: true, expect: "Charged")
        ring(app).tap()

        app.terminate()
        app.launch()
        let stop = app.buttons["End early"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        app.buttons["End session"].tap()
        XCTAssertTrue(app.buttons["Too tired"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Choose a reason"].isEnabled, "Done waits for a reason")

        app.terminate()
        app.launch()
        app.buttons["Too tired"].tap()
        app.buttons["Done"].tap()
        skipBreak(app)

        app.terminate()
        app.launch()
        let insights = app.buttons["Insights"]
        XCTAssertTrue(insights.waitForExistence(timeout: 5))
        insights.tap()
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

        let finished = app.buttons["Just right"]
        XCTAssertTrue(finished.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Session complete"].exists)
        XCTAssertTrue(app.buttons["Too short"].exists)
        XCTAssertFalse(app.buttons["Too tired"].exists)
        app.buttons["A little more"].tap()
        finished.tap()
        app.buttons["Done"].tap()
        skipBreak(app)
    }

    @MainActor
    func testSkipClosesTheEndScreen() {
        let app = isolatedApp()
        app.launch()
        setEnergy(app, clockwise: nil, expect: "Steady")
        ring(app).tap()
        XCTAssertTrue(app.descendants(matching: .any)["Time remaining"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["End early"].tap()
        app.buttons["End session"].tap()
        XCTAssertTrue(app.staticTexts["You stopped early"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()
        skipBreak(app)
    }

    @MainActor
    func testPauseStopsTheCountdownAndResumes() {
        let app = isolatedApp()
        app.launch()
        setEnergy(app, clockwise: nil, expect: "Steady")
        ring(app).tap()
        XCTAssertTrue(app.descendants(matching: .any)["Time remaining"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.staticTexts["break left"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Suggested 3 min · after 0 min of focus"].exists)
        let breakRing = app.descendants(matching: .any)["breakRing"].firstMatch
        XCTAssertEqual(breakRing.value as? String, "3 minutes")
        app.buttons["Resume now"].tap()
        let value = remaining(app)
        XCTAssertTrue(value.hasPrefix("44 minutes") || value.hasPrefix("45 minutes"), value)
    }

    @MainActor
    func testInsightsShowsRequestedChartsAndSleepUnlockProgress() {
        let app = isolatedApp()
        app.launch()
        let insights = app.buttons["Insights"]
        XCTAssertTrue(insights.waitForExistence(timeout: 5))
        insights.tap()

        XCTAssertTrue(app.staticTexts["Daily focus time"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Planned vs. focused"].exists)
        XCTAssertTrue(app.staticTexts["Sleep and focus"].exists)
        XCTAssertTrue(app.staticTexts["A few more sessions unlock this chart"].exists)

        let progress = app.descendants(matching: .any)["sleepUnlockProgress"].firstMatch
        XCTAssertTrue(progress.exists)
        XCTAssertTrue(progress.label.contains("0 of 5 sessions"))

        let remaining = app.descendants(matching: .any)["sleepSessionsRemaining"].firstMatch
        XCTAssertTrue(remaining.exists)
        XCTAssertTrue(remaining.label.contains("5 more to go"))
        XCTAssertFalse(app.buttons["Pilot check"].exists)
        // A pushed screen with the standard Back button.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Hold the rings to check in"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func isolatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                                "-focusTestHistory", UUID().uuidString, "-readsSleepFromHealth", "NO",
                                "-userName", "Tester"]
        return app
    }

    @MainActor
    private func ring(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["ringButton"].firstMatch
    }

    /// Holds past the 1 s arm time; turns a quarter in the same touch, or (no direction) lifts and taps to confirm.
    @MainActor
    private func holdAndTurn(_ app: XCUIApplication, clockwise: Bool? = nil) {
        let control = ring(app)
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        let top = control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.1))
        let right = control.coordinate(withNormalizedOffset: .init(dx: 0.9, dy: 0.5))
        guard let clockwise else {
            top.press(forDuration: 1.3)
            top.tap()
            return
        }
        let from = clockwise ? top : right, to = clockwise ? right : top
        from.press(forDuration: 1.3, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    /// After the energy the time is open: turn about 150° (25 min, one turn = 60 min) in one touch and release to start.
    /// A straight drag that passes beside the centre, outside its dead zone, sweeps the widest angle.
    @MainActor
    private func turnForTime(_ app: XCUIApplication, clockwise: Bool) {
        let control = ring(app)
        let upperRight = control.coordinate(withNormalizedOffset: .init(dx: 0.919, dy: 0.265))
        let lowerLeft = control.coordinate(withNormalizedOffset: .init(dx: 0.265, dy: 0.919))
        let from = clockwise ? upperRight : lowerLeft, to = clockwise ? lowerLeft : upperRight
        from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    @MainActor
    private func setEnergy(_ app: XCUIApplication, clockwise: Bool?, expect title: String) {
        holdAndTurn(app, clockwise: clockwise)
        XCTAssertTrue(app.buttons["Energy · \(title)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Touch and turn to set the time"].exists)
    }

    /// After the feedback a break starts: skip it to get back to the Home.
    @MainActor
    private func skipBreak(_ app: XCUIApplication) {
        let skip = app.buttons["Skip break"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        XCTAssertTrue(ring(app).waitForExistence(timeout: 5))
    }

    @MainActor
    private func remaining(_ app: XCUIApplication) -> String {
        let element = app.descendants(matching: .any)["Time remaining"].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        return element.value as? String ?? ""
    }
}
