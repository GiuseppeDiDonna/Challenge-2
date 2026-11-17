import XCTest

final class FocusCheckInUITests: XCTestCase {
    @MainActor
    func testPredictionUpdatesAndDurationBoundaries() {
        let app = isolatedApp()
        app.launch()

        let duration = app.textFields["plannedMinutes"]
        XCTAssertEqual(duration.value as? String, "45")
        XCTAssertTrue(app.staticTexts["Pick your energy to see the estimates."].exists)

        selectEnergy("Medium", in: app)
        // Reference percentages from the bundled synthetic-v1 model on macOS.
        assertVisible(["35 min", "45 min · Your pick", "55 min", "70.7%", "68.5%", "66.2%"], in: app)

        selectEnergy("High", in: app)
        assertVisible(["82.2%", "80.7%", "79.0%"], in: app)
        XCTAssertFalse(app.staticTexts["68.5%"].exists)

        replaceDuration(with: "5", in: app)
        assertVisible(["5 min · Your pick", "15 min"], in: app)
        XCTAssertFalse(app.staticTexts["-5 min"].exists)
        XCTAssertFalse(app.staticTexts["25 min"].exists)

        replaceDuration(with: "180", in: app)
        assertVisible(["170 min", "180 min · Your pick"], in: app)
        XCTAssertFalse(app.staticTexts["190 min"].exists)

        replaceDuration(with: "181", in: app)
        assertVisible(["Enter a length between 5 and 180 minutes."], in: app)
        XCTAssertFalse(app.staticTexts["180 min · Your pick"].exists)
    }

    @MainActor
    func testEarlyStopAndFeedbackSurviveRelaunchWithoutSleep() {
        let app = isolatedApp()
        app.launch()
        selectEnergy("High", in: app)
        app.buttons["Start focus"].tap()

        app.terminate()
        app.launch()
        let stop = app.buttons["End early"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(app.buttons["I felt tired"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.buttons["I felt tired"].tap()
        XCTAssertTrue(app.textFields["plannedMinutes"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.tabBars.buttons["Insights"].tap()
        let pilot = app.buttons["Pilot check"]
        XCTAssertTrue(pilot.waitForExistence(timeout: 5))
        pilot.tap()
        let count = app.descendants(matching: .any)["pilotSessionCount"].firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.value as? String, "1")
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
        XCTAssertTrue(app.textFields["plannedMinutes"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func isolatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                                "-focusTestHistory", UUID().uuidString, "-readsSleepFromHealth", "NO"]
        return app
    }

    @MainActor
    private func selectEnergy(_ label: String, in app: XCUIApplication) {
        app.buttons[label].tap()
    }

    @MainActor
    private func replaceDuration(with value: String, in app: XCUIApplication) {
        let field = app.textFields["plannedMinutes"]
        // The field is as wide as its digits: tap its trailing edge so the caret lands after them.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let previous = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + value)
        app.buttons["Done"].tap()
    }

    @MainActor
    private func assertVisible(_ labels: [String], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for label in labels {
            XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 2), label, file: file, line: line)
        }
    }
}
