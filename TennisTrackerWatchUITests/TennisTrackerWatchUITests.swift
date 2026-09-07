import XCTest

final class TennisTrackerWatchUITests: XCTestCase {
    private func launch(page: String, completedTraining: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-watch", "-watch-page=\(page)"]
        if completedTraining { app.launchArguments.append("-watch-completed-training") }
        app.launch()
        return app
    }

    func testFivePagesHaveDistinctHeadings() {
        for page in ["Today", "Track", "Live", "Recent", "Score"] {
            let app = launch(page: page)
            XCTAssertTrue(app.staticTexts[page].waitForExistence(timeout: 10) || app.navigationBars[page].exists)
            if page == "Track" {
                XCTAssertTrue(app.buttons["Track Training Session"].exists)
                XCTAssertFalse(app.buttons["Record Point for Alex"].exists)
            }
            if page == "Live" { XCTAssertTrue(app.staticTexts["No tennis activity in progress."].exists) }
            app.terminate()
        }
    }

    func testTrainingDrillDownSupportsMultiSelectionWithoutExtraCancel() {
        let app = launch(page: "Track")
        app.buttons["Track Training Session"].tap()
        XCTAssertFalse(app.buttons["Cancel"].exists)
        app.buttons["Coaches"].tap()
        for name in ["Chris", "Sarah"] {
            let toggle = app.buttons[name]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            toggle.tap()
            XCTAssertTrue(toggle.isSelected)
        }
        XCTAssertFalse(app.buttons["Cancel"].exists)
        XCTAssertLessThanOrEqual(app.buttons.matching(identifier: "Back").count, 1)
    }

    func testCompletedWorkoutHasOnePreciseFitnessSummaryAndEditorCancel() {
        let app = launch(page: "Live", completedTraining: true)
        let summary = app.staticTexts["Completed training summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("2 minutes 39 seconds"))
        XCTAssertTrue(summary.label.contains("72 beats per minute"))
        XCTAssertTrue(summary.label.contains("201 steps"))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Average heart rate")).count, 1)
        reveal(app.buttons["Edit Training"], in: app)
        app.buttons["Edit Training"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("2 minutes 39 seconds"))
    }

    func testCompletedWorkoutCanBeMarkedCompleteOnWatch() {
        let app = launch(page: "Live", completedTraining: true)
        let complete = app.buttons["Mark Complete"]
        reveal(complete, in: app)
        complete.tap()
        XCTAssertTrue(complete.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Completed training summary"].label.contains("72 beats per minute"))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
