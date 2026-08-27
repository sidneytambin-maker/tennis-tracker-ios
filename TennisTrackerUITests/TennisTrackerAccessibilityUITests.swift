import XCTest

final class TennisTrackerAccessibilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-store"]
        app.launch()
    }

    func testOnboardingCanCreateProfileAndTabsActivate() throws {
        XCTAssertTrue(app.buttons["setupProfileButton"].waitForExistence(timeout: 5))
        app.buttons["setupProfileButton"].tap()

        let nameField = app.textFields["playerNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Sidney")

        continueOnboarding(to: "Choose Tennis Details")
        continueOnboarding(to: "Choose Preferences")
        finishOnboarding()

        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))
        for tab in ["Player", "Matches", "Training", "Settings", "Dashboard"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.exists, "Missing tab \(tab)")
            button.tap()
        }

        app.tabBars.buttons["Dashboard"].tap()
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 5))
    }

    func testSettingsSaveActivates() throws {
        completeOnboarding()
        app.tabBars.buttons["Settings"].tap()
        let save = app.buttons["Save settings"]
        if !save.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.staticTexts["Settings saved."].waitForExistence(timeout: 5))
    }

    func testImportantLiveScoringControlsActivate() throws {
        completeOnboarding()
        app.tabBars.buttons["Matches"].tap()
        app.buttons["Start live scoring"].tap()
        XCTAssertTrue(app.buttons["playerWinsPointButton"].waitForExistence(timeout: 5))
        app.buttons["playerWinsPointButton"].tap()
        app.buttons["opponentWinsPointButton"].tap()
        app.buttons["undoScoreButton"].tap()
        app.buttons["resetScoreButton"].tap()
    }

    func testFreshSetupShowsPersonalEmptyDashboardWithoutSeedData() throws {
        completeOnboarding()
        app.tabBars.buttons["Dashboard"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back, Sidney"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 matches, 0 wins, 0 losses, 0 percent win rate. 0 training sessions saved."].exists)
        XCTAssertFalse(app.staticTexts["Player One"].exists)
        XCTAssertFalse(app.staticTexts["Practice opponent"].exists)
    }

    private func completeOnboarding() {
        app.buttons["setupProfileButton"].tap()
        let nameField = app.textFields["playerNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Sidney")
        continueOnboarding(to: "Choose Tennis Details")
        continueOnboarding(to: "Choose Preferences")
        finishOnboarding()
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))
    }

    private func continueOnboarding(to heading: String) {
        let button = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 5))
    }

    private func finishOnboarding() {
        let button = app.buttons["onboardingFinishButton"]
        if !button.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }
}
