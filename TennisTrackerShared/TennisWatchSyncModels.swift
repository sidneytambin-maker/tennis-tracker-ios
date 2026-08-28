import Foundation

struct TennisWatchSnapshot: Codable, Equatable {
    var generatedAt = Date()
    var selectedPlayerID: UUID?
    var players: [PlayerProfile] = []
    var matches: [MatchRecord] = []
    var trainingSessions: [TrainingSession] = []
    var tournaments: [TournamentRecord] = []
    var settings = AppSettings()

    static let empty = TennisWatchSnapshot()

    init() {}

    init(data: AppData, now: Date = Date()) {
        generatedAt = now
        selectedPlayerID = data.selectedPlayerID
        players = data.players
        settings = data.settings

        let recentLimit = Calendar.current.date(byAdding: .day, value: -60, to: now) ?? now
        matches = data.matches
            .filter { $0.status == .inProgress || $0.needsDetails || $0.date >= recentLimit || $0.date >= now }
            .sorted { $0.date > $1.date }
            .prefix(30)
            .map { $0 }
        trainingSessions = data.trainingSessions
            .filter { $0.needsDetails || $0.date >= recentLimit || $0.expectedEndDate >= now }
            .sorted { $0.date > $1.date }
            .prefix(30)
            .map { $0 }
        tournaments = data.tournaments
            .filter { !$0.isCompleted || $0.needsDetails || $0.endDate >= recentLimit }
            .sorted { $0.date > $1.date }
            .prefix(20)
            .map { $0 }
    }
}

enum TennisWatchSyncCommand: Codable, Equatable {
    case requestSnapshot
    case upsertMatch(MatchRecord)
    case upsertTraining(TrainingSession)
    case upsertTournament(TournamentRecord)
    case markMatchDetailsComplete(UUID)
    case markTrainingDetailsComplete(UUID)
    case markTournamentDetailsComplete(UUID)
}

enum TennisRecordConflictResolver {
    static func shouldReplace(incomingRevision: Int, incomingModifiedAt: Date, existingRevision: Int, existingModifiedAt: Date) -> Bool {
        if incomingRevision != existingRevision {
            return incomingRevision > existingRevision
        }
        return incomingModifiedAt >= existingModifiedAt
    }

    static func prepareLocalMatch(_ match: MatchRecord, now: Date = Date()) -> MatchRecord {
        var copy = match
        copy.revision += 1
        copy.modifiedAt = now
        return copy
    }

    static func prepareLocalTraining(_ session: TrainingSession, now: Date = Date()) -> TrainingSession {
        var copy = session
        copy.revision += 1
        copy.modifiedAt = now
        return copy
    }

    static func prepareLocalTournament(_ tournament: TournamentRecord, now: Date = Date()) -> TournamentRecord {
        var copy = tournament
        copy.revision += 1
        copy.modifiedAt = now
        return copy
    }
}

enum TennisWatchActivityFactory {
    static func trainingSession(playerID: UUID, startDate: Date = Date()) -> TrainingSession {
        var session = TrainingSession(playerID: playerID)
        session.date = startDate
        session.hasStartTime = true
        session.durationMinutes = 1
        session.hasSessionDetails = false
        session.needsDetails = true
        session.focus = "Needs details"
        session.notes = "Created on Apple Watch."
        return TennisRecordConflictResolver.prepareLocalTraining(session, now: startDate)
    }

    static func finishTrainingSession(_ session: TrainingSession, finishDate: Date = Date()) -> TrainingSession {
        var finished = session
        let minutes = Int(ceil(finishDate.timeIntervalSince(session.date) / 60))
        finished.durationMinutes = max(1, minutes)
        finished.needsDetails = true
        finished.hasSessionDetails = false
        return TennisRecordConflictResolver.prepareLocalTraining(finished, now: finishDate)
    }

    static func match(player: PlayerProfile, kind: MatchKind, tournament: TournamentRecord? = nil, startDate: Date = Date()) -> MatchRecord {
        var match = MatchRecord(playerID: player.id)
        match.date = tournament?.date ?? startDate
        match.hasStartTime = true
        match.status = .inProgress
        match.matchType = kind
        match.playerName = player.displayName
        match.opponentName = "Opponent"
        match.matchFormat = .bestOfThree
        match.sightLevel = player.sightLevel
        match.allowedBounces = player.sightLevel.allowedBounces
        match.suddenDeathDeuce = player.playerMode == .blindTennis
        match.tournamentID = tournament?.id
        match.venue = tournament?.location ?? ""
        match.needsDetails = true
        match.liveScore = TennisScoreState().snapshot
        return TennisRecordConflictResolver.prepareLocalMatch(match, now: startDate)
    }

    static func tournament(playerID: UUID, startDate: Date = Date()) -> TournamentRecord {
        var tournament = TournamentRecord(playerID: playerID)
        tournament.name = "Tournament"
        tournament.date = startDate
        tournament.endDate = startDate
        tournament.finalResult = .inProgress
        tournament.needsDetails = true
        tournament.notes = "Created on Apple Watch."
        return TennisRecordConflictResolver.prepareLocalTournament(tournament, now: startDate)
    }

    static func finishMatch(_ match: MatchRecord, score: TennisScoreState, now: Date = Date()) -> MatchRecord {
        var finished = match
        finished.status = .completed
        finished.liveScore = nil
        finished.yourSetsWon = score.playerSets
        finished.opponentSetsWon = score.opponentSets
        finished.setScores = score.completedSetScores.joined(separator: ", ")
        finished.result = score.playerSets >= score.opponentSets ? .win : .loss
        finished.hadTiebreak = score.isTiebreak || finished.setScores.contains("7-6") || finished.setScores.contains("6-7")
        finished.needsDetails = true
        return TennisRecordConflictResolver.prepareLocalMatch(finished, now: now)
    }
}

extension Date {
    var shortTennisDate: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    var fullTennisDate: String {
        formatted(date: .long, time: .omitted)
    }

    var shortTennisTime: String {
        formatted(date: .omitted, time: .shortened)
    }

    var tennisSummaryDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: self)
    }
}

extension Calendar {
    func dateByKeepingTime(from timeSource: Date, on dateSource: Date) -> Date {
        let time = dateComponents([.hour, .minute, .second], from: timeSource)
        var date = dateComponents([.year, .month, .day], from: dateSource)
        date.hour = time.hour
        date.minute = time.minute
        date.second = time.second
        return self.date(from: date) ?? dateSource
    }
}

extension Int {
    var durationText: String {
        let total = Swift.max(0, self)
        let hours = total / 60
        let minutes = total % 60
        var parts: [String] = []
        if hours > 0 { parts.append(hours == 1 ? "1 hour" : "\(hours) hours") }
        if minutes > 0 { parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes") }
        return parts.isEmpty ? "0 minutes" : parts.joined(separator: " ")
    }
}

extension JSONEncoder {
    static var tennisTracker: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var tennisTracker: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
