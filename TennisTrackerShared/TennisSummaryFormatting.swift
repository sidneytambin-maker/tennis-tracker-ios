import Foundation

enum TennisSummaryStyle {
    case short
    case long
    case accessibility
}

struct TennisMatchSummary: Equatable {
    var shortText: String
    var longText: String
    var accessibilityText: String
    var scoreText: String
}

enum TennisSummaryFormatter {
    static func match(_ match: MatchRecord, tournaments: [TournamentRecord] = [], style: TennisSummaryStyle = .long) -> String {
        let summary = matchSummary(match, tournaments: tournaments)
        switch style {
        case .short:
            return summary.shortText
        case .long:
            return summary.longText
        case .accessibility:
            return summary.accessibilityText
        }
    }

    static func matchSummary(_ match: MatchRecord, tournaments: [TournamentRecord] = []) -> TennisMatchSummary {
        let status = statusText(for: match)
        let opponent = match.opponentSummary.fallback("opponent not recorded")
        let score = scoreText(for: match)
        let tournament = match.tournamentID.flatMap { id in tournaments.first { $0.id == id }?.name }.flatMap { $0.isBlank ? nil : $0 }
        let date = match.date.tennisSummaryDate

        var shortParts = ["\(status) against \(opponent)"]
        if !score.isBlank { shortParts.append(score) }
        if let tournament { shortParts.append(tournament) }

        var longParts = shortParts
        longParts.append(date)

        let short = shortParts.joined(separator: ", ") + "."
        let long = longParts.joined(separator: ", ") + "."
        return TennisMatchSummary(
            shortText: short,
            longText: long,
            accessibilityText: long,
            scoreText: score.fallback("score not recorded")
        )
    }

    static func training(_ session: TrainingSession, style: TennisSummaryStyle = .long) -> String {
        let duration = session.durationMinutes.durationText
        let focus = session.focus.fallback("focus not recorded")
        let date = session.date.formatted(date: .abbreviated, time: session.hasStartTime ? .shortened : .omitted)
        switch style {
        case .short:
            return "Training, \(duration), \(focus)."
        case .long, .accessibility:
            return "Training, \(duration), \(focus), \(date)."
        }
    }

    static func tournament(_ tournament: TournamentRecord, linkedMatchCount: Int = 0, style: TennisSummaryStyle = .long) -> String {
        let name = tournament.name.fallback("Tournament")
        let place = tournament.location.fallback("location not recorded")
        let matchText = linkedMatchCount == 1 ? "1 match linked" : "\(linkedMatchCount) matches linked"
        switch style {
        case .short:
            return "\(name), \(tournament.finalResult.rawValue)."
        case .long, .accessibility:
            return "\(name), \(tournament.finalResult.rawValue), \(place), \(matchText), \(tournament.date.shortTennisDate)."
        }
    }

    static func scoreAnnouncement(state: TennisScoreState, playerName: String, opponentName: String, suddenDeathDeuce: Bool) -> String {
        if state.isMatchComplete {
            let winner = state.playerSets > state.opponentSets ? playerName : opponentName
            return "Match, \(winner)."
        }
        if state.playerGames != 0 || state.opponentGames != 0 {
            return "\(state.pointScore(suddenDeathDeuce: suddenDeathDeuce)), \(playerName) leads \(state.playerGames) games to \(state.opponentGames)."
        }
        return state.pointScore(suddenDeathDeuce: suddenDeathDeuce)
    }

    private static func statusText(for match: MatchRecord) -> String {
        switch match.status {
        case .scheduled:
            return "Scheduled"
        case .inProgress:
            return "In progress"
        case .completed:
            return match.result.rawValue
        }
    }

    private static func scoreText(for match: MatchRecord) -> String {
        if !match.setScores.isBlank {
            return match.setScores.replacingOccurrences(of: "-", with: "-")
        }
        if !match.liveScoreText.isBlank {
            return match.liveScoreText
        }
        let totalSets = match.yourSetsWon + match.opponentSetsWon
        if totalSets > 0 {
            return "sets \(match.yourSetsWon)-\(match.opponentSetsWon)"
        }
        return ""
    }
}

private extension MatchRecord {
    var liveScoreText: String {
        guard let liveScore else { return "" }
        return "games \(liveScore.playerGames)-\(liveScore.opponentGames), sets \(liveScore.playerSets)-\(liveScore.opponentSets)"
    }
}
