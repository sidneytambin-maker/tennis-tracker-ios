import Foundation

enum TennisSummaryStyle { case short, long, accessibility, detailed }

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
        case .short: return summary.shortText
        case .long, .accessibility: return summary.longText
        case .detailed:
            return "\(summary.longText) \(match.matchType.rawValue). \(match.matchFormat.label), \(match.suddenDeathDeuce ? "sudden-death deuce" : "advantage deuce"). Player classification: \(match.sightLevel.label). \(match.allowedBounces) bounces allowed."
        }
    }

    static func matchSummary(_ match: MatchRecord, tournaments: [TournamentRecord] = []) -> TennisMatchSummary {
        let team = match.playerTeam
        let opponents = match.opponentSummary.fallback("opponent not recorded")
        let score = scoreText(for: match)
        let tournament = match.tournamentID.flatMap { id in tournaments.first { $0.id == id }?.name } ?? ""
        let verb: String
        switch match.status {
        case .scheduled: verb = "will play"
        case .inProgress: verb = match.matchType == .doubles ? "are playing" : "is playing"
        case .completed:
            switch match.result {
            case .win: verb = "beat"
            case .loss: verb = "lost to"
            case .draw: verb = "drew with"
            case .retired: verb = "retired against"
            }
        }
        var standard = "\(team) \(verb) \(opponents)"
        if !score.isBlank { standard += ", \(score)" }
        else if match.status == .completed { standard += ". Score not recorded" }
        if !tournament.isBlank { standard += ", \(tournament)" }
        standard += ", \(match.date.tennisSummaryDate)"
        if match.hasStartTime { standard += " at \(match.date.shortTennisTime)" }
        let place = unique([match.venue, match.location]).joined(separator: ", ")
        if !place.isBlank { standard += " at \(place)" }
        standard += "."
        let status = match.status == .completed ? match.result.rawValue : match.status.rawValue
        // Doubles names remain complete even on compact surfaces.
        var compact = match.matchType == .doubles ? "\(team) \(verb) \(opponents)" : "\(status) against \(opponents)"
        if !score.isBlank { compact += ", \(score)" }
        else if match.status == .completed { compact += ". Score not recorded" }
        if !tournament.isBlank { compact += ", \(tournament)" }
        return TennisMatchSummary(shortText: compact + ".", longText: standard, accessibilityText: standard, scoreText: score.fallback("Score not recorded"))
    }

    static func training(_ session: TrainingSession, style: TennisSummaryStyle = .long, now: Date = Date()) -> String {
        var parts = [session.trainingType.rawValue]
        if !session.context.coachName.isBlank { parts[0] += " with coach \(session.context.coachName)" }
        if let start = session.actualStart {
            let minutes = session.isActive ? max(0, Int(now.timeIntervalSince(start) / 60)) : session.durationMinutes
            parts.append(minutes.durationText + (session.isActive ? " elapsed" : ""))
        } else { parts.append(session.durationMinutes.durationText) }
        if style != .short && !session.context.participantNames.isEmpty {
            parts.append("with " + session.context.participantNames.joined(separator: " and "))
        }
        parts += unique([session.venue, session.location])
        if style != .short {
            let date = session.actualStart ?? session.date
            parts.append(date.tennisSummaryDate + (session.hasStartTime || session.actualStart != nil ? " at \(date.shortTennisTime)" : ""))
        }
        if style == .detailed, let result = session.workout {
            if let heart = result.averageHeartRate { parts.append("Average heart rate \(Int(heart.rounded())) BPM") }
            if let energy = result.activeEnergyKcal { parts.append("Active energy \(Int(energy.rounded())) calories") }
        }
        if let practice = session.practiceResult {
            parts.append("Practice result: \(practice.result.rawValue), \(practice.playerGames)-\(practice.opponentGames)")
        }
        return parts.joined(separator: ", ") + "."
    }

    static func tournament(_ tournament: TournamentRecord, linkedMatchCount: Int = 0, style: TennisSummaryStyle = .long, matches: [MatchRecord] = []) -> String {
        var parts = [tournament.name.fallback("Tournament"), dateRange(from: tournament.date, through: tournament.endDate)]
        parts += unique([tournament.venue, tournament.location])
        if style != .short {
            let linked = matches.filter { $0.tournamentID == tournament.id && $0.status == .completed }
            if !linked.isEmpty {
                let wins = linked.filter { $0.result == .win }.count
                let losses = linked.filter { $0.result == .loss }.count
                let draws = linked.filter { $0.result == .draw }.count
                var results = ["\(wins) \(wins == 1 ? "win" : "wins")", "\(losses) \(losses == 1 ? "loss" : "losses")"]
                if draws > 0 { results.append("\(draws) \(draws == 1 ? "draw" : "draws")") }
                parts.append("\(linked.count) \(linked.count == 1 ? "match" : "matches"): " + results.joined(separator: " and "))
            } else {
                parts.append(linkedMatchCount == 0 ? "No matches recorded yet" : "\(linkedMatchCount) matches recorded")
            }
        }
        return parts.joined(separator: ", ") + "."
    }

    static func dateRange(from start: Date, through end: Date, calendar: Calendar = .current) -> String {
        let finish = max(start, end)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        func formatted(_ date: Date, _ pattern: String) -> String {
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }
        if calendar.isDate(start, inSameDayAs: finish) { return formatted(start, "d MMMM yyyy") }
        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: finish)
        let sameMonth = sameYear && calendar.component(.month, from: start) == calendar.component(.month, from: finish)
        return formatted(start, sameMonth ? "d" : sameYear ? "d MMMM" : "d MMMM yyyy") + " to " + formatted(finish, "d MMMM yyyy")
    }

    static func scoreAnnouncement(state: TennisScoreState, playerName: String, opponentName: String, suddenDeathDeuce: Bool) -> String {
        if state.isMatchComplete { return "Match, \(state.playerSets > state.opponentSets ? playerName : opponentName)." }
        let games: String
        if state.playerGames == state.opponentGames { games = "Games level at \(state.playerGames) all" }
        else {
            let leader = state.playerGames > state.opponentGames ? playerName : opponentName
            games = "\(leader) leads \(max(state.playerGames, state.opponentGames)) games to \(min(state.playerGames, state.opponentGames))"
        }
        return "\(state.pointScore(suddenDeathDeuce: suddenDeathDeuce)). \(games)."
    }

    private static func scoreText(for match: MatchRecord) -> String {
        if match.status == .inProgress, let live = match.liveScore {
            let state = TennisScoreState(snapshot: live)
            return [live.completedSetScores.joined(separator: ", "), "\(live.playerGames)-\(live.opponentGames)", state.pointScore(suddenDeathDeuce: match.suddenDeathDeuce)].filter { !$0.isBlank }.joined(separator: ", ")
        }
        if !match.setScores.isBlank { return match.setScores }
        if match.yourSetsWon + match.opponentSetsWon > 0 { return "sets \(match.yourSetsWon)-\(match.opponentSetsWon)" }
        return ""
    }

    private static func unique(_ values: [String]) -> [String] {
        var result: [String] = []
        for value in values where !value.isBlank && !result.contains(value) { result.append(value) }
        return result
    }
}
