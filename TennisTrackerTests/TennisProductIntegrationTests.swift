import XCTest
@testable import TennisTracker

final class TennisProductIntegrationTests: XCTestCase {
    private func match(_ result: MatchResult, doubles: Bool = false) -> MatchRecord {
        var match = MatchRecord(playerID: UUID())
        match.playerName = "Alex"
        match.opponentName = "Sam"
        match.partnerName = doubles ? "Jo" : ""
        match.opponent2Name = doubles ? "Kim" : ""
        match.matchType = doubles ? .doubles : .singles
        match.result = result
        match.matchFormat = .oneSet
        match.setScores = result == .win ? "6-4" : result == .loss ? "4-6" : "6-6"
        return match
    }

    func testSinglesResultWordsAndScore() {
        for (result, verb) in [(MatchResult.win, "beat"), (.loss, "lost to"), (.draw, "drew with")] {
            let record = match(result)
            let text = TennisSummaryFormatter.match(record)
            XCTAssertTrue(text.hasPrefix("Alex \(verb) Sam"))
            XCTAssertTrue(text.contains(record.setScores))
            XCTAssertFalse(text.contains("not recorded"))
        }
    }

    func testDoublesNeverOmitsAnyPlayer() {
        for result in [MatchResult.win, .loss, .draw] {
            for style in [TennisSummaryStyle.short, .long, .accessibility, .detailed] {
                let text = TennisSummaryFormatter.match(match(result, doubles: true), style: style)
                for name in ["Alex", "Jo", "Sam", "Kim"] { XCTAssertTrue(text.contains(name)) }
            }
        }
    }

    func testLiveScoreHasPointsAndNames() {
        var record = match(.win, doubles: true)
        record.status = .inProgress
        record.liveScore = TennisScoreSnapshot(playerPoints: 2, opponentPoints: 1, playerGames: 4, opponentGames: 3)
        let text = TennisSummaryFormatter.match(record)
        XCTAssertTrue(text.contains("Alex and Jo are playing Sam and Kim"))
        XCTAssertTrue(text.contains("4-3"))
        XCTAssertTrue(text.contains("30-15"))
    }

    func testMissingScoreIsExplicitButOptionalVenueIsNot() {
        var record = match(.win)
        record.setScores = ""
        let text = TennisSummaryFormatter.match(record)
        XCTAssertTrue(text.contains("Score not recorded"))
        XCTAssertFalse(text.lowercased().contains("venue not recorded"))
    }

    func testDateRangesSameMonthDifferentMonthAndYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }
        XCTAssertEqual(TennisSummaryFormatter.dateRange(from: date(2026, 9, 19), through: date(2026, 9, 20), calendar: calendar), "19 to 20 September 2026")
        XCTAssertEqual(TennisSummaryFormatter.dateRange(from: date(2026, 9, 30), through: date(2026, 10, 1), calendar: calendar), "30 September to 1 October 2026")
        XCTAssertEqual(TennisSummaryFormatter.dateRange(from: date(2026, 12, 31), through: date(2027, 1, 1), calendar: calendar), "31 December 2026 to 1 January 2027")
        XCTAssertEqual(TennisSummaryFormatter.dateRange(from: date(2026, 9, 19), through: date(2026, 9, 19), calendar: calendar), "19 September 2026")
    }

    func testTournamentCountsOnlyItsCompletedMatches() {
        var tournament = TournamentRecord(playerID: UUID())
        tournament.name = "Regional Open"
        var win = match(.win); win.tournamentID = tournament.id
        var loss = match(.loss); loss.tournamentID = tournament.id
        let text = TennisSummaryFormatter.tournament(tournament, matches: [win, loss, match(.win)])
        XCTAssertTrue(text.contains("2 matches: 1 win and 1 loss"))
    }

    func testTrainingContextAndMetricsAreNotInvented() {
        var session = TrainingSession(playerID: UUID())
        session.trainingType = .doublesPractice
        session.durationMinutes = 120
        session.context.coachName = "Chris"
        session.context.participantNames = ["Ben", "Lucy"]
        session.venue = "Tennis Centre"
        let text = TennisSummaryFormatter.training(session, style: .detailed)
        for expected in ["Doubles practice", "Chris", "2 hours", "Ben and Lucy", "Tennis Centre"] {
            XCTAssertTrue(text.contains(expected))
        }
        XCTAssertFalse(text.contains("BPM"))
        XCTAssertFalse(text.contains("calories"))
    }

    func testClassificationOptionsAreExact() {
        XCTAssertEqual(SightLevel.allCases.map(\.label), ["B1", "B2", "B3", "B4", "B5", "Sighted", "Not known"])
    }

    func testStructuredSetupSurvivesSnapshotRoundTrip() throws {
        var data = AppData()
        var player = PlayerProfile(); player.name = "Alex"; player.isRegularPartner = true
        data.players = [player]
        data.setup.coaches = [TennisCoach(name: "Coach")]
        data.setup.venues = [TennisVenue(name: "Centre", town: "Town")]
        data.setup.locations = [TennisLocation(name: "Town")]
        data.setup.tournamentTemplates = [TennisTournamentTemplate(name: "League", venueID: data.setup.venues[0].id)]
        let snapshot = TennisWatchSnapshot(data: data)
        let restored = try JSONDecoder.tennisTracker.decode(TennisWatchSnapshot.self, from: JSONEncoder.tennisTracker.encode(snapshot))
        XCTAssertEqual(restored.setup, data.setup)
        XCTAssertEqual(restored.players, data.players)
    }

    func testOlderSnapshotLoadsWithoutNewSetupField() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder.tennisTracker.encode(TennisWatchSnapshot())) as! [String: Any]
        json.removeValue(forKey: "setup")
        let restored = try JSONDecoder.tennisTracker.decode(TennisWatchSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.setup, TennisSetup())
    }

    func testOneSetAndDecidingSetRows() {
        XCTAssertEqual(TennisSetEntry.requiredRows(format: .oneSet, player: [6, 0, 0], opponent: [4, 0, 0]), 1)
        XCTAssertEqual(TennisSetEntry.requiredRows(format: .bestOfThree, player: [6, 6, 0], opponent: [4, 3, 0]), 2)
        XCTAssertEqual(TennisSetEntry.requiredRows(format: .bestOfThree, player: [6, 4, 0], opponent: [4, 6, 0]), 3)
    }

    func testPendingTrainingSurvivesOlderSnapshotAndAcknowledgesSameID() {
        let session = TennisWatchActivityFactory.trainingSession(playerID: UUID())
        let pending: [TennisWatchSyncCommand] = [.upsertTraining(session)]
        let first = TennisWatchReconciliation.reconcile(incoming: .empty, pending: pending)
        XCTAssertEqual(first.snapshot.trainingSessions, [session])
        XCTAssertEqual(first.pending, pending)
        let second = TennisWatchReconciliation.reconcile(incoming: first.snapshot, pending: pending)
        XCTAssertTrue(second.pending.isEmpty)
        XCTAssertEqual(second.snapshot.trainingSessions.count, 1)
    }

    func testTrainingResumeUsesActualStartNotScheduledDate() {
        var session = TrainingSession(playerID: UUID())
        session.date = Date(timeIntervalSince1970: 100)
        session.actualStart = Date(timeIntervalSince1970: 500)
        let finished = TennisWatchActivityFactory.finishTrainingSession(session, finishDate: Date(timeIntervalSince1970: 1100))
        XCTAssertEqual(finished.id, session.id)
        XCTAssertEqual(finished.durationMinutes, 10)
        XCTAssertFalse(finished.isActive)
    }

    func testFiveWatchPagesAndDeepLinks() {
        XCTAssertEqual(TennisWatchPage.allCases.map(\.rawValue), ["Today", "Track", "Live", "Recent", "Score"])
        for page in TennisWatchPage.allCases { XCTAssertEqual(TennisWatchPage.destination(for: page.url), page) }
        XCTAssertNil(TennisWatchPage.destination(for: URL(string: "https://example.com/score")!))
    }

    @MainActor
    func testPlayerDefaultFormatAndRepeatedWatchDelivery() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = TennisStore(storeURL: url)
        var player = PlayerProfile(); player.name = "Alex"; player.defaultMatchFormat = .oneSet
        store.upsertPlayer(player)
        XCTAssertEqual(store.makeDefaultMatch()?.matchFormat, .oneSet)
        XCTAssertEqual(TennisWatchActivityFactory.match(player: player, kind: .singles).matchFormat, .oneSet)
        let session = TennisWatchActivityFactory.trainingSession(playerID: player.id)
        store.applyWatchCommand(.upsertTraining(session))
        store.applyWatchCommand(.upsertTraining(session))
        XCTAssertEqual(store.data.trainingSessions.count, 1)
        XCTAssertEqual(store.data.trainingSessions.first?.id, session.id)
    }
}
