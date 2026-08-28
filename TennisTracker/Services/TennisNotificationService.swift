import Foundation
import UserNotifications

struct PlannedNotification: Equatable {
    var identifier: String
    var title: String
    var body: String
    var fireDate: Date
    var deepLink: URL
}

enum TennisNotificationPlanner {
    static func plannedRequests(data: AppData, now: Date = Date()) -> [PlannedNotification] {
        let settings = data.settings
        let lead = TimeInterval(settings.reminderLeadMinutes * 60)
        var requests: [PlannedNotification] = []

        if settings.matchRemindersEnabled {
            for match in data.matches where match.date > now && match.status != .completed {
                requests.append(PlannedNotification(
                    identifier: "match-\(match.id)",
                    title: "Upcoming match",
                    body: "\(match.playerName.fallback("Player")) against \(match.opponentSummary.fallback("opponent not recorded"))",
                    fireDate: max(now.addingTimeInterval(60), match.date.addingTimeInterval(-lead)),
                    deepLink: URL(string: "tennistracker://match/\(match.id.uuidString)")!
                ))
            }
        }

        if settings.trainingRemindersEnabled {
            for session in data.trainingSessions where session.date > now {
                requests.append(PlannedNotification(
                    identifier: "training-\(session.id)",
                    title: "Upcoming training",
                    body: "\(session.trainingType.rawValue) at \(session.placeText)",
                    fireDate: max(now.addingTimeInterval(60), session.date.addingTimeInterval(-lead)),
                    deepLink: URL(string: "tennistracker://training/\(session.id.uuidString)")!
                ))
            }
        }

        if settings.tournamentRemindersEnabled {
            for tournament in data.tournaments where tournament.date > now && !tournament.isCompleted {
                requests.append(PlannedNotification(
                    identifier: "tournament-\(tournament.id)",
                    title: "Upcoming tournament",
                    body: "\(tournament.name.fallback("Tournament")) at \(tournament.location.fallback("location not recorded"))",
                    fireDate: max(now.addingTimeInterval(60), tournament.date.addingTimeInterval(-lead)),
                    deepLink: URL(string: "tennistracker://tournament/\(tournament.id.uuidString)")!
                ))
            }
        }

        if settings.postSessionRemindersEnabled {
            let delay = TimeInterval(settings.postSessionDelayMinutes * 60)
            for session in data.trainingSessions where session.date <= now && session.date.addingTimeInterval(delay) > now {
                requests.append(PlannedNotification(
                    identifier: "training-reflection-\(session.id)",
                    title: "Training reflection",
                    body: "Add a short note while the session is still fresh.",
                    fireDate: session.date.addingTimeInterval(delay),
                    deepLink: URL(string: "tennistracker://training/\(session.id.uuidString)")!
                ))
            }
        }

        return requests.sorted { $0.fireDate < $1.fireDate }
    }
}

final class TennisNotificationService {
    static let shared = TennisNotificationService()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func rescheduleAll(for data: AppData) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let requests = TennisNotificationPlanner.plannedRequests(data: data)
        for planned in requests {
            let content = UNMutableNotificationContent()
            content.title = planned.title
            content.body = planned.body
            content.sound = .default
            content.userInfo = ["url": planned.deepLink.absoluteString]

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: planned.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: planned.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
