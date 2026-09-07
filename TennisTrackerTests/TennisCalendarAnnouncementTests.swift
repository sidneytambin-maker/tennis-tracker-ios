import XCTest
@testable import TennisTracker

@MainActor
final class TennisCalendarAnnouncementTests: XCTestCase {
    func testConfirmationNamesActivityDateAndVenueWithoutInventingMissingTime() {
        let playerID = UUID()
        var session = TrainingSession(playerID: playerID)
        session.venue = "Brentwood Tennis Club"
        session.hasStartTime = false
        let draft = TennisCalendarMapper.event(for: session)
        let message = draft.confirmation(saved: true)
        XCTAssertTrue(message.contains("Your training session"))
        XCTAssertTrue(message.contains(session.date.fullTennisDate))
        XCTAssertTrue(message.contains("at Brentwood Tennis Club"))
        XCTAssertFalse(message.contains(session.date.shortTennisTime))
        XCTAssertTrue(TennisCalendarMapper.event(for: MatchRecord(playerID: playerID)).confirmation(saved: true).contains("Your match"))
        XCTAssertTrue(TennisCalendarMapper.event(for: TournamentRecord(playerID: playerID)).confirmation(saved: true).contains("Your tournament"))
    }

    func testCalendarResultIsDeliveredForEveryActionIncludingIdenticalSuccessAndFailure() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = TennisStore(storeURL: url)
        var announcements: [String] = []
        store.announcementDelivery = { announcements.append($0) }
        let draft = TennisCalendarMapper.event(for: TrainingSession(playerID: UUID()))
        var saveCount = 0
        for _ in 0..<2 {
            await store.addToCalendar(draft) { received in
                XCTAssertEqual(received, draft)
                saveCount += 1
                return true
            }
        }
        await store.addToCalendar(draft) { _ in false }
        XCTAssertEqual(saveCount, 2)
        XCTAssertEqual(announcements.count, 3)
        XCTAssertEqual(announcements[0], announcements[1])
        XCTAssertTrue(announcements[2].hasPrefix("Not added"))
        XCTAssertFalse(announcements[2].contains("successfully"))
        XCTAssertEqual(store.lastAnnouncement, announcements[2])
    }
}
