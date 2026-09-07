import XCTest

final class TennisTrackerWatchUITests: XCTestCase {
    private func launch(page: String, completedTraining: Bool = false, accessibleNavigation: Bool = false, scheduledTraining: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-watch", "-watch-page=\(page)"]
        if completedTraining { app.launchArguments.append("-watch-completed-training") }
        if accessibleNavigation { app.launchArguments.append("-watch-accessibility-navigation") }
        if scheduledTraining { app.launchArguments.append("-watch-scheduled-training") }
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
        let summary = app.buttons["Completed training summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("2 minutes 39 seconds"))
        XCTAssertTrue(summary.label.contains("72 beats per minute"))
        XCTAssertTrue(summary.label.contains("201 steps"))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Average heart rate")).count, 1)
        reveal(app.buttons["Edit"], in: app)
        app.buttons["Edit"].tap()
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
        XCTAssertTrue(app.buttons["Completed training summary"].label.contains("72 beats per minute"))
    }

    func testWatchDeleteCancelKeepsTrainingAndConfirmationRemovesIt() {
        let app = launch(page: "Live", completedTraining: true)
        reveal(app.buttons["Delete"], in: app)
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Completed training summary"].exists)
        reveal(app.buttons["Delete"], in: app)
        app.buttons["Delete"].tap()
        app.buttons["Confirm activity deletion"].tap()
        XCTAssertTrue(app.staticTexts["No tennis activity in progress."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Completed training summary"].exists)
    }

    func testAccessibleNavigationHasOnePageAndNoDuplicateActionButtons() {
        let app = launch(page: "Live", completedTraining: true, accessibleNavigation: true)
        XCTAssertTrue(app.buttons["Completed training summary"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Edit"].exists)
        XCTAssertFalse(app.buttons["Delete"].exists)
        XCTAssertFalse(app.buttons["View Details"].exists)
        XCTAssertFalse(app.buttons["Track Training Session"].exists)
        app.buttons["Completed training summary"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "72 beats per minute")).firstMatch.waitForExistence(timeout: 5))
    }

    func testEmptyAccessibleLivePageDoesNotExposeAdjacentPages() {
        let app = launch(page: "Live", accessibleNavigation: true)
        for _ in 0..<3 {
            app.swipeDown()
            XCTAssertTrue(app.staticTexts["No tennis activity in progress."].exists)
            XCTAssertFalse(app.buttons["Track Training Session"].exists)
        }
        XCTAssertTrue(app.buttons["Pages"].exists)
        capture(app, name: "Watch empty Live with accessible navigation")
    }

    func testScheduledQuickStartShowsSavedDetailsWithoutStartingOnOpen() {
        let app = launch(page: "Track", scheduledTraining: true)
        app.buttons["Track Training Session"].tap()
        XCTAssertTrue(app.staticTexts["Scheduled training preview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Scheduled training preview"].label.contains("Coaches: Chris"))
        XCTAssertFalse(app.buttons["Active training summary"].exists)
        reveal(app.buttons["Start Training"], in: app)
        capture(app, name: "Watch scheduled training ready to start")
        app.buttons["Start Training"].tap()
        XCTAssertTrue(app.buttons["Active training summary"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Active training summary"].label.contains("Coaches: Chris"))
    }

    func testSportingLayoutsForVisualReview() {
        for page in ["Track", "Score", "Live"] {
            let app = launch(page: page, completedTraining: page == "Live")
            capture(app, name: "Watch \(page)")
            app.terminate()
        }
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
