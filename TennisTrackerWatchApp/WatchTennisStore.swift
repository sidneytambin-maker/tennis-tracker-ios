import Foundation
import WatchConnectivity
#if os(watchOS)
import WatchKit
#endif

@MainActor
final class WatchTennisStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot = TennisWatchSnapshot.empty
    @Published var activeTraining: TrainingSession?
    @Published var activeMatch: MatchRecord?
    @Published var scoreState = TennisScoreState()
    @Published var lastAnnouncement = "Tennis Tracker ready."

    private let snapshotKey = "snapshotData"
    private let commandKey = "commandData"
    private let localSnapshotKey = "watchSnapshot"
    private let queuedCommandsKey = "queuedWatchCommands"
    private var queuedCommands: [TennisWatchSyncCommand] = []

    override init() {
        super.init()
        loadLocalState()
    }

    var selectedPlayer: PlayerProfile? {
        if let id = snapshot.selectedPlayerID {
            return snapshot.players.first { $0.id == id } ?? snapshot.players.first
        }
        return snapshot.players.first
    }

    var upcomingTournament: TournamentRecord? {
        snapshot.tournaments
            .filter { !$0.isCompleted }
            .sorted { $0.date < $1.date }
            .first
    }

    var needsDetailsCount: Int {
        snapshot.matches.filter(\.needsDetails).count
        + snapshot.trainingSessions.filter(\.needsDetails).count
        + snapshot.tournaments.filter(\.needsDetails).count
    }

    var recentSummary: [String] {
        let matches = snapshot.matches.prefix(3).map { "Match, \($0.status.rawValue), \($0.opponentSummary.fallback("opponent not recorded"))" }
        let training = snapshot.trainingSessions.prefix(3).map { "Training, \($0.durationMinutes.durationText), \($0.focus.fallback("focus not recorded"))" }
        return Array((matches + training).prefix(5))
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        send(.requestSnapshot)
    }

    func trackTrainingSession() {
        guard let playerID = selectedPlayer?.id else {
            announce("Set up a player on iPhone first.")
            return
        }
        let session = TennisWatchActivityFactory.trainingSession(playerID: playerID)
        activeTraining = session
        mergeTraining(session)
        send(.upsertTraining(session))
        haptic(.start)
        announce("Training session tracking started.")
    }

    func finishTrainingSession() {
        guard let activeTraining else {
            announce("No training session in progress.")
            return
        }
        let finished = TennisWatchActivityFactory.finishTrainingSession(activeTraining)
        self.activeTraining = nil
        mergeTraining(finished)
        send(.upsertTraining(finished))
        haptic(.success)
        announce("Finished training session. Complete details on iPhone when ready.")
    }

    func recordMatch(kind: MatchKind, tournament: TournamentRecord? = nil) {
        guard let player = selectedPlayer else {
            announce("Set up a player on iPhone first.")
            return
        }
        let match = TennisWatchActivityFactory.match(player: player, kind: kind, tournament: tournament)
        activeMatch = match
        scoreState = TennisScoreState(snapshot: match.liveScore ?? TennisScoreState().snapshot)
        mergeMatch(match)
        send(.upsertMatch(match))
        haptic(.start)
        announce("Match scoring ready.")
    }

    func trackTournament() {
        guard let playerID = selectedPlayer?.id else {
            announce("Set up a player on iPhone first.")
            return
        }
        let tournament = TennisWatchActivityFactory.tournament(playerID: playerID)
        mergeTournament(tournament)
        send(.upsertTournament(tournament))
        haptic(.success)
        announce("Tournament created. Complete tournament details on iPhone.")
    }

    func resume(_ match: MatchRecord) {
        activeMatch = match
        scoreState = TennisScoreState(snapshot: match.liveScore ?? TennisScoreState().snapshot)
        announce("Resumed match scoring.")
    }

    func recordPoint(_ winner: PointWinner) {
        guard var match = activeMatch else {
            announce("No match in progress.")
            return
        }
        var scorer = scoringEngine(for: match)
        let message = scorer.awardPoint(to: winner)
        scoreState = scorer.state
        match.liveScore = scoreState.snapshot
        match.status = scoreState.isMatchComplete ? .completed : .inProgress
        match.yourSetsWon = scoreState.playerSets
        match.opponentSetsWon = scoreState.opponentSets
        match.setScores = scoreState.completedSetScores.joined(separator: ", ")
        if scoreState.isMatchComplete {
            match = TennisWatchActivityFactory.finishMatch(match, score: scoreState)
            activeMatch = nil
        } else {
            match = TennisRecordConflictResolver.prepareLocalMatch(match)
            activeMatch = match
        }
        mergeMatch(match)
        send(.upsertMatch(match))
        haptic(.click)
        announce(message)
    }

    func undoLastPoint() {
        guard var match = activeMatch else { return }
        var scorer = scoringEngine(for: match)
        lastAnnouncement = scorer.undo()
        scoreState = scorer.state
        match.liveScore = scoreState.snapshot
        match = TennisRecordConflictResolver.prepareLocalMatch(match)
        activeMatch = match
        mergeMatch(match)
        send(.upsertMatch(match))
        haptic(.retry)
    }

    func saveMatchProgress() {
        guard var match = activeMatch else { return }
        match.liveScore = scoreState.snapshot
        match.status = .inProgress
        match = TennisRecordConflictResolver.prepareLocalMatch(match)
        activeMatch = match
        mergeMatch(match)
        send(.upsertMatch(match))
        haptic(.success)
        announce("Saved match progress.")
    }

    func startTieBreak() {
        guard var match = activeMatch else { return }
        var scorer = scoringEngine(for: match)
        lastAnnouncement = scorer.startTieBreak()
        scoreState = scorer.state
        match.liveScore = scoreState.snapshot
        match = TennisRecordConflictResolver.prepareLocalMatch(match)
        activeMatch = match
        mergeMatch(match)
        send(.upsertMatch(match))
        haptic(.click)
    }

    func finishMatch() {
        guard let match = activeMatch else { return }
        let finished = TennisWatchActivityFactory.finishMatch(match, score: scoreState)
        activeMatch = nil
        mergeMatch(finished)
        send(.upsertMatch(finished))
        haptic(.success)
        announce("Finished match. Complete match details on iPhone when ready.")
    }

    func markDetailsComplete() {
        if let match = snapshot.matches.first(where: \.needsDetails) {
            send(.markMatchDetailsComplete(match.id))
            announce("Marked match details complete.")
            return
        }
        if let session = snapshot.trainingSessions.first(where: \.needsDetails) {
            send(.markTrainingDetailsComplete(session.id))
            announce("Marked training details complete.")
            return
        }
        if let tournament = snapshot.tournaments.first(where: \.needsDetails) {
            send(.markTournamentDetailsComplete(tournament.id))
            announce("Marked tournament details complete.")
        }
    }

    func send(_ command: TennisWatchSyncCommand) {
        queuedCommands.append(command)
        persistQueue()
        flushQueue()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.flushQueue() }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor in self.applySnapshotData(messageData) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[snapshotKey] as? Data else { return }
        Task { @MainActor in self.applySnapshotData(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[snapshotKey] as? Data else { return }
        Task { @MainActor in self.applySnapshotData(data) }
    }

    private func scoringEngine(for match: MatchRecord) -> TennisScoringEngine {
        TennisScoringEngine(
            playerName: match.playerName,
            opponentName: match.opponentSummary,
            suddenDeathDeuce: match.suddenDeathDeuce,
            tieBreakRule: match.tieBreakRule,
            tieBreakTarget: match.tieBreakTarget,
            tieBreakWinByTwo: match.tieBreakWinByTwo,
            setsNeededToWin: match.matchFormat.setsNeededToWin,
            snapshot: scoreState.snapshot
        )
    }

    private func flushQueue() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let pending = queuedCommands
        queuedCommands.removeAll()
        persistQueue()
        for command in pending {
            guard let data = try? JSONEncoder.tennisTracker.encode(command) else { continue }
            if session.isReachable {
                session.sendMessageData(data, replyHandler: nil)
            } else {
                session.transferUserInfo([commandKey: data])
            }
        }
    }

    private func applySnapshotData(_ data: Data) {
        guard let incoming = try? JSONDecoder.tennisTracker.decode(TennisWatchSnapshot.self, from: data) else { return }
        snapshot = incoming
        if activeMatch == nil {
            activeMatch = incoming.matches.first { $0.status == MatchStatus.inProgress && $0.liveScore != nil }
            if let activeMatch {
                scoreState = TennisScoreState(snapshot: activeMatch.liveScore ?? TennisScoreState().snapshot)
            }
        }
        persistSnapshot()
    }

    private func mergeMatch(_ match: MatchRecord) {
        snapshot.matches.removeAll { $0.id == match.id }
        snapshot.matches.insert(match, at: 0)
        persistSnapshot()
    }

    private func mergeTraining(_ session: TrainingSession) {
        snapshot.trainingSessions.removeAll { $0.id == session.id }
        snapshot.trainingSessions.insert(session, at: 0)
        persistSnapshot()
    }

    private func mergeTournament(_ tournament: TournamentRecord) {
        snapshot.tournaments.removeAll { $0.id == tournament.id }
        snapshot.tournaments.insert(tournament, at: 0)
        persistSnapshot()
    }

    private func announce(_ message: String) {
        lastAnnouncement = message
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    private func haptic(_ type: WatchHaptic) {
        #if os(watchOS)
        let watchType: WKHapticType
        switch type {
        case .start:
            watchType = .start
        case .success:
            watchType = .success
        case .click:
            watchType = .click
        case .retry:
            watchType = .retry
        }
        WKInterfaceDevice.current().play(watchType)
        #else
        _ = type
        #endif
    }

    private func loadLocalState() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: localSnapshotKey),
           let saved = try? JSONDecoder.tennisTracker.decode(TennisWatchSnapshot.self, from: data) {
            snapshot = saved
        }
        if let data = defaults.data(forKey: queuedCommandsKey),
           let saved = try? JSONDecoder.tennisTracker.decode([TennisWatchSyncCommand].self, from: data) {
            queuedCommands = saved
        }
    }

    private func persistSnapshot() {
        guard let data = try? JSONEncoder.tennisTracker.encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: localSnapshotKey)
    }

    private func persistQueue() {
        guard let data = try? JSONEncoder.tennisTracker.encode(queuedCommands) else { return }
        UserDefaults.standard.set(data, forKey: queuedCommandsKey)
    }
}

private enum WatchHaptic {
    case start
    case success
    case click
    case retry
}
