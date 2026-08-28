import XCTest
@testable import TennisTracker

final class TennisStatisticsTests: XCTestCase {
    func testStatisticsSummariseMatchesTrainingAndTournaments() {
        let playerID = UUID()
        let now = Date()
        var win = MatchRecord(playerID: playerID)
        win.result = .win
        win.yourSetsWon = 2
        win.opponentSetsWon = 0
        win.hadTiebreak = true
        win.tiebreakScore = "7-5"
        var loss = MatchRecord(playerID: playerID)
        loss.result = .loss
        loss.yourSetsWon = 1
        loss.opponentSetsWon = 2
        let matches = [win, loss]
        let training = [
            TrainingSession(playerID: playerID, date: now, durationMinutes: 75),
            TrainingSession(playerID: playerID, date: now, durationMinutes: 45)
        ]
        let tournaments = [
            TournamentRecord(playerID: playerID, date: now, matchesPlayed: 3)
        ]

        let stats = TennisStatistics.build(matches: matches, training: training, tournaments: tournaments, today: now)

        XCTAssertEqual(stats.matchCount, 2)
        XCTAssertEqual(stats.winCount, 1)
        XCTAssertEqual(stats.lossCount, 1)
        XCTAssertEqual(stats.winRate, 0.5)
        XCTAssertEqual(stats.trainingMinutesLast30Days, 120)
        XCTAssertEqual(stats.tiebreakSetsLast30Days, 1)
        XCTAssertEqual(stats.upcomingTournamentCount, 1)
        XCTAssertEqual(stats.needsAttention, ["3 tournament matches still need adding.", "Some matches are not linked to training or tournaments."])
    }
}
