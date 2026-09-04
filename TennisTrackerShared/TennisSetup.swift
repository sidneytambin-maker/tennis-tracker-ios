import Foundation

struct TennisCoach: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var organisation = ""
    var notes = ""
    var playerID: UUID?
}

struct TennisVenue: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var town = ""
    var address = ""
    var notes = ""
    var usedForTraining = true
    var usedForMatches = true
    var summary: String { [name, town].filter { !$0.isBlank }.joined(separator: ", ") }
}

struct TennisLocation: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
}

struct TennisTournamentTemplate: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var venueID: UUID?
    var format: TournamentFormat = .other
}

struct TennisSetup: Codable, Equatable {
    var coaches: [TennisCoach] = []
    var venues: [TennisVenue] = []
    var locations: [TennisLocation] = []
    var tournamentTemplates: [TennisTournamentTemplate] = []
}

// IDs link reusable records; names preserve the historical context after setup edits.
struct TennisActivityContext: Codable, Equatable {
    var coachID: UUID?
    var coachName = ""
    var participantIDs: [UUID] = []
    var participantNames: [String] = []
    var venueID: UUID?
    var tournamentID: UUID?
}

struct TennisWorkoutResult: Codable, Equatable {
    var workoutID: UUID?
    var durationSeconds: Double
    var averageHeartRate: Double?
    var activeEnergyKcal: Double?
}

struct TennisPracticeResult: Codable, Equatable {
    var kind: MatchKind = .singles
    var partnerID: UUID?
    var opponentID: UUID?
    var opponent2ID: UUID?
    var partnerName = ""
    var opponentName = ""
    var opponent2Name = ""
    var result: MatchResult = .draw
    var playerGames = 0
    var opponentGames = 0
}

enum TennisWatchPage: String, CaseIterable, Identifiable {
    case today = "Today", track = "Track", live = "Live", recent = "Recent", score = "Score"
    var id: String { rawValue }
    var url: URL { URL(string: "tennistracker://watch/\(rawValue.lowercased())")! }
    static func destination(for url: URL) -> Self? {
        guard url.scheme == "tennistracker", url.host == "watch" else { return nil }
        return allCases.first { url.lastPathComponent == $0.rawValue.lowercased() }
    }
}

enum TennisSetEntry {
    static func requiredRows(format: MatchFormat, player: [Int], opponent: [Int]) -> Int {
        if format == .oneSet { return 1 }
        var wins = 0, losses = 0
        for index in 0..<min(player.count, opponent.count, format.maximumSetsToEnter) {
            if player[index] == 0 && opponent[index] == 0 {
                return max(format.defaultSetsToEnter, index + 1)
            }
            if player[index] > opponent[index] { wins += 1 }
            if player[index] < opponent[index] { losses += 1 }
            if wins == format.setsNeededToWin || losses == format.setsNeededToWin { return index + 1 }
        }
        return format.maximumSetsToEnter
    }
}
