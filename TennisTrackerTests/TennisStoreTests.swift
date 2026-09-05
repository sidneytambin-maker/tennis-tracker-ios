import XCTest
@testable import TennisTracker

@MainActor
final class TennisStoreTests: XCTestCase {
    func testSettingsThemeAndAnnouncementModePersist() {
        let url = temporaryStoreURL()
        let store = TennisStore(storeURL: url)
        var player = PlayerProfile()
        player.name = "Sidney"
        var settings = AppSettings()
        settings.theme = .classic
        settings.scoreAnnouncementMode = .reduced

        store.completeOnboarding(player: player, settings: settings)
        let reloaded = TennisStore(storeURL: url)

        XCTAssertEqual(reloaded.data.settings.theme, .classic)
        XCTAssertEqual(reloaded.data.settings.scoreAnnouncementMode, .reduced)
        XCTAssertEqual(reloaded.selectedPlayer?.displayName, "Sidney")
    }

    func testDefaultMatchUsesProfileAndLinksTournament() {
        let store = TennisStore(storeURL: temporaryStoreURL())
        var player = PlayerProfile()
        player.name = "Sidney"
        player.sightLevel = .b2
        player.playerMode = .blindTennis
        store.completeOnboarding(player: player, settings: AppSettings())
        var tournament = store.makeDefaultTournament()!
        tournament.name = "Regional Open"
        tournament.location = "Brighton Tennis Centre"
        tournament.date = Date(timeIntervalSince1970: 1_800_200_000)
        tournament.endDate = tournament.date.addingTimeInterval(86_400)
        tournament.hasStartTime = true
        tournament.isAllDay = false
        tournament.format = .roundRobin
        store.upsertTournament(tournament)

        let match = store.makeDefaultMatch(tournamentID: tournament.id)

        XCTAssertEqual(match?.playerName, "Sidney")
        XCTAssertEqual(match?.tournamentID, tournament.id)
        XCTAssertEqual(match?.date, tournament.date)
        XCTAssertEqual(match?.hasStartTime, true)
        XCTAssertEqual(match?.location, "Brighton Tennis Centre")
        XCTAssertEqual(match?.matchPosition, .roundRobin)
        XCTAssertEqual(match?.allowedBounces, 3)
        XCTAssertEqual(match?.suddenDeathDeuce, true)
    }

    func testLinkedMatchesAndTournamentDeleteChoicesStayConsistent() {
        let store = TennisStore(storeURL: temporaryStoreURL())
        var player = PlayerProfile()
        player.name = "Sidney"
        store.completeOnboarding(player: player, settings: AppSettings())
        var tournament = store.makeDefaultTournament()!
        store.upsertTournament(tournament)
        var linked = store.makeDefaultMatch(tournamentID: tournament.id)!
        linked.opponentName = "Klaudia"
        var unlinked = store.makeDefaultMatch()!
        unlinked.opponentName = "Sam"
        store.upsertMatch(linked)
        store.upsertMatch(unlinked)

        XCTAssertEqual(store.linkedMatches(for: tournament).map(\.id), [linked.id])

        store.deleteTournamentKeepingMatches(tournament)
        XCTAssertNil(store.data.matches.first { $0.id == linked.id }?.tournamentID)
        XCTAssertNotNil(store.data.matches.first { $0.id == unlinked.id })

        tournament.id = UUID()
        store.upsertTournament(tournament)
        linked.tournamentID = tournament.id
        store.upsertMatch(linked)
        store.deleteTournamentAndLinkedMatches(tournament)

        XCTAssertNil(store.data.matches.first { $0.id == linked.id })
        XCTAssertNotNil(store.data.matches.first { $0.id == unlinked.id })
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }
}
