import XCTest

final class TennisTrackerWatchUITests: XCTestCase {
    private func launch(page: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-watch", "-watch-page=\(page)"]
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
            let toggle = app.switches[name]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            toggle.tap()
            XCTAssertTrue(["Selected", "1"].contains(toggle.value as? String ?? ""))
        }
        XCTAssertFalse(app.buttons["Cancel"].exists)
        XCTAssertLessThanOrEqual(app.buttons.matching(identifier: "Back").count, 1)
    }
}
