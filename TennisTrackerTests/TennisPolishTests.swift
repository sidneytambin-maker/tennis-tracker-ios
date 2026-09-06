import XCTest
@testable import TennisTracker

@MainActor
final class TennisPolishTests: XCTestCase {
    func testLegacyCoachIDAndMultiCoachRoundTrip() throws {
        let id = UUID()
        let legacy = try JSONSerialization.data(withJSONObject: ["coachID": id.uuidString, "coachName": "Chris"])
        var context = try JSONDecoder().decode(TennisActivityContext.self, from: legacy)
        XCTAssertEqual(context.coachIDs, [id])
        let second = UUID()
        context.coachIDs = [id, second, id]
        let decoded = try JSONDecoder().decode(TennisActivityContext.self, from: JSONEncoder().encode(context))
        XCTAssertEqual(decoded.coachIDs, [id, second])
        XCTAssertEqual(decoded.coachID, id)
    }

    func testNamesResolveIDsAndPreserveDeletedPeople() {
        let chris = TennisCoach(name: "Chris"), sarah = TennisCoach(name: "Sarah")
        var ben = PlayerProfile(); ben.name = "Ben"
        var lucy = PlayerProfile(); lucy.name = "Lucy"
        var context = TennisActivityContext()
        context.coachIDs = [chris.id, sarah.id]
        context.participantIDs = [ben.id, lucy.id]
        context.captureLegacyNames(coaches: [chris, sarah], players: [ben, lucy])
        XCTAssertEqual(context.coachSummary(in: [chris, sarah]), "Chris and Sarah")
        var renamed = sarah; renamed.name = "Sarah Jones"
        XCTAssertEqual(context.coachSummary(in: [chris, renamed]), "Chris and Sarah Jones")
        context.captureLegacyNames(coaches: [chris], players: [ben])
        XCTAssertEqual(context.coachSummary(in: [chris]), "Chris and Sarah")
        XCTAssertEqual(context.participantSummary(in: [ben]), "Ben and Lucy")
    }

    func testTrainingSummaryIncludesAllCoachesAndPlayers() {
        let coaches = [TennisCoach(name: "Chris"), TennisCoach(name: "Sarah")]
        let players = ["Ben", "Jaggy", "Lucy"].map { name in var player = PlayerProfile(); player.name = name; return player }
        var training = TrainingSession(playerID: UUID())
        training.trainingType = .groupCoaching
        training.durationMinutes = 120
        training.context.coachIDs = coaches.map(\.id)
        training.context.participantIDs = players.map(\.id)
        training.venue = "Morley Tennis Centre"
        let full = TennisSummaryFormatter.training(training, coaches: coaches, players: players)
        XCTAssertTrue(full.contains("Group coaching with Chris and Sarah"))
        XCTAssertTrue(full.contains("Ben, Jaggy and Lucy"))
        XCTAssertTrue(full.contains("2 hours"))
        XCTAssertTrue(full.contains("Morley Tennis Centre"))
        let compact = TennisSummaryFormatter.training(training, style: .short, coaches: coaches, players: players)
        XCTAssertTrue(compact.contains("Chris and Sarah"))
        XCTAssertFalse(compact.contains("BPM"))
    }

    func testOrderedChoicesClampAndDoNotReplaceUnknownImportedValues() {
        XCTAssertEqual(TennisOrderedSelection.moved(1, in: [1, 2, 3], forward: false), 1)
        XCTAssertEqual(TennisOrderedSelection.moved(3, in: [1, 2, 3], forward: true), 3)
        XCTAssertEqual(TennisOrderedSelection.moved(1, in: [1, 2, 3], forward: true), 2)
        XCTAssertEqual(TennisOrderedSelection.moved(2, in: [1, 2, 3], forward: false), 1)
        XCTAssertEqual(TennisOrderedSelection.moved(7, in: [1, 2, 3], forward: true), 7)
    }

    func testPeopleAreCommittedWithTrainingOnlyAndRetainIDs() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("data.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = TennisStore(storeURL: url)
        var owner = PlayerProfile(); owner.name = "Alex"
        store.completeOnboarding(player: owner, settings: AppSettings())
        let coaches = [TennisCoach(name: "Chris"), TennisCoach(name: "Sarah")]
        var player = PlayerProfile(); player.name = "Ben"
        var training = TrainingSession(playerID: owner.id)
        training.context.coachIDs = coaches.map(\.id)
        training.context.participantIDs = [player.id]
        XCTAssertTrue(store.data.setup.coaches.isEmpty)
        XCTAssertEqual(store.data.players.count, 1)
        store.upsertTraining(training, newPlayers: [player], newCoaches: coaches)
        store.upsertTraining(training, newPlayers: [player], newCoaches: coaches)
        let reloaded = TennisStore(storeURL: url)
        XCTAssertEqual(reloaded.data.setup.coaches.map(\.id), coaches.map(\.id))
        XCTAssertEqual(reloaded.data.trainingSessions.map(\.id), [training.id])
        XCTAssertEqual(reloaded.data.players.count, 2)
        XCTAssertEqual(reloaded.data.trainingSessions.first?.context.coachIDs, coaches.map(\.id))
    }

    func testSettingsDeepLinksHaveSingleLogicalPath() {
        let router = AppRouter()
        router.open(URL(string: "tennistracker://player/\(UUID())")!)
        XCTAssertEqual(router.selectedTab, "settings")
        XCTAssertEqual(router.settingsPath, [.players])
        router.open(URL(string: "tennistracker://settings")!)
        XCTAssertTrue(router.settingsPath.isEmpty)
    }
}
