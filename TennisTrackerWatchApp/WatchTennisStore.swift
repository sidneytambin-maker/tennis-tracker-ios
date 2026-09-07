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
    private var isRestoringWorkout = false

    override init() {
        super.init()
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-watch") {
            var data = AppData()
            var player = PlayerProfile(); player.name = "Alex"
            data.players = [player]
            data.setup.coaches = [TennisCoach(name: "Chris"), TennisCoach(name: "Sarah")]
            data.selectedPlayerID = player.id
            if ProcessInfo.processInfo.arguments.contains("-watch-scheduled-training") {
                var training = TrainingSession(playerID: player.id)
                training.date = Date().addingTimeInterval(600)
                training.hasStartTime = true
                training.context.coachIDs = [data.setup.coaches[0].id]
                data.trainingSessions = [training]
                UserDefaults.standard.set(false, forKey: "trackTrainingAsWorkout")
            }
            if ProcessInfo.processInfo.arguments.contains("-watch-completed-training") {
                var training = TrainingSession(playerID: player.id)
                training.actualStart = Date(timeIntervalSince1970: 1000)
                training.actualFinish = Date(timeIntervalSince1970: 1159)
                training.durationMinutes = 3
                training.needsDetails = true
                training.workout = TennisWorkoutResult(durationSeconds: 159, averageHeartRate: 72, activeEnergyKcal: 4,
                    peakHeartRate: 90, distanceMeters: 123, stepCount: 201)
                data.trainingSessions = [training]
                completedTraining = training
            }
            if ProcessInfo.processInfo.arguments.contains("-watch-active-match") {
                var match = MatchRecord(playerID: player.id)
                match.playerName = "Alex"
                match.opponentName = "Sam"
                match.actualStart = Date()
                match.status = .inProgress
                match.liveScore = scoreState.snapshot
                data.matches = [match]
                activeMatch = match
            }
            snapshot = TennisWatchSnapshot(data: data)
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-watch-page=") }),
               let destination = TennisWatchPage(rawValue: String(argument.dropFirst("-watch-page=".count))) { page = destination }
            return
        }
        #endif
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
        let training = snapshot.trainingSessions.prefix(3).map { trainingSummary($0, style: .short) }
        return Array((matches + training).prefix(5))
    }

    func trainingSummary(_ session: TrainingSession, style: TennisSummaryStyle = .long, now: Date = Date()) -> String {
        TennisSummaryFormatter.training(session, style: style, now: now, coaches: snapshot.setup.coaches, players: snapshot.players)
    }

    func activate() {
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-watch") { return }
        #endif
        persistSnapshot()
        restoreWorkoutIfNeeded()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        send(.requestSnapshot)
    }

    func sendHealthStatus() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let status = TennisWatchHealthStatus(access: healthClient.accessDescription,
            enabledByDefault: UserDefaults.standard.bool(forKey: "trackTrainingAsWorkout"), reportedAt: Date())
        guard let data = try? JSONEncoder.tennisTracker.encode(status) else { return }
        try? WCSession.default.updateApplicationContext(["healthStatusData": data])
    }

    func trackTrainingSession(type: TrainingType = .singlesPractice, context: TennisActivityContext = TennisActivityContext(), venue: String = "", location: String = "", useHealth: Bool = false) {
        guard let playerID = selectedPlayer?.id else {
            announce("Set up a player on iPhone first.")
            return
        }
        guard activeTraining == nil && !isPreparingWorkout && !isRestoringWorkout && !isFinishingWorkout else { page = .live; return }
        var session = TennisWatchActivityFactory.trainingSession(playerID: playerID, type: type)
        session.context = context
        session.venue = venue
        session.location = location
        healthClient.clearMetrics()
        workoutMessage = useHealth ? "Requesting Health workout access." : "Training started."
        activeTraining = session
        completedTraining = nil
        page = .live
        mergeTraining(session)
        send(.upsertTraining(session))
        haptic(.start)
        announce("\(type.rawValue) tracking started.")
        isPreparingWorkout = true
        Task {
            await workoutCoordinator.start(useHealth: useHealth, activityID: session.id, at: session.actualStart ?? session.date)
            isPreparingWorkout = false
            workoutMessage = workoutCoordinator.message
            if useHealth { announce(workoutMessage) }
            sendHealthStatus()
            finishRemotelyCompletedWorkoutIfNeeded()
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
        announce("Training finished. " + TennisDurationFormatter.training(finished) + ".")
        finishWorkout(for: finished.id, at: finishDate)
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
        guard !snapshot.deletedRecordIDs.contains(match.id) else { announce("This match was deleted."); return }
        var match = match
        if snapshot.matches.contains(where: { $0.id == match.id }) {
            match.actualStart = match.actualStart ?? Date()
        } else { match.actualStart = Date() }
        match.actualFinish = nil
        match.status = .inProgress
        match.liveScore = match.liveScore ?? TennisScoreState().snapshot
        match = TennisRecordConflictResolver.prepareLocalMatch(match)
        mergeMatch(match)
        send(.upsertMatch(match))
        resume(match)
    }

    func beginTraining(_ planned: TrainingSession, useHealth: Bool = false) {
        guard !snapshot.deletedRecordIDs.contains(planned.id), planned.actualStart == nil, planned.actualFinish == nil else {
            announce("This session has already started or was deleted."); return
        }
        guard activeTraining == nil && !isPreparingWorkout && !isRestoringWorkout && !isFinishingWorkout else { page = .live; return }
        healthClient.clearMetrics()
        workoutMessage = useHealth ? "Requesting Health workout access." : "Training started."
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
            await workoutCoordinator.start(useHealth: useHealth, activityID: session.id, at: session.actualStart ?? session.date)
            isPreparingWorkout = false
            workoutMessage = workoutCoordinator.message
            if useHealth { announce(workoutMessage) }
            sendHealthStatus()
            finishRemotelyCompletedWorkoutIfNeeded()
        }
    }

    func restoreWorkoutIfNeeded() {
        sendHealthStatus()
        guard !isRestoringWorkout, !isPreparingWorkout, !isFinishingWorkout else { return }
        isRestoringWorkout = true
        Task {
            defer { isRestoringWorkout = false }
            let tracked = healthClient.activeTrainingID.flatMap { id in snapshot.trainingSessions.first { $0.id == id } } ?? activeTraining
            if let tracked, workoutCoordinator.state == .idle || workoutCoordinator.state == .finished {
                isPreparingWorkout = true
                await workoutCoordinator.restore(activityID: tracked.id, startedAt: tracked.actualStart ?? tracked.date)
                isPreparingWorkout = false
                workoutMessage = workoutCoordinator.message
            } else if let id = healthClient.activeTrainingID, snapshot.deletedRecordIDs.contains(id),
                      workoutCoordinator.state == .idle || workoutCoordinator.state == .finished {
                await workoutCoordinator.restore(activityID: id, startedAt: Date())
            }
            finishRemotelyCompletedWorkoutIfNeeded()
            for id in healthClient.pendingWorkoutIDs {
                guard let training = snapshot.trainingSessions.first(where: { $0.id == id }), training.actualFinish != nil else { continue }
                if training.workout?.workoutID != nil { healthClient.acknowledgeSavedWorkout(id); continue }
                if let result = try? await healthClient.savedWorkout(activityID: id) {
                    attachWorkout(result, to: id)
                    healthClient.acknowledgeSavedWorkout(id)
                }
            }
        }
    }

    private func finishRemotelyCompletedWorkoutIfNeeded() {
        if let id = workoutCoordinator.activityID, snapshot.deletedRecordIDs.contains(id),
           !isPreparingWorkout, !isFinishingWorkout,
           workoutCoordinator.state == .recording || workoutCoordinator.state == .recordingWithoutHealth {
            finishWorkout(for: id, at: Date())
            return
        }
        guard !isPreparingWorkout, !isFinishingWorkout,
              let id = workoutCoordinator.activityID,
              let training = snapshot.trainingSessions.first(where: { $0.id == id }),
              let finishDate = training.actualFinish,
              workoutCoordinator.state == .recording || workoutCoordinator.state == .recordingWithoutHealth else { return }
        finishWorkout(for: id, at: finishDate)
    }

    private func finishWorkout(for id: UUID, at date: Date) {
        guard !isFinishingWorkout else { return }
        isFinishingWorkout = true
        Task {
            defer { isFinishingWorkout = false }
            if let result = await workoutCoordinator.finish(at: date) {
                attachWorkout(result, to: id)
                if result.workoutID != nil { healthClient.acknowledgeSavedWorkout(id) }
            }
            workoutMessage = workoutCoordinator.message
            if let training = snapshot.trainingSessions.first(where: { $0.id == id }) {
                announce(trainingSummary(training, style: .detailed) + " " + workoutMessage)
            }
        }
    }

    private func attachWorkout(_ result: TennisWorkoutResult, to id: UUID) {
        guard var training = snapshot.trainingSessions.first(where: { $0.id == id }) else { return }
        // A delayed save must not replace a previously confirmed Health relationship.
        guard training.workout?.workoutID == nil else { return }
        training.workout = result
        training = TennisRecordConflictResolver.prepareLocalTraining(training)
        if completedTraining?.id == id { completedTraining = training }
        mergeTraining(training)
        send(.upsertTraining(training))
    }

    func beginTournament(_ tournament: TournamentRecord) {
        guard !snapshot.deletedRecordIDs.contains(tournament.id) else { announce("This tournament was deleted."); return }
        guard activeTournamentID == nil || activeTournamentID == tournament.id else { page = .live; return }
        var tournament = tournament
        tournament.actualStart = tournament.actualStart ?? Date()
        tournament.actualFinish = nil
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
        if let start = tournament.actualStart { tournament.actualFinish = max(start, Date()) }
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

    func markTrainingComplete(_ id: UUID) {
        guard var training = snapshot.trainingSessions.first(where: { $0.id == id }) else { return }
        training.markDetailsComplete()
        training = TennisRecordConflictResolver.prepareLocalTraining(training)
        if completedTraining?.id == id { completedTraining = training }
        mergeTraining(training)
        send(.upsertTraining(training))
        announce("Marked complete. Saved on Watch and queued for iPhone.")
    }

    func deleteActivity(_ deletion: TennisRecordDeletion) {
        guard !isPreparingWorkout && !isFinishingWorkout else { announce("Wait for the workout to finish saving."); return }
        if activeTraining?.id == deletion.id {
            activeTraining = nil
            finishWorkout(for: deletion.id, at: Date())
        }
        if completedTraining?.id == deletion.id { completedTraining = nil }
        if activeMatch?.id == deletion.id { activeMatch = nil; pointHistory = []; persistPointHistory() }
        if activeTournamentID == deletion.id {
            activeTournamentID = nil
            UserDefaults.standard.removeObject(forKey: "activeTournamentID")
        }
        snapshot.delete(deletion)
        if let id = activeMatch?.id, snapshot.deletedRecordIDs.contains(id) { activeMatch = nil; pointHistory = []; persistPointHistory() }
        queuedCommands.removeAll {
            if case .deleteRecord = $0 { return false }
            return $0.recordID.map(snapshot.deletedRecordIDs.contains) ?? false
        }
        send(.deleteRecord(deletion))
        persistSnapshot()
        announce("Deleted on Watch. The deletion will sync to iPhone.")
    }

    func updateTrainingDetails(_ draft: TrainingSession) {
        guard let current = snapshot.trainingSessions.first(where: { $0.id == draft.id }) else { return }
        let updated = TennisWatchRecordEdits.training(draft, current: current)
        if activeTraining?.id == updated.id { activeTraining = updated }
        if completedTraining?.id == updated.id { completedTraining = updated }
        mergeTraining(updated); send(.upsertTraining(updated))
        announce("Training details saved on Watch.")
    }

    func updateMatchDetails(_ draft: MatchRecord) {
        guard let current = snapshot.matches.first(where: { $0.id == draft.id }) else { return }
        let updated = TennisWatchRecordEdits.match(draft, current: current)
        if activeMatch?.id == updated.id { activeMatch = updated }
        mergeMatch(updated); send(.upsertMatch(updated))
        announce("Match details saved on Watch.")
    }

    func updateTournamentDetails(_ draft: TournamentRecord) {
        guard let current = snapshot.tournaments.first(where: { $0.id == draft.id }) else { return }
        let updated = TennisWatchRecordEdits.tournament(draft, current: current)
        mergeTournament(updated); send(.upsertTournament(updated))
        announce("Tournament details saved on Watch.")
    }

    func markMatchComplete(_ id: UUID) {
        guard var draft = snapshot.matches.first(where: { $0.id == id }), draft.status == .completed else { return }
        draft.needsDetails = false
        updateMatchDetails(draft)
    }

    func markTournamentComplete(_ id: UUID) {
        guard var draft = snapshot.tournaments.first(where: { $0.id == id }), draft.isCompleted else { return }
        draft.needsDetails = false
        updateTournamentDetails(draft)
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
        page = .recent
        announce(TennisSummaryFormatter.match(finished, tournaments: snapshot.tournaments))
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
            self.sendHealthStatus()
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
        let result = TennisWatchReconciliation.reconcile(incoming: incoming, pending: queuedCommands, localDeletedIDs: snapshot.deletedRecordIDs)
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
        finishRemotelyCompletedWorkoutIfNeeded()
    }

    private func mergeMatch(_ match: MatchRecord) {
        guard !snapshot.deletedRecordIDs.contains(match.id) else { return }
        snapshot.matches.removeAll { $0.id == match.id }
        snapshot.matches.insert(match, at: 0)
        persistSnapshot()
    }

    private func mergeTraining(_ session: TrainingSession) {
        guard !snapshot.deletedRecordIDs.contains(session.id) else { return }
        snapshot.trainingSessions.removeAll { $0.id == session.id }
        snapshot.trainingSessions.insert(session, at: 0)
        persistSnapshot()
    }

    private func mergeTournament(_ tournament: TournamentRecord) {
        guard !snapshot.deletedRecordIDs.contains(tournament.id) else { return }
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
        // Replay the persisted delete command if shutdown interrupted the snapshot write.
        for case .deleteRecord(let deletion) in queuedCommands { snapshot.delete(deletion) }
        snapshot.removeDeletedRecords()
        activeTraining = snapshot.trainingSessions.first(where: \.isActive)
        if let id = activeMatch?.id, snapshot.deletedRecordIDs.contains(id) {
            activeMatch = nil; pointHistory = []; persistPointHistory()
        }
        if let id = activeTournamentID, snapshot.deletedRecordIDs.contains(id) {
            activeTournamentID = nil
            defaults.removeObject(forKey: "activeTournamentID")
        }
    }

    private func persistSnapshot() {
        snapshot.removeDeletedRecords()
        guard let data = try? JSONEncoder.tennisTracker.encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: localSnapshotKey)
        do {
            if try TennisSharedSnapshotFile.write(snapshot) {
                for kind in TennisGlanceKind.allCases { WidgetCenter.shared.reloadTimelines(ofKind: kind.widgetKind) }
            }
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
