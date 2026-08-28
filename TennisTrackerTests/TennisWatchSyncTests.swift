import XCTest
@testable import TennisTracker

final class TennisWatchSyncTests: XCTestCase {
    func testWatchTrainingStartAndFinishKeepsRecordIDAndNeedsDetails() {
        let playerID = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let finish = start.addingTimeInterval(37 * 60)

        let session = TennisWatchActivityFactory.trainingSession(playerID: playerID, startDate: start)
        let finished = TennisWatchActivityFactory.finishTrainingSession(session, finishDate: finish)

        XCTAssertEqual(finished.id, session.id)
        XCTAssertEqual(finished.playerID, playerID)
        XCTAssertEqual(finished.durationMinutes, 37)
        XCTAssertTrue(finished.needsDetails)
        XCTAssertFalse(finished.hasSessionDetails)
        XCTAssertGreaterThan(finished.revision, session.revision)
    }

    func testWatchCreatedMatchHasStableIDLiveScoreAndNeedsDetails() {
        var player = PlayerProfile()
        player.name = "Sidney"
        player.sightLevel = .b2

        let match = TennisWatchActivityFactory.match(player: player, kind: .singles)

        XCTAssertEqual(match.playerID, player.id)
        XCTAssertEqual(match.playerName, "Sidney")
        XCTAssertEqual(match.status, .inProgress)
        XCTAssertEqual(match.allowedBounces, 3)
        XCTAssertNotNil(match.liveScore)
        XCTAssertTrue(match.needsDetails)
    }

    func testWatchMatchCanLinkToTournamentWithoutChangingTournamentID() {
        var player = PlayerProfile()
        player.name = "Sidney"
        var tournament = TournamentRecord(playerID: player.id)
        tournament.name = "Regional Open"
        tournament.location = "Brighton"
        tournament.date = Date(timeIntervalSince1970: 1_800_100_000)

        let match = TennisWatchActivityFactory.match(player: player, kind: .doubles, tournament: tournament)

        XCTAssertEqual(match.tournamentID, tournament.id)
        XCTAssertEqual(match.date, tournament.date)
        XCTAssertEqual(match.venue, "Brighton")
        XCTAssertEqual(match.matchType, .doubles)
    }

    func testConflictResolverUsesRevisionThenModifiedDate() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)

        XCTAssertTrue(TennisRecordConflictResolver.shouldReplace(incomingRevision: 2, incomingModifiedAt: older, existingRevision: 1, existingModifiedAt: newer))
        XCTAssertFalse(TennisRecordConflictResolver.shouldReplace(incomingRevision: 1, incomingModifiedAt: newer, existingRevision: 2, existingModifiedAt: older))
        XCTAssertTrue(TennisRecordConflictResolver.shouldReplace(incomingRevision: 2, incomingModifiedAt: newer, existingRevision: 2, existingModifiedAt: older))
    }

    func testWatchSnapshotIncludesActiveAndNeedsDetailsRecords() {
        let playerID = UUID()
        var data = AppData()
        data.selectedPlayerID = playerID
        data.players = [PlayerProfile()]
        data.players[0].id = playerID
        data.matches = [TennisWatchActivityFactory.match(player: data.players[0], kind: .singles)]
        data.trainingSessions = [TennisWatchActivityFactory.trainingSession(playerID: playerID)]

        let snapshot = TennisWatchSnapshot(data: data)

        XCTAssertEqual(snapshot.matches.count, 1)
        XCTAssertEqual(snapshot.trainingSessions.count, 1)
        XCTAssertTrue(snapshot.matches[0].needsDetails)
        XCTAssertTrue(snapshot.trainingSessions[0].needsDetails)
    }

    func testOneSetMatchSummaryUsesActualScoreAcrossSurfaces() {
        var player = PlayerProfile()
        player.name = "Sidney"
        var tournament = TournamentRecord(playerID: player.id)
        tournament.name = "Yorkshire League"
        var match = MatchRecord(playerID: player.id)
        match.playerName = "Sidney"
        match.opponentName = "Anthony Harrison"
        match.matchFormat = .oneSet
        match.status = .completed
        match.result = .win
        match.yourSetsWon = 1
        match.opponentSetsWon = 0
        match.setScores = "6-4"
        match.tournamentID = tournament.id
        match.date = date(day: 21, month: 8, year: 2026)

        XCTAssertEqual(
            TennisSummaryFormatter.match(match, tournaments: [tournament], style: .long),
            "Win against Anthony Harrison, 6-4, Yorkshire League, 21 August 2026."
        )
        XCTAssertEqual(
            TennisSummaryFormatter.match(match, tournaments: [tournament], style: .short),
            "Win against Anthony Harrison, 6-4, Yorkshire League."
        )
    }

    private func date(day: Int, month: Int, year: Int) -> Date {
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
