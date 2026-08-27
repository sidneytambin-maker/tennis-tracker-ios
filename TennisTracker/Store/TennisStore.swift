import Foundation

@MainActor
final class TennisStore: ObservableObject {
    @Published private(set) var data = AppData()
    @Published var lastAnnouncement = "Tennis Tracker ready."

    private let storeURL: URL

    init(storeURL: URL? = nil) {
        if let storeURL {
            self.storeURL = storeURL
        } else {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("TennisTracker", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.storeURL = directory.appendingPathComponent("tennis-tracker-data.json")
        }
        load()
        seedIfNeeded()
    }

    var selectedPlayer: PlayerProfile? {
        guard let id = data.selectedPlayerID else { return data.players.first }
        return data.players.first { $0.id == id } ?? data.players.first
    }

    var selectedPlayerID: UUID? {
        selectedPlayer?.id
    }

    var selectedMatches: [MatchRecord] {
        guard let id = selectedPlayerID else { return [] }
        return data.matches.filter { $0.playerID == id }.sorted { $0.date > $1.date }
    }

    var selectedTraining: [TrainingSession] {
        guard let id = selectedPlayerID else { return [] }
        return data.trainingSessions.filter { $0.playerID == id }.sorted { $0.date > $1.date }
    }

    var selectedTournaments: [TournamentRecord] {
        guard let id = selectedPlayerID else { return [] }
        return data.tournaments.filter { $0.playerID == id }.sorted { $0.date > $1.date }
    }

    func selectPlayer(_ player: PlayerProfile) {
        data.selectedPlayerID = player.id
        saveAndAnnounce("Selected \(player.displayName).")
    }

    func upsertPlayer(_ player: PlayerProfile) {
        upsert(player, in: \.players)
        if data.selectedPlayerID == nil {
            data.selectedPlayerID = player.id
        }
        saveAndAnnounce("Saved player \(player.displayName).")
    }

    func deletePlayer(_ player: PlayerProfile) {
        data.players.removeAll { $0.id == player.id }
        data.matches.removeAll { $0.playerID == player.id }
        data.trainingSessions.removeAll { $0.playerID == player.id }
        data.tournaments.removeAll { $0.playerID == player.id }
        data.selectedPlayerID = data.players.first?.id
        saveAndAnnounce("Deleted player \(player.displayName) and their saved activity.")
    }

    func upsertMatch(_ match: MatchRecord) {
        upsert(match, in: \.matches)
        saveAndAnnounce("Saved match against \(match.opponentSummary.fallback("opponent not recorded")).")
    }

    func deleteMatch(_ match: MatchRecord) {
        data.matches.removeAll { $0.id == match.id }
        saveAndAnnounce("Deleted match.")
    }

    func upsertTraining(_ session: TrainingSession) {
        upsert(session, in: \.trainingSessions)
        saveAndAnnounce("Saved training at \(session.placeText).")
    }

    func deleteTraining(_ session: TrainingSession) {
        data.trainingSessions.removeAll { $0.id == session.id }
        saveAndAnnounce("Deleted training session.")
    }

    func upsertTournament(_ tournament: TournamentRecord) {
        upsert(tournament, in: \.tournaments)
        saveAndAnnounce("Saved tournament \(tournament.name.fallback("unnamed tournament")).")
    }

    func deleteTournament(_ tournament: TournamentRecord) {
        data.tournaments.removeAll { $0.id == tournament.id }
        data.matches = data.matches.map { match in
            var copy = match
            if copy.tournamentID == tournament.id {
                copy.tournamentID = nil
            }
            return copy
        }
        saveAndAnnounce("Deleted tournament.")
    }

    func updateSettings(_ settings: AppSettings) {
        data.settings = settings
        saveAndAnnounce("Saved settings.")
    }

    func announce(_ message: String) {
        lastAnnouncement = message
    }

    private func upsert<T: Identifiable & Equatable>(_ item: T, in keyPath: WritableKeyPath<AppData, [T]>) where T.ID == UUID {
        if let index = data[keyPath: keyPath].firstIndex(where: { $0.id == item.id }) {
            data[keyPath: keyPath][index] = item
        } else {
            data[keyPath: keyPath].append(item)
        }
    }

    private func saveAndAnnounce(_ message: String) {
        save()
        announce(message)
    }

    private func load() {
        guard let savedData = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder.tennisTracker.decode(AppData.self, from: savedData) else {
            return
        }
        data = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder.tennisTracker.encode(data) else { return }
        try? encoded.write(to: storeURL, options: [.atomic])
    }

    private func seedIfNeeded() {
        guard data.players.isEmpty else { return }
        var player = PlayerProfile()
        player.name = "Player One"
        player.preferredName = "Player One"
        player.bCategory = "B1"
        player.sightLevel = .b1
        player.primaryGoal = "Build consistent match and training records."
        data.players = [player]
        data.selectedPlayerID = player.id
        data.trainingSessions = [
            TrainingSession(playerID: player.id, durationMinutes: 60, location: "Home club", venue: "Indoor court", focus: "Serve rhythm", sessionOutcome: "Good rhythm and clearer targets")
        ]
        var match = MatchRecord(playerID: player.id)
        match.opponentName = "Practice opponent"
        match.result = .win
        match.nextPracticeFocus = "Return position"
        match.courtSurface = "Hard"
        match.matchStrengths = "Serve placement"
        match.yourSetsWon = 2
        match.opponentSetsWon = 1
        match.setScores = "6-4, 4-6, 10-8"
        match.hadTiebreak = true
        match.tiebreakScore = "10-8"
        data.matches = [match]
        save()
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
