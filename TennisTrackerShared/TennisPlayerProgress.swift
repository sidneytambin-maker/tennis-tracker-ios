import Foundation

struct TennisResultTotals: Equatable {
    var wins = 0
    var losses = 0
    var draws = 0
    var retired = 0
    var count: Int { wins + losses + draws + retired }
    var summary: String { "\(count) matches. \(wins) wins, \(losses) losses, \(draws) draws, \(retired) retired." }

    mutating func record(_ result: MatchResult) {
        switch result {
        case .win: wins += 1
        case .loss: losses += 1
        case .draw: draws += 1
        case .retired: retired += 1
        }
    }
}

struct TennisFocusProgress: Identifiable, Equatable {
    let focus: String
    let sessions: Int
    let seconds: TimeInterval
    var id: String { focus }
    var summary: String { "\(sessions) \(sessions == 1 ? "session" : "sessions"), \(TennisDurationFormatter.text(seconds: seconds))." }
}

struct TennisPracticeSuggestion: Identifiable, Equatable {
    let source: String
    let detail: String
    var id: String { source }
}

struct TennisPlayerProgress: Equatable {
    var singles = TennisResultTotals()
    var doubles = TennisResultTotals()
    var singlesPractice = TennisResultTotals()
    var doublesPractice = TennisResultTotals()
    var focus: [TennisFocusProgress] = []
    var trainingTypes: [TennisFocusProgress] = []
    var suggestions: [TennisPracticeSuggestion] = []

    static func build(player: PlayerProfile?, matches: [MatchRecord], training: [TrainingSession], now: Date = Date()) -> Self {
        guard let player else { return Self() }
        var progress = Self()
        let matches = matches.filter { $0.playerID == player.id && $0.status == .completed }
        let training = training.filter { $0.playerID == player.id }
        let recorded = training.filter { $0.isRecordedTraining(at: now) }
        for match in matches {
            if match.trainingSessionID != nil {
                if match.matchType == .singles { progress.singlesPractice.record(match.result) }
                else { progress.doublesPractice.record(match.result) }
            } else {
                if match.matchType == .singles { progress.singles.record(match.result) }
                else { progress.doubles.record(match.result) }
            }
        }
        // Prefer complete linked match records over a duplicate session-level practice summary.
        let linkedSessions = Set(matches.compactMap(\.trainingSessionID))
        for session in recorded where !linkedSessions.contains(session.id) {
            guard let practice = session.practiceResult else { continue }
            if practice.kind == .singles { progress.singlesPractice.record(practice.result) }
            else { progress.doublesPractice.record(practice.result) }
        }
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: now)) ?? now
        let recent = recorded.filter { ($0.actualStart ?? $0.date) >= start && ($0.actualStart ?? $0.date) <= now }
        func breakdown(_ key: (TrainingSession) -> String) -> [TennisFocusProgress] {
            Dictionary(grouping: recent, by: key).map { name, sessions in
                TennisFocusProgress(focus: name, sessions: sessions.count,
                    seconds: sessions.reduce(0) { $0 + TennisDurationFormatter.trainingSeconds($1) })
            }.sorted { $0.sessions == $1.sessions ? $0.focus < $1.focus : $0.sessions > $1.sessions }
        }
        progress.focus = breakdown { $0.focusSummary }
        progress.trainingTypes = breakdown { $0.trainingType.rawValue }
        if !player.primaryGoal.isBlank {
            progress.suggestions.append(.init(source: "Your goal", detail: player.primaryGoal))
        }
        if !player.coachingFocus.isBlank {
            progress.suggestions.append(.init(source: "Your coaching focus", detail: player.coachingFocus))
        }
        if let match = matches.sorted(by: { $0.date > $1.date }).first(where: { !$0.nextPracticeFocus.isBlank || !$0.matchNeedsWork.isBlank }) {
            progress.suggestions.append(.init(source: "Your match review, \(match.date.fullTennisDate)",
                detail: match.nextPracticeFocus.fallback(match.matchNeedsWork)))
        }
        return progress
    }
}
