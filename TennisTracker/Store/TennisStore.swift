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
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-store") {
            try? FileManager.default.removeItem(at: self.storeURL)
        }
        load()
        migrateIfNeeded()
    }

    var needsOnboarding: Bool {
        data.players.isEmpty
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
        var saved = TennisRecordConflictResolver.prepareLocalMatch(match)
        if saved.playerName.isBlank {
            saved.playerName = selectedPlayer?.displayName ?? "Player"
        }
        if saved.allowedBounces == 0 {
            saved.allowedBounces = saved.sightLevel.allowedBounces
        }
        if saved.status == .completed {
            saved.liveScore = nil
        }
        upsert(saved, in: \.matches)
        saveAndAnnounce("Saved match against \(match.opponentSummary.fallback("opponent not recorded")).")
    }

    func deleteMatch(_ match: MatchRecord) {
        data.matches.removeAll { $0.id == match.id }
        saveAndAnnounce("Deleted match.")
    }

    func upsertTraining(_ session: TrainingSession) {
        let saved = TennisRecordConflictResolver.prepareLocalTraining(session)
        upsert(saved, in: \.trainingSessions)
        saveAndAnnounce("Saved training at \(session.placeText).")
    }

    func deleteTraining(_ session: TrainingSession) {
        data.trainingSessions.removeAll { $0.id == session.id }
        saveAndAnnounce("Deleted training session.")
    }

    func upsertTournament(_ tournament: TournamentRecord) {
        let saved = TennisRecordConflictResolver.prepareLocalTournament(tournament)
        upsert(saved, in: \.tournaments)
        saveAndAnnounce("Saved tournament \(tournament.name.fallback("unnamed tournament")).")
    }

    func linkedMatches(for tournament: TournamentRecord) -> [MatchRecord] {
        data.matches
            .filter { $0.playerID == tournament.playerID && $0.tournamentID == tournament.id }
            .sorted { $0.date > $1.date }
    }

    func deleteTournamentKeepingMatches(_ tournament: TournamentRecord) {
        data.tournaments.removeAll { $0.id == tournament.id }
        data.matches = data.matches.map { match in
            var copy = match
            if copy.tournamentID == tournament.id {
                copy.tournamentID = nil
            }
            return copy
        }
        saveAndAnnounce("Deleted tournament and kept linked matches.")
    }

    func deleteTournamentAndLinkedMatches(_ tournament: TournamentRecord) {
        data.tournaments.removeAll { $0.id == tournament.id }
        data.matches.removeAll { $0.tournamentID == tournament.id }
        saveAndAnnounce("Deleted tournament and linked matches.")
    }

    func deleteTournament(_ tournament: TournamentRecord) {
        deleteTournamentKeepingMatches(tournament)
    }

    func updateSettings(_ settings: AppSettings) {
        var saved = settings
        saved.announceScores = settings.scoreAnnouncementMode != .off
        data.settings = saved
        saveAndAnnounce("Saved settings.")
    }

    func completeMatchDetails(_ id: UUID) {
        guard let index = data.matches.firstIndex(where: { $0.id == id }) else { return }
        data.matches[index].needsDetails = false
        data.matches[index] = TennisRecordConflictResolver.prepareLocalMatch(data.matches[index])
        saveAndAnnounce("Marked match details complete.")
    }

    func completeTrainingDetails(_ id: UUID) {
        guard let index = data.trainingSessions.firstIndex(where: { $0.id == id }) else { return }
        data.trainingSessions[index].needsDetails = false
        data.trainingSessions[index].hasSessionDetails = true
        data.trainingSessions[index] = TennisRecordConflictResolver.prepareLocalTraining(data.trainingSessions[index])
        saveAndAnnounce("Marked training details complete.")
    }

    func completeTournamentDetails(_ id: UUID) {
        guard let index = data.tournaments.firstIndex(where: { $0.id == id }) else { return }
        data.tournaments[index].needsDetails = false
        data.tournaments[index] = TennisRecordConflictResolver.prepareLocalTournament(data.tournaments[index])
        saveAndAnnounce("Marked tournament details complete.")
    }

    func applyWatchCommand(_ command: TennisWatchSyncCommand) {
        switch command {
        case .requestSnapshot:
            save()
            announce("Apple Watch sync refreshed.")
        case .upsertMatch(let match):
            mergeWatchMatch(match)
            saveAndAnnounce("Synced match from Apple Watch.")
        case .upsertTraining(let session):
            mergeWatchTraining(session)
            saveAndAnnounce("Synced training from Apple Watch.")
        case .upsertTournament(let tournament):
            mergeWatchTournament(tournament)
            saveAndAnnounce("Synced tournament from Apple Watch.")
        case .markMatchDetailsComplete(let id):
            completeMatchDetails(id)
        case .markTrainingDetailsComplete(let id):
            completeTrainingDetails(id)
        case .markTournamentDetailsComplete(let id):
            completeTournamentDetails(id)
        }
    }

    func makeDefaultMatch(tournamentID: UUID? = nil) -> MatchRecord? {
        guard let player = selectedPlayer else { return nil }
        var match = MatchRecord(playerID: player.id)
        match.playerName = player.displayName
        match.matchType = data.settings.defaultMatchType
        match.sightLevel = player.sightLevel
        match.allowedBounces = player.sightLevel.allowedBounces
        match.suddenDeathDeuce = player.playerMode == .blindTennis
        match.tournamentID = tournamentID
        if let tournamentID, let tournament = data.tournaments.first(where: { $0.id == tournamentID }) {
            match.date = tournament.date
            match.hasStartTime = tournament.hasStartTime && !tournament.isAllDay
            match.venue = tournament.location
            match.sightLevel = sightLevel(from: tournament.category) ?? player.sightLevel
            match.allowedBounces = match.sightLevel.allowedBounces
            match.matchPosition = tournament.format == .roundRobin ? .roundRobin : .notSpecified
        }
        match.courtSurface = player.preferredSurface.isBlank ? .notSpecified : CourtSurface(rawValue: player.preferredSurface) ?? .notSpecified
        return match
    }

    func resumableMatches() -> [MatchRecord] {
        selectedMatches.filter { $0.status == .inProgress && $0.liveScore != nil }
    }

    func makeDefaultTournament() -> TournamentRecord? {
        guard let player = selectedPlayer else { return nil }
        var tournament = TournamentRecord(playerID: player.id)
        tournament.category = player.bCategory
        return tournament
    }

    func makeDefaultTraining() -> TrainingSession? {
        guard let player = selectedPlayer else { return nil }
        return TrainingSession(playerID: player.id)
    }

    func completeOnboarding(player: PlayerProfile, settings: AppSettings) {
        data = AppData()
        data.dataVersion = 8
        data.players = [player]
        data.selectedPlayerID = player.id
        data.settings = settings
        saveAndAnnounce("Set up \(player.displayName).")
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

    private func mergeWatchMatch(_ incoming: MatchRecord) {
        guard let index = data.matches.firstIndex(where: { $0.id == incoming.id }) else {
            data.matches.append(incoming)
            return
        }
        let existing = data.matches[index]
        if TennisRecordConflictResolver.shouldReplace(
            incomingRevision: incoming.revision,
            incomingModifiedAt: incoming.modifiedAt,
            existingRevision: existing.revision,
            existingModifiedAt: existing.modifiedAt
        ) {
            data.matches[index] = incoming
        }
    }

    private func mergeWatchTraining(_ incoming: TrainingSession) {
        guard let index = data.trainingSessions.firstIndex(where: { $0.id == incoming.id }) else {
            data.trainingSessions.append(incoming)
            return
        }
        let existing = data.trainingSessions[index]
        if TennisRecordConflictResolver.shouldReplace(
            incomingRevision: incoming.revision,
            incomingModifiedAt: incoming.modifiedAt,
            existingRevision: existing.revision,
            existingModifiedAt: existing.modifiedAt
        ) {
            data.trainingSessions[index] = incoming
        }
    }

    private func mergeWatchTournament(_ incoming: TournamentRecord) {
        guard let index = data.tournaments.firstIndex(where: { $0.id == incoming.id }) else {
            data.tournaments.append(incoming)
            return
        }
        let existing = data.tournaments[index]
        if TennisRecordConflictResolver.shouldReplace(
            incomingRevision: incoming.revision,
            incomingModifiedAt: incoming.modifiedAt,
            existingRevision: existing.revision,
            existingModifiedAt: existing.modifiedAt
        ) {
            data.tournaments[index] = incoming
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
        Task {
            await TennisNotificationService.shared.rescheduleAll(for: data)
        }
        #if os(iOS)
        IPhoneWatchSyncService.shared.sendSnapshot(data)
        #endif
    }

    private func sightLevel(from category: String) -> SightLevel? {
        let normalized = category.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return nil }
        return SightLevel.allCases.first { $0.rawValue.uppercased().hasPrefix(normalized) }
    }

    private func migrateIfNeeded() {
        if data.dataVersion < 3 {
            data = AppData()
            data.dataVersion = 8
            lastAnnouncement = "Tennis Tracker is ready for first setup."
            save()
            return
        }
        if data.dataVersion < 8 {
            data.dataVersion = 8
            save()
        }
    }
}
