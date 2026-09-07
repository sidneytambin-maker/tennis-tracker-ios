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
        for destination in ["Matches", "Tournaments", "Training", "Player", "Dashboard"] {
            openDestination(destination)
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5), "Missing destination \(destination)")
        }
    }

    func testSettingsSaveActivates() throws {
        completeOnboarding()
        openDestination("Settings")
        let save = app.buttons["settingsToolbarSaveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.staticTexts["Settings saved."].waitForExistence(timeout: 5))
    }

    func testImportantLiveScoringControlsActivate() throws {
        completeOnboarding()
        openDestination("Matches")
        app.buttons["Track Match Scoring"].tap()
        XCTAssertTrue(app.buttons["startConfiguredLiveScoringButton"].waitForExistence(timeout: 5))
        app.buttons["startConfiguredLiveScoringButton"].tap()
        XCTAssertTrue(app.buttons["playerWinsPointButton"].waitForExistence(timeout: 5))
        app.buttons["playerWinsPointButton"].tap()
        app.buttons["opponentWinsPointButton"].tap()
        tapPossiblyScrolledButton("undoScoreButton")
        tapPossiblyScrolledButton("saveLiveProgressButton")
        tapPossiblyScrolledButton("hearFullScoreButton")
        tapPossiblyScrolledButton("resetScoreButton")
    }

    func testFreshSetupShowsPersonalEmptyDashboardWithoutSeedData() throws {
        completeOnboarding()
        openDestination("Dashboard")
        XCTAssertTrue(app.staticTexts["Welcome, Sidney"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 matches, 0 wins, 0 losses, 0 percent win rate. 0 training sessions saved."].exists)
        XCTAssertFalse(app.staticTexts["Player One"].exists)
        XCTAssertFalse(app.staticTexts["Practice opponent"].exists)
    }

    func testTournamentAndTrainingCreationAreReachable() throws {
        completeOnboarding()
        openDestination("Tournaments")
        app.buttons["addTournamentButton"].tap()
        let tournamentName = app.textFields["tournamentNameField"]
        XCTAssertTrue(tournamentName.waitForExistence(timeout: 5))
        tournamentName.tap()
        tournamentName.typeText("Regional Open")
        app.buttons["saveTournamentButton"].tap()
        XCTAssertTrue(textContaining("Regional Open").waitForExistence(timeout: 5))

        openDestination("Training")
        app.buttons["addTrainingButton"].tap()
        XCTAssertTrue(app.buttons["trainingTypePicker"].waitForExistence(timeout: 5))
        app.buttons["saveTrainingButton"].tap()
        XCTAssertTrue(textContaining("Singles practice").waitForExistence(timeout: 5))
    }

    func testTennisSetupAddsCoachAndRegularPartner() throws {
        completeOnboarding()
        openDestination("Settings")
        app.buttons["tennisSetupLink"].tap()
        app.buttons["Coaches"].tap()
        app.buttons["Add Coach"].tap()
        let coachName = app.textFields["Name"]
        XCTAssertTrue(coachName.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        coachName.tap()
        coachName.typeText("Chris")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Chris"].waitForExistence(timeout: 5))
        let coachesNavigation = app.navigationBars["Coaches"]
        XCTAssertTrue(coachesNavigation.waitForExistence(timeout: 5))
        coachesNavigation.buttons.element(boundBy: 0).tap()
        let partners = app.buttons["Regular Doubles Partners"]
        XCTAssertTrue(partners.waitForExistence(timeout: 5))
        partners.tap()
        app.buttons["addPlayerButton"].tap()
        let playerName = app.textFields["playerNameField"]
        XCTAssertTrue(playerName.waitForExistence(timeout: 5))
        playerName.tap()
        playerName.typeText("Jo")
        app.buttons["savePlayerButton"].tap()
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Jo")).firstMatch.waitForExistence(timeout: 5))
    }

    func testOneSetEditorDoesNotExposeAdditionalSets() throws {
        completeOnboarding()
        openDestination("Matches")
        app.buttons["addMatchButton"].tap()
        let setOne = app.staticTexts["Set 1"]
        for _ in 0..<8 {
            if setOne.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(setOne.exists)
        XCTAssertFalse(app.staticTexts["Set 2"].exists)
        XCTAssertFalse(app.buttons["Sets played"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["addMatchButton"].waitForExistence(timeout: 5))
    }

    func testThemeAndSetupHaveNoDuplicateNavigationControls() throws {
        completeOnboarding()
        openDestination("Settings")
        let theme = app.buttons["settingsThemePicker"]
        for _ in 0..<5 { if theme.isHittable { break }; app.swipeUp() }
        XCTAssertEqual(app.buttons.matching(identifier: "settingsThemePicker").count, 1)
        XCTAssertLessThanOrEqual(app.staticTexts.matching(identifier: "Theme").count, 1)
        for _ in 0..<5 { if app.buttons["tennisSetupLink"].isHittable { break }; app.swipeDown() }
        app.buttons["tennisSetupLink"].tap()
        for destination in ["Players", "Coaches", "Training Venues", "Match Venues"] {
            app.buttons[destination].tap()
            let bar = app.navigationBars[destination]
            XCTAssertTrue(bar.waitForExistence(timeout: 5))
            XCTAssertEqual(bar.buttons.count, 1, "Expected one Back action on \(destination)")
            bar.buttons.firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Tennis Setup"].waitForExistence(timeout: 5))
        }
    }

    func testTrainingMultiSelectionIsAnnouncedAndCancelDiscardsDraftPeople() throws {
        completeOnboarding()
        openDestination("Training")
        app.buttons["addTrainingButton"].tap()
        tapPossiblyScrolledButton("Coaches")
        for name in ["Chris", "Sarah"] {
            let field = app.textFields["New coach name"]
            field.tap(); field.typeText(name)
            app.buttons["Add Coach"].tap()
            let selected = app.switches[name]
            XCTAssertTrue(selected.waitForExistence(timeout: 5))
            XCTAssertTrue(["Selected", "1"].contains(selected.value as? String ?? ""))
        }
        app.switches["Chris"].tap()
        let deselected = NSPredicate(format: "value == %@ OR value == %@", "Not selected", "0")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: deselected, evaluatedWith: app.switches["Chris"])], timeout: 3), .completed,
            "Chris remained \(app.switches["Chris"].value ?? "unknown") after deselection")
        app.switches["Chris"].tap()
        app.navigationBars["Coaches"].buttons.firstMatch.tap()
        tapPossiblyScrolledButton("Players Present")
        for name in ["Ben", "Lucy"] {
            let field = app.textFields["Other player name"]
            field.tap(); field.typeText(name)
            app.buttons["Add Player"].tap()
            XCTAssertTrue(app.switches[name].waitForExistence(timeout: 5))
        }
        app.navigationBars["Players Present"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["saveTrainingButton"].exists)
        app.buttons["Cancel"].tap()
        app.buttons["addTrainingButton"].tap()
        tapPossiblyScrolledButton("Coaches")
        XCTAssertFalse(app.switches["Chris"].exists)
        XCTAssertFalse(app.switches["Sarah"].exists)
        app.navigationBars["Coaches"].buttons.firstMatch.tap()
        tapPossiblyScrolledButton("Players Present")
        XCTAssertFalse(app.switches["Ben"].exists)
        XCTAssertFalse(app.switches["Lucy"].exists)
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

    private func openDestination(_ name: String) {
        if name == "Player" {
            app.tabBars.buttons["Settings"].tap()
            app.buttons["Players"].tap()
            return
        }
        let visibleTab = app.tabBars.buttons[name]
        if visibleTab.waitForExistence(timeout: 2) {
            visibleTab.tap()
            return
        }
        XCTFail("Missing tab for \(name)")
    }

    private func tapPossiblyScrolledButton(_ identifier: String) {
        let button = app.buttons[identifier]
        for _ in 0..<8 { if button.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing button \(identifier)")
        button.tap()
    }

    private func textContaining(_ text: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
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
