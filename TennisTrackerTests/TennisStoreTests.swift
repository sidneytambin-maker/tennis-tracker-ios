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
        store.upsertTournament(tournament)

        let match = store.makeDefaultMatch(tournamentID: tournament.id)

        XCTAssertEqual(match?.playerName, "Sidney")
        XCTAssertEqual(match?.tournamentID, tournament.id)
        XCTAssertEqual(match?.allowedBounces, 3)
        XCTAssertEqual(match?.suddenDeathDeuce, true)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }
}
