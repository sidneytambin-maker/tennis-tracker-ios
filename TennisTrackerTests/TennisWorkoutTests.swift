import XCTest
@testable import TennisTracker

@MainActor
private final class MockWorkoutClient: TennisWorkoutClient {
    var available = true
    var permission = true
    var begins = 0
    var finishes = 0
    var permissionRequests = 0
    var result = TennisWorkoutResult(durationSeconds: 600)
    func requestPermission() async throws -> Bool { permissionRequests += 1; return permission }
    func begin(at date: Date) async throws { begins += 1 }
    func finish(at date: Date) async throws -> TennisWorkoutResult { finishes += 1; return result }
}

final class TennisWorkoutTests: XCTestCase {
    @MainActor
    func testDeclinedPermissionKeepsTrackingWithoutFakeMetrics() async {
        let client = MockWorkoutClient(); client.permission = false
        let coordinator = TennisWorkoutCoordinator(client: client)
        let start = Date(timeIntervalSince1970: 100)
        await coordinator.start(useHealth: true, at: start)
        XCTAssertEqual(coordinator.state, .recordingWithoutHealth)
        XCTAssertEqual(client.begins, 0)
        let result = await coordinator.finish(at: start.addingTimeInterval(600))
        XCTAssertEqual(result?.durationSeconds, 600)
        XCTAssertNil(result?.workoutID)
        XCTAssertNil(result?.averageHeartRate)
        XCTAssertEqual(client.finishes, 0)
    }

    @MainActor
    func testGrantedPermissionStartsAndEndsOneWorkout() async {
        let client = MockWorkoutClient()
        client.result.workoutID = UUID()
        let coordinator = TennisWorkoutCoordinator(client: client)
        await coordinator.start(useHealth: true)
        await coordinator.start(useHealth: true)
        XCTAssertEqual(coordinator.state, .recording)
        XCTAssertEqual(client.begins, 1)
        let result = await coordinator.finish()
        XCTAssertEqual(result?.workoutID, client.result.workoutID)
        XCTAssertEqual(client.finishes, 1)
        XCTAssertEqual(coordinator.state, .finished)
        let repeated = await coordinator.finish()
        XCTAssertNil(repeated)
    }

    @MainActor
    func testNoConsentNeverRequestsHealthPermission() async {
        let client = MockWorkoutClient()
        let coordinator = TennisWorkoutCoordinator(client: client)
        await coordinator.start(useHealth: false)
        XCTAssertEqual(client.permissionRequests, 0)
        XCTAssertEqual(client.begins, 0)
    }

    @MainActor
    func testUnavailableCapabilityKeepsTrainingFunctional() async {
        let client = MockWorkoutClient(); client.available = false
        let coordinator = TennisWorkoutCoordinator(client: client)
        await coordinator.start(useHealth: true)
        XCTAssertEqual(coordinator.state, .recordingWithoutHealth)
        XCTAssertEqual(client.permissionRequests, 0)
    }

    func testComplicationRoutesLiveTrainingAndScore() {
        var snapshot = TennisWatchSnapshot()
        snapshot.trainingSessions = [TennisWatchActivityFactory.trainingSession(playerID: UUID())]
        XCTAssertEqual(TennisGlance.make(snapshot: snapshot).destination, .live)
        var player = PlayerProfile(); player.name = "Alex"
        var match = TennisWatchActivityFactory.match(player: player, kind: .doubles)
        match.partnerName = "Jo"; match.opponentName = "Sam"; match.opponent2Name = "Kim"
        snapshot.matches = [match]
        let glance = TennisGlance.make(snapshot: snapshot)
        XCTAssertEqual(glance.destination, .score)
        for name in ["Alex", "Jo", "Sam", "Kim"] { XCTAssertTrue(glance.accessibilitySummary.contains(name)) }
    }

    func testStaleComplicationDoesNotClaimLiveMatch() {
        var snapshot = TennisWatchSnapshot()
        var match = TennisWatchActivityFactory.match(player: PlayerProfile(), kind: .singles)
        match.modifiedAt = Date(timeIntervalSince1970: 100)
        snapshot.matches = [match]
        let glance = TennisGlance.make(snapshot: snapshot, now: Date(timeIntervalSince1970: 100000))
        XCTAssertTrue(glance.isStale)
        XCTAssertEqual(glance.title, "Saved match")
    }

    func testPracticeResultIsNotACompetitiveMatch() {
        var data = AppData()
        var session = TrainingSession(playerID: UUID())
        session.trainingType = .matchPlay
        session.practiceResult = TennisPracticeResult(result: .win, playerGames: 6, opponentGames: 4)
        data.trainingSessions = [session]
        XCTAssertTrue(data.matches.isEmpty)
        XCTAssertEqual(data.trainingSessions[0].practiceResult?.playerGames, 6)
    }
}
