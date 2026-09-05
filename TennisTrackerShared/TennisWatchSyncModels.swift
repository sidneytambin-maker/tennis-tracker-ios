import Foundation

struct TennisWatchSnapshot: Codable, Equatable {
    var generatedAt = Date()
    var selectedPlayerID: UUID?
    var players: [PlayerProfile] = []
    var matches: [MatchRecord] = []
    var trainingSessions: [TrainingSession] = []
    var tournaments: [TournamentRecord] = []
    var settings = AppSettings()
    var setup = TennisSetup()

    static let empty = TennisWatchSnapshot()

    init() {}

    init(data: AppData, now: Date = Date()) {
        generatedAt = now
        selectedPlayerID = data.selectedPlayerID
        players = data.players
        settings = data.settings
        setup = data.setup

        let recentLimit = Calendar.current.date(byAdding: .day, value: -60, to: now) ?? now
        matches = data.matches
            .filter { $0.status == .inProgress || $0.needsDetails || $0.date >= recentLimit || $0.date >= now }
            .sorted { $0.date > $1.date }
            .prefix(30)
            .map { $0 }
        // History limits must never drop an active record or an offline edit awaiting details.
        matches += data.matches.filter { record in
            (record.status == .inProgress || record.needsDetails) && !matches.contains { $0.id == record.id }
        }
        trainingSessions = data.trainingSessions
            .filter { $0.isActive || $0.needsDetails || $0.date >= recentLimit || $0.expectedEndDate >= now }
            .sorted { $0.date > $1.date }
            .prefix(30)
            .map { $0 }
        trainingSessions += data.trainingSessions.filter { record in
            (record.isActive || record.needsDetails) && !trainingSessions.contains { $0.id == record.id }
        }
        tournaments = data.tournaments
            .filter { !$0.isCompleted || $0.needsDetails || $0.endDate >= recentLimit }
            .sorted { $0.date > $1.date }
            .prefix(20)
            .map { $0 }
        tournaments += data.tournaments.filter { record in
            (!record.isCompleted || record.needsDetails) && !tournaments.contains { $0.id == record.id }
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try c.decodeIfPresent(Date.self, forKey: .generatedAt) ?? .distantPast
        selectedPlayerID = try c.decodeIfPresent(UUID.self, forKey: .selectedPlayerID)
        players = try c.decodeIfPresent([PlayerProfile].self, forKey: .players) ?? []
        matches = try c.decodeIfPresent([MatchRecord].self, forKey: .matches) ?? []
        trainingSessions = try c.decodeIfPresent([TrainingSession].self, forKey: .trainingSessions) ?? []
        tournaments = try c.decodeIfPresent([TournamentRecord].self, forKey: .tournaments) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        setup = try c.decodeIfPresent(TennisSetup.self, forKey: .setup) ?? TennisSetup()
    }
}

enum TennisWatchSyncCommand: Codable, Equatable {
    case requestSnapshot
    case snapshotReceived(Date)
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
        // The existing wire format carries whole seconds. Compare at that precision
        // so an encoded acknowledgement can acknowledge its local source record.
        return incomingModifiedAt.timeIntervalSince1970.rounded(.down)
            >= existingModifiedAt.timeIntervalSince1970.rounded(.down)
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
    static func trainingSession(playerID: UUID, type: TrainingType = .singlesPractice, startDate: Date = Date()) -> TrainingSession {
        var session = TrainingSession(playerID: playerID)
        session.date = startDate
        session.actualStart = startDate
        session.hasStartTime = true
        session.durationMinutes = 1
        session.trainingType = type
        session.hasSessionDetails = false
        session.needsDetails = true
        session.focus = type.rawValue
        return TennisRecordConflictResolver.prepareLocalTraining(session, now: startDate)
    }

    static func finishTrainingSession(_ session: TrainingSession, finishDate: Date = Date()) -> TrainingSession {
        var finished = session
        finished.actualFinish = max(session.actualStart ?? session.date, finishDate)
        let minutes = Int(ceil(finishDate.timeIntervalSince(session.actualStart ?? session.date) / 60))
        finished.durationMinutes = max(1, minutes)
        finished.needsDetails = true
        finished.hasSessionDetails = false
        return TennisRecordConflictResolver.prepareLocalTraining(finished, now: finishDate)
    }

    static func match(player: PlayerProfile, kind: MatchKind, tournament: TournamentRecord? = nil, startDate: Date = Date()) -> MatchRecord {
        var match = MatchRecord(playerID: player.id)
        match.date = startDate
        match.hasStartTime = true
        match.status = .inProgress
        match.matchType = kind
        match.playerName = player.displayName
        match.opponentName = "Opponent"
        match.matchFormat = player.defaultMatchFormat
        match.sightLevel = player.sightLevel
        match.allowedBounces = player.bounceAllowance ?? player.sightLevel.allowedBounces
        match.suddenDeathDeuce = player.playerMode == .blindTennis
        match.tournamentID = tournament?.id
        match.venueID = tournament?.venueID
        match.venue = tournament?.venue ?? ""
        match.location = tournament?.location ?? ""
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
        var scores = score.completedSetScores
        if score.playerGames != 0 || score.opponentGames != 0 { scores.append("\(score.playerGames)-\(score.opponentGames)") }
        finished.setScores = scores.joined(separator: ", ")
        if score.playerSets != score.opponentSets { finished.result = score.playerSets > score.opponentSets ? .win : .loss }
        else if score.playerGames != score.opponentGames { finished.result = score.playerGames > score.opponentGames ? .win : .loss }
        else { finished.result = .draw }
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
