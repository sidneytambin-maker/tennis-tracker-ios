import Foundation
import Accessibility
import WidgetKit
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
    @Published var lastSyncStatus = "Waiting for iPhone data."
    @Published var page: TennisWatchPage = .today
    @Published var completedTraining: TrainingSession?
    @Published var activeTournamentID: UUID?
    let healthClient = WatchHealthWorkout()
    lazy var workoutCoordinator = TennisWorkoutCoordinator(client: healthClient)
    @Published var workoutMessage = ""
    @Published var isPreparingWorkout = false
    @Published var isFinishingWorkout = false

    private let snapshotKey = "snapshotData"
    private let commandKey = "commandData"
    private let localSnapshotKey = "watchSnapshot"
    private let queuedCommandsKey = "queuedWatchCommands"
    private var queuedCommands: [TennisWatchSyncCommand] = []
    private var pointHistory: [TennisScoreSnapshot] = []

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
        let matches = snapshot.matches.prefix(3).map { TennisSummaryFormatter.match($0, tournaments: snapshot.tournaments, style: .short) }
        let training = snapshot.trainingSessions.prefix(3).map { TennisSummaryFormatter.training($0, style: .short) }
        return Array((matches + training).prefix(5))
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        send(.requestSnapshot)
    }

    func trackTrainingSession(type: TrainingType = .singlesPractice, context: TennisActivityContext = TennisActivityContext(), venue: String = "", location: String = "", useHealth: Bool = false) {
        guard let playerID = selectedPlayer?.id else {
            announce("Set up a player on iPhone first.")
            return
        }
        guard activeTraining == nil && !isFinishingWorkout else { page = .live; return }
        var session = TennisWatchActivityFactory.trainingSession(playerID: playerID, type: type)
        session.context = context
        session.venue = venue
        session.location = location
        healthClient.clearMetrics()
        activeTraining = session
        completedTraining = nil
        page = .live
        mergeTraining(session)
        send(.upsertTraining(session))
        haptic(.start)
        announce("\(type.rawValue) tracking started.")
        isPreparingWorkout = true
        Task {
            await workoutCoordinator.start(useHealth: useHealth, at: session.actualStart ?? session.date)
            isPreparingWorkout = false
            workoutMessage = workoutCoordinator.message
            if useHealth { announce(workoutMessage) }
        }
    }

    func finishTrainingSession() {
        guard !isPreparingWorkout else { announce("Waiting for the Health permission response."); return }
        guard let activeTraining else {
            announce("No training session in progress.")
            return
        }
        let finishDate = Date()
        let finished = TennisWatchActivityFactory.finishTrainingSession(activeTraining, finishDate: finishDate)
        self.activeTraining = nil
        completedTraining = finished
        mergeTraining(finished)
        send(.upsertTraining(finished))
        haptic(.success)
        announce("Finished training session. Complete details on iPhone when ready.")
        isFinishingWorkout = true
        Task {
            defer { isFinishingWorkout = false }
            if let result = await workoutCoordinator.finish(at: finishDate) {
                var updated = snapshot.trainingSessions.first(where: { $0.id == finished.id }) ?? finished
                updated.workout = result
                updated = TennisRecordConflictResolver.prepareLocalTraining(updated)
                completedTraining = updated
                mergeTraining(updated)
                send(.upsertTraining(updated))
                workoutMessage = workoutCoordinator.message
                announce(TennisSummaryFormatter.training(updated, style: .detailed) + " " + workoutMessage)
            }
        }
    }

    func recordMatch(kind: MatchKind, tournament: TournamentRecord? = nil) {
        guard let player = selectedPlayer else {
            announce("Set up a player on iPhone first.")
            return
        }
        let match = TennisWatchActivityFactory.match(player: player, kind: kind, tournament: tournament)
        pointHistory = []
        persistPointHistory()
        activeMatch = match
        page = .score
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
        if activeMatch?.id != match.id || activeMatch?.liveScore != match.liveScore {
            pointHistory = []
            persistPointHistory()
        }
        activeMatch = match
        page = .score
        scoreState = TennisScoreState(snapshot: match.liveScore ?? TennisScoreState().snapshot)
        announce("Resumed match scoring.")
    }

    func beginMatch(_ match: MatchRecord) {
        var match = match
        match.status = .inProgress
        match.liveScore = match.liveScore ?? TennisScoreState().snapshot
        match = TennisRecordConflictResolver.prepareLocalMatch(match)
        mergeMatch(match)
        send(.upsertMatch(match))
        resume(match)
    }

    func beginTraining(_ planned: TrainingSession, useHealth: Bool = false) {
        guard activeTraining == nil && !isFinishingWorkout else { page = .live; return }
        healthClient.clearMetrics()
        var session = planned
        session.actualStart = Date()
        session.actualFinish = nil
        session = TennisRecordConflictResolver.prepareLocalTraining(session)
        activeTraining = session
        completedTraining = nil
        mergeTraining(session)
        send(.upsertTraining(session))
        page = .live
        haptic(.start)
        announce("Training started.")
        isPreparingWorkout = true
        Task {
            await workoutCoordinator.start(useHealth: useHealth, at: session.actualStart ?? session.date)
            isPreparingWorkout = false
            workoutMessage = workoutCoordinator.message
            if useHealth { announce(workoutMessage) }
        }
    }

    func beginTournament(_ tournament: TournamentRecord) {
        var tournament = tournament
        tournament.finalResult = .inProgress
        tournament = TennisRecordConflictResolver.prepareLocalTournament(tournament)
        activeTournamentID = tournament.id
        UserDefaults.standard.set(tournament.id.uuidString, forKey: "activeTournamentID")
        mergeTournament(tournament)
        send(.upsertTournament(tournament))
        page = .live
    }

    func finishTournament() {
        guard var tournament = snapshot.tournaments.first(where: { $0.id == activeTournamentID }) else { return }
        tournament.finalResult = .completed
        tournament = TennisRecordConflictResolver.prepareLocalTournament(tournament)
        mergeTournament(tournament)
        send(.upsertTournament(tournament))
        activeTournamentID = nil
        UserDefaults.standard.removeObject(forKey: "activeTournamentID")
        announce("Tournament tracking finished.")
    }

    func savePracticeResult(_ result: TennisPracticeResult) {
        guard var training = completedTraining else { return }
        training.practiceResult = result
        training = TennisRecordConflictResolver.prepareLocalTraining(training)
        completedTraining = training
        mergeTraining(training)
        send(.upsertTraining(training))
        announce("Saved practice result with training.")
    }

    func recordPoint(_ winner: PointWinner) {
        guard var match = activeMatch else {
            announce("No match in progress.")
            return
        }
        var scorer = scoringEngine(for: match)
        pointHistory.append(scoreState.snapshot)
        persistPointHistory()
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
        guard let previous = pointHistory.popLast() else { announce("No point available to undo."); return }
        scoreState = TennisScoreState(snapshot: previous)
        persistPointHistory()
        match.liveScore = scoreState.snapshot
        match.yourSetsWon = scoreState.playerSets
        match.opponentSetsWon = scoreState.opponentSets
        match.setScores = scoreState.completedSetScores.joined(separator: ", ")
        match = TennisRecordConflictResolver.prepareLocalMatch(match)
        activeMatch = match
        mergeMatch(match)
        send(.upsertMatch(match))
        haptic(.retry)
        announce("Point undone. " + scoreState.spokenScore(playerName: match.playerTeam, opponentName: match.opponentSummary, suddenDeathDeuce: match.suddenDeathDeuce))
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
        guard !scoreState.isMatchComplete && !scoreState.isTiebreak else { return }
        var scorer = scoringEngine(for: match)
        pointHistory.append(scoreState.snapshot)
        persistPointHistory()
        announce(scorer.startTieBreak())
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
        if let id = command.recordID { queuedCommands.removeAll { $0.recordID == id } }
        queuedCommands.append(command)
        persistQueue()
        flushQueue()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let received = session.receivedApplicationContext["snapshotData"] as? Data
        Task { @MainActor in
            if let received { self.applySnapshotData(received) }
            self.flushQueue()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in self.send(.requestSnapshot) }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        guard error != nil, let data = userInfoTransfer.userInfo["commandData"] as? Data,
              let command = try? JSONDecoder.tennisTracker.decode(TennisWatchSyncCommand.self, from: data) else { return }
        Task { @MainActor in
            self.queuedCommands.append(command)
            self.persistQueue()
            self.lastSyncStatus = "Saved on Watch. Waiting to sync with iPhone."
        }
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
            playerName: match.playerTeam,
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
        queuedCommands.removeAll { $0.recordID == nil }
        persistQueue()
        for command in pending {
            guard let data = try? JSONEncoder.tennisTracker.encode(command) else { continue }
            if session.isReachable {
                session.sendMessageData(data, replyHandler: nil, errorHandler: { _ in
                    session.transferUserInfo(["commandData": data])
                })
            } else {
                session.transferUserInfo([commandKey: data])
            }
        }
    }

    private func applySnapshotData(_ data: Data) {
        guard let incoming = try? JSONDecoder.tennisTracker.decode(TennisWatchSnapshot.self, from: data) else { return }
        let previousMatch = activeMatch
        let result = TennisWatchReconciliation.reconcile(incoming: incoming, pending: queuedCommands)
        snapshot = result.snapshot
        queuedCommands = result.pending
        persistQueue()
        lastSyncStatus = "Updated from iPhone at \(Date().formatted(date: .omitted, time: .shortened))."
        send(.snapshotReceived(incoming.generatedAt))
        if let id = activeMatch?.id {
            activeMatch = snapshot.matches.first { $0.id == id && $0.status == .inProgress }
        } else {
            activeMatch = snapshot.matches.first { $0.status == MatchStatus.inProgress && $0.liveScore != nil }
        }
        activeTraining = snapshot.trainingSessions.first(where: \.isActive)
        if previousMatch?.id != activeMatch?.id || previousMatch?.liveScore != activeMatch?.liveScore {
            pointHistory = []
            persistPointHistory()
        }
        if let id = completedTraining?.id {
            completedTraining = snapshot.trainingSessions.first { $0.id == id }
        }
        if let id = activeTournamentID, !snapshot.tournaments.contains(where: { $0.id == id && $0.finalResult == .inProgress }) {
            activeTournamentID = nil
            UserDefaults.standard.removeObject(forKey: "activeTournamentID")
        }
        if activeMatch != nil {
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

    func announce(_ message: String) {
        lastAnnouncement = message
        #if os(watchOS)
        AccessibilityNotification.Announcement(message).post()
        #endif
    }

    private func haptic(_ type: WatchHaptic) {
        guard snapshot.settings.hapticsEnabled else { return }
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
        if let data = defaults.data(forKey: "pointHistory"), let history = try? JSONDecoder.tennisTracker.decode([TennisScoreSnapshot].self, from: data) { pointHistory = history }
        activeTournamentID = defaults.string(forKey: "activeTournamentID").flatMap(UUID.init(uuidString:))
        if let data = defaults.data(forKey: localSnapshotKey),
           let saved = try? JSONDecoder.tennisTracker.decode(TennisWatchSnapshot.self, from: data) {
            snapshot = saved
            activeTraining = saved.trainingSessions.first(where: \.isActive)
            activeMatch = saved.matches.first { $0.status == .inProgress && $0.liveScore != nil }
            if let activeMatch { scoreState = TennisScoreState(snapshot: activeMatch.liveScore ?? TennisScoreState().snapshot) }
            lastSyncStatus = "Saved iPhone data available."
        }
        if let data = defaults.data(forKey: queuedCommandsKey),
           let saved = try? JSONDecoder.tennisTracker.decode([TennisWatchSyncCommand].self, from: data) {
            queuedCommands = saved
        }
    }

    private func persistSnapshot() {
        guard let data = try? JSONEncoder.tennisTracker.encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: localSnapshotKey)
        do {
            try TennisSharedSnapshotFile.write(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch { lastSyncStatus = "Saved on Watch. Complication update could not be saved." }
    }

    private func persistQueue() {
        guard let data = try? JSONEncoder.tennisTracker.encode(queuedCommands) else { return }
        UserDefaults.standard.set(data, forKey: queuedCommandsKey)
    }

    private func persistPointHistory() {
        if let data = try? JSONEncoder.tennisTracker.encode(pointHistory) { UserDefaults.standard.set(data, forKey: "pointHistory") }
    }
}

private enum WatchHaptic {
    case start
    case success
    case click
    case retry
}
