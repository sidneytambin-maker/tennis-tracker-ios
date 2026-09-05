import EventKit
import Foundation

struct CalendarEventDraft: Equatable {
    var title: String
    var notes: String
    var startDate: Date
    var endDate: Date
    var location: String
    var deepLink: URL
    var isAllDay = false
}

enum TennisCalendarMapper {
    static func event(for match: MatchRecord) -> CalendarEventDraft {
        CalendarEventDraft(
            title: "Tennis: \(match.playerTeam) versus \(match.opponentSummary.fallback("opponent not recorded"))",
            notes: "Tennis Tracker match. \(TennisSummaryFormatter.match(match, style: .long)) \(match.notes)",
            startDate: match.date,
            endDate: match.date.addingTimeInterval(TimeInterval((match.hasExpectedDuration ? match.expectedDurationMinutes : 60) * 60)),
            location: [match.venue, match.location].filter { !$0.isBlank }.joined(separator: ", "),
            deepLink: URL(string: "tennistracker://match/\(match.id.uuidString)")!
        )
    }

    static func event(for session: TrainingSession) -> CalendarEventDraft {
        CalendarEventDraft(
            title: "Tennis training: \(session.trainingType.rawValue)",
            notes: "\(TennisSummaryFormatter.training(session, style: .detailed)) \(session.notes)",
            startDate: session.date,
            endDate: session.expectedEndDate,
            location: session.placeText,
            deepLink: URL(string: "tennistracker://training/\(session.id.uuidString)")!
        )
    }

    static func event(for tournament: TournamentRecord) -> CalendarEventDraft {
        CalendarEventDraft(
            title: "Tennis tournament: \(tournament.name.fallback("Unnamed tournament"))",
            notes: "\(TennisSummaryFormatter.tournament(tournament, style: .short)) \(tournament.goal) \(tournament.notes)",
            startDate: tournament.date,
            endDate: tournament.isAllDay
                ? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: max(tournament.endDate, tournament.date))) ?? tournament.endDate
                : max(tournament.endDate, tournament.date.addingTimeInterval(60 * 60)),
            location: [tournament.venue, tournament.location].filter { !$0.isBlank }.joined(separator: ", "),
            deepLink: URL(string: "tennistracker://tournament/\(tournament.id.uuidString)")!,
            isAllDay: tournament.isAllDay || !tournament.hasStartTime
        )
    }
}

final class TennisCalendarService {
    static let shared = TennisCalendarService()

    private let store = EKEventStore()

    private init() {}

    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await store.requestFullAccessToEvents()
            }
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        } catch {
            return false
        }
    }

    func save(_ draft: CalendarEventDraft) async -> Bool {
        guard await requestAccess(), let calendar = store.defaultCalendarForNewEvents else { return false }
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = draft.title
        event.notes = "\(draft.notes)\n\(draft.deepLink.absoluteString)"
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.location = draft.location
        event.isAllDay = draft.isAllDay

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }
}
