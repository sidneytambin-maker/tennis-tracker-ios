import XCTest
@testable import TennisTracker

final class TestScoreTests: XCTestCase {
    func testInitialScoreUsesTennisTerms() {
        let score = TestScore()

        XCTAssertEqual(score.spokenScore, "Player One Love, Player Two Love")
        XCTAssertEqual(score.accessibilityValue, "Player One Love, Player Two Love")
    }

    func testPointProgressionUsesTennisTerms() {
        var score = TestScore()

        XCTAssertEqual(score.playerOneWinsPoint(), "Player One wins point. Current test score, Player One 15, Player Two Love.")
        XCTAssertEqual(score.playerTwoWinsPoint(), "Player Two wins point. Current test score, Player One 15, Player Two 15.")
        XCTAssertEqual(score.playerOneWinsPoint(), "Player One wins point. Current test score, Player One 30, Player Two 15.")
    }

    func testDeuceAndAdvantageAreAnnounced() {
        var score = TestScore()

        _ = score.playerOneWinsPoint()
        _ = score.playerOneWinsPoint()
        _ = score.playerOneWinsPoint()
        _ = score.playerTwoWinsPoint()
        _ = score.playerTwoWinsPoint()

        XCTAssertEqual(score.playerTwoWinsPoint(), "Player Two wins point. Current test score, Deuce.")
        XCTAssertEqual(score.playerOneWinsPoint(), "Player One wins point. Current test score, Advantage Player One.")
    }

    func testGameWinnerIsAnnounced() {
        var score = TestScore()

        _ = score.playerOneWinsPoint()
        _ = score.playerOneWinsPoint()
        _ = score.playerOneWinsPoint()

        XCTAssertEqual(score.playerOneWinsPoint(), "Player One wins the game. Reset the proof-of-concept score to start another game.")
    }
}

