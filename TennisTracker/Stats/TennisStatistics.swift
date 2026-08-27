import Foundation

struct TennisStatistics: Equatable {
    let matchCount: Int
    let winCount: Int
    let lossCount: Int
    let winRate: Double
    let trainingCount: Int
    let trainingMinutesLast30Days: Int
    let tiebreakSetsLast30Days: Int
    let upcomingTournamentCount: Int
    let needsAttention: [String]

    var spokenSummary: String {
        let percent = Int((winRate * 100).rounded())
        return "\(matchCount) matches, \(winCount) wins, \(lossCount) losses, \(percent) percent win rate. \(trainingCount) training sessions saved."
    }

    static func build(matches: [MatchRecord], training: [TrainingSession], tournaments: [TournamentRecord], today: Date = Date()) -> TennisStatistics {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: today)) ?? today
        let wins = matches.filter { $0.result == .win }.count
        let losses = matches.filter { $0.result == .loss }.count
        let last30Matches = matches.filter { $0.date >= start }
        let last30Training = training.filter { $0.date >= start }
        let upcoming = tournaments.filter { calendar.startOfDay(for: $0.date) >= calendar.startOfDay(for: today) }
        let linkedCounts = Dictionary(grouping: matches.compactMap(\.tournamentID), by: { $0 }).mapValues(\.count)

        var attention: [String] = []
        let outstanding = tournaments.reduce(0) { total, tournament in
            total + tournament.outstandingMatches(linkedMatchCount: linkedCounts[tournament.id, default: 0])
        }
        if outstanding > 0 {
            attention.append("\(outstanding) tournament matches still need adding.")
        }
        if matches.contains(where: { $0.tournamentID == nil && $0.trainingSessionID == nil }) {
            attention.append("Some matches are not linked to training or tournaments.")
        }
        if matches.isEmpty && training.isEmpty {
            attention.append("No tennis activity recorded yet.")
        }
        if attention.isEmpty {
            attention.append("Nothing urgent needs attention.")
        }

        return TennisStatistics(
            matchCount: matches.count,
            winCount: wins,
            lossCount: losses,
            winRate: matches.isEmpty ? 0 : Double(wins) / Double(matches.count),
            trainingCount: training.count,
            trainingMinutesLast30Days: last30Training.reduce(0) { $0 + $1.durationMinutes },
            tiebreakSetsLast30Days: last30Matches.reduce(0) { $0 + $1.tiebreakSetCount },
            upcomingTournamentCount: upcoming.count,
            needsAttention: attention
        )
    }
}
