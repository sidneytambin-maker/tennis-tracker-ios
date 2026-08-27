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

        app.buttons["onboardingContinueButton"].tap()
        app.buttons["onboardingContinueButton"].tap()
        app.buttons["onboardingFinishButton"].tap()

        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))
        for tab in ["Player", "Matches", "Training", "Settings", "Dashboard"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.exists, "Missing tab \(tab)")
            button.tap()
        }

        app.tabBars.buttons["Dashboard"].tap()
        XCTAssertTrue(app.buttons["dashboardOpenTournamentsLink"].exists)
    }

    func testSettingsSaveActivates() throws {
        completeOnboarding()
        app.tabBars.buttons["Settings"].tap()
        let save = app.buttons["settingsSaveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(save.exists)
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

    func testAccessibilityAuditHasNoImmediateFailures() throws {
        completeOnboarding()
        if #available(iOS 17.0, *) {
            try app.performAccessibilityAudit()
        }
    }

    private func completeOnboarding() {
        app.buttons["setupProfileButton"].tap()
        let nameField = app.textFields["playerNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Sidney")
        app.buttons["onboardingContinueButton"].tap()
        app.buttons["onboardingContinueButton"].tap()
        app.buttons["onboardingFinishButton"].tap()
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))
    }
}
