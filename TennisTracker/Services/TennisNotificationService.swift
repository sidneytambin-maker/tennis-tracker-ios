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
            for match in data.matches where match.hasStartTime && match.date > now && match.status != .completed {
                requests.append(PlannedNotification(
                    identifier: "match-\(match.id)",
                    title: "Upcoming match",
                    body: "\(TennisSummaryFormatter.match(match, tournaments: data.tournaments, style: .short)) Starts at \(match.date.shortTennisTime).",
                    fireDate: max(now.addingTimeInterval(60), match.date.addingTimeInterval(-lead)),
                    deepLink: URL(string: "tennistracker://match/\(match.id.uuidString)")!
                ))
            }
        }

        if settings.trainingRemindersEnabled {
            for session in data.trainingSessions where session.hasStartTime && session.date > now && session.actualStart == nil {
                requests.append(PlannedNotification(
                    identifier: "training-\(session.id)",
                    title: "Upcoming training",
                    body: TennisSummaryFormatter.training(session),
                    fireDate: max(now.addingTimeInterval(60), session.date.addingTimeInterval(-lead)),
                    deepLink: URL(string: "tennistracker://training/\(session.id.uuidString)")!
                ))
            }
        }

        if settings.tournamentRemindersEnabled {
            for tournament in data.tournaments where tournament.date > now && !tournament.isCompleted {
                let body = TennisSummaryFormatter.tournament(tournament, style: .short)
                    + (tournament.isAllDay || !tournament.hasStartTime ? "" : " Starts at \(tournament.date.shortTennisTime).")
                requests.append(PlannedNotification(
                    identifier: "tournament-\(tournament.id)",
                    title: "Upcoming tournament",
                    body: body,
                    fireDate: max(now.addingTimeInterval(60), tournament.date.addingTimeInterval(-lead)),
                    deepLink: URL(string: "tennistracker://tournament/\(tournament.id.uuidString)")!
                ))
            }
        }

        if settings.postSessionRemindersEnabled {
            let delay = TimeInterval(settings.postSessionDelayMinutes * 60)
            for session in data.trainingSessions where !session.isActive && session.hasStartTime && session.expectedEndDate <= now && session.expectedEndDate.addingTimeInterval(delay) > now {
                requests.append(PlannedNotification(
                    identifier: "training-reflection-\(session.id)",
                    title: "Training reflection",
                    body: "\(TennisSummaryFormatter.training(session, style: .short)) Add your training notes.",
                    fireDate: session.expectedEndDate.addingTimeInterval(delay),
                    deepLink: URL(string: "tennistracker://training/\(session.id.uuidString)")!
                ))
            }
        }

        if settings.matchResultRemindersEnabled {
            for match in data.matches where match.hasStartTime && match.status != .completed {
                let expectedEnd = match.date.addingTimeInterval(TimeInterval((match.hasExpectedDuration ? match.expectedDurationMinutes : 120) * 60))
                let fireDate = expectedEnd.addingTimeInterval(TimeInterval(settings.postSessionDelayMinutes * 60))
                if expectedEnd <= now && fireDate > now {
                    requests.append(PlannedNotification(
                        identifier: "match-result-\(match.id)",
                        title: "Match result",
                    body: "Record Result for \(TennisSummaryFormatter.match(match, tournaments: data.tournaments, style: .short))",
                        fireDate: fireDate,
                        deepLink: URL(string: "tennistracker://match/\(match.id.uuidString)")!
                    ))
                }
            }
        }

        if settings.weeklySummaryEnabled {
            let nextWeek = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 9, minute: 0, weekday: 2), matchingPolicy: .nextTime) ?? now.addingTimeInterval(7 * 24 * 60 * 60)
            requests.append(PlannedNotification(
                identifier: "weekly-summary",
                title: "Tennis weekly summary",
                body: "Review your recent matches, training, and tournaments.",
                fireDate: nextWeek,
                deepLink: URL(string: "tennistracker://dashboard")!
            ))
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
