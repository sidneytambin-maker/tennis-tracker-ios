import SwiftUI

struct WatchRootView: View {
    @StateObject private var store = WatchTennisStore()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var quickTraining = false
    var body: some View {
        Group {
            if voiceOver || WatchAccessibilityNavigation.testingEnabled {
                NavigationStack {
                    selectedPage.toolbar {
                        ToolbarItem(placement: .topBarLeading) { WatchPageSelector() }
                    }
                }.id(store.page)
            } else {
                TabView(selection: $store.page) {
                    NavigationStack { WatchTodayView() }.tag(TennisWatchPage.today)
                    NavigationStack { WatchTrackView() }.tag(TennisWatchPage.track)
                    NavigationStack { WatchLiveView() }.tag(TennisWatchPage.live)
                    NavigationStack { WatchRecentView() }.tag(TennisWatchPage.recent)
                    NavigationStack { WatchScoreView() }.tag(TennisWatchPage.score)
                }.tabViewStyle(.page)
            }
        }
        .environmentObject(store)
        .tint(store.snapshot.settings.theme == .tennis ? TennisSportStyle.ball : .cyan)
        .sheet(isPresented: $quickTraining) { NavigationStack { WatchTrainingEntryView() }.environmentObject(store) }
        .onAppear { store.activate() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.restoreWorkoutIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tennisWorkoutRecovery)) { _ in store.restoreWorkoutIfNeeded() }
        .onOpenURL { url in
            if let page = TennisWatchPage.destination(for: url) {
                store.page = page
                if url.lastPathComponent == "start-training" { quickTraining = true }
            }
        }
    }

    @ViewBuilder private var selectedPage: some View {
        switch store.page {
        case .today: WatchTodayView()
        case .track: WatchTrackView()
        case .live: WatchLiveView()
        case .recent: WatchRecentView()
        case .score: WatchScoreView()
        }
    }
}

private struct WatchTodayView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @State private var trainingToStart: TrainingSession?
    @State private var confirmHealth = false
    var body: some View {
        List {
            if let training = store.snapshot.trainingSessions.filter({ !$0.isActive && $0.actualFinish == nil && $0.expectedEndDate >= Date() }).sorted(by: { $0.date < $1.date }).first {
                Section("Next training") {
                    WatchTrainingRow(training: training)
                    Button("Start Training Session") {
                        if store.healthClient.available { trainingToStart = training; confirmHealth = true }
                        else { store.beginTraining(training) }
                    }
                    .disabled(store.activeTraining != nil || store.isFinishingWorkout)
                }
            }
            if let match = store.snapshot.matches.filter({ $0.status == .scheduled }).sorted(by: { $0.date < $1.date }).first {
                Section("Next match") { WatchMatchRow(match: match) }
            }
            if let tournament = store.upcomingTournament {
                Section("Next tournament") { WatchTournamentRow(tournament: tournament) }
            }
            if store.activeTraining != nil {
                Button("Training in progress") { store.page = .live }
            }
            if store.activeMatch != nil {
                Button("Match in progress") { store.page = .score }
            }
            if store.needsDetailsCount > 0 {
                Button("Review \(store.needsDetailsCount) activities needing details") { store.page = .recent }
            }
            Section("Sync") { Text(store.lastSyncStatus).font(.footnote) }
        }
        .navigationTitle("Today")
        .confirmationDialog("Record this tennis session in Apple Health?", isPresented: $confirmHealth, titleVisibility: .visible) {
            Button("Begin with Health Workout") {
                if let trainingToStart { store.beginTraining(trainingToStart, useHealth: true) }
            }
            Button("Begin without Health") {
                if let trainingToStart { store.beginTraining(trainingToStart) }
            }
            Button("Cancel", role: .cancel) { trainingToStart = nil }
        } message: {
            Text("With permission, Tennis Tracker records workout duration, heart rate, active energy and available steps and distance. Training still works without Health access.")
        }
    }
}

private struct WatchTrackView: View {
    var body: some View {
        List {
            Section {
                NavigationLink { WatchTrainingEntryView() } label: { Label("Track Training Session", systemImage: "figure.tennis") }
                NavigationLink { WatchMatchSetupView() } label: { Label("Live Score a Match", systemImage: "tennisball.fill") }
                NavigationLink { WatchTournamentSetupView() } label: { Label("Track Tournament", systemImage: "trophy.fill") }
            }
        }
        .navigationTitle("Track")
    }
}

struct WatchTrainingSetupView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Environment(\.dismiss) private var dismiss
    @State private var type: TrainingType = .singlesPractice
    @State private var focus = ""
    @State private var context = TennisActivityContext()
    @State private var otherPlayers = false
    @State private var otherCoaches = false
    @AppStorage("trackTrainingAsWorkout") private var useHealth = false

    var body: some View {
        Form {
            Picker("Training type", selection: $type) {
                ForEach(TrainingType.allCases) { Text($0.rawValue).tag($0) }
            }
            TennisTrainingFocusPicker(focus: $focus)
            NavigationLink("Coaches") {
                List {
                    ForEach(store.snapshot.setup.coaches) { coach in
                        TennisSelectionRow(name: coach.name, id: coach.id, selectedIDs: $context.coachIDs)
                    }
                    Toggle("Other: complete on iPhone", isOn: $otherCoaches)
                }.navigationTitle("Coaches")
            }
            .accessibilityValue(context.coachSummary(in: store.snapshot.setup.coaches).fallback("None"))
            Picker("Venue", selection: $context.venueID) {
                Text("Other").tag(Optional<UUID>.none)
                ForEach(store.snapshot.setup.venues.filter(\.usedForTraining)) { Text($0.summary).tag(Optional($0.id)) }
            }
            NavigationLink("Players Present") {
                List {
                    ForEach(store.snapshot.players.filter { $0.id != store.selectedPlayer?.id }) { player in
                        TennisSelectionRow(name: player.displayName, id: player.id, selectedIDs: $context.participantIDs)
                    }
                    Toggle("Other", isOn: $otherPlayers)
                }.navigationTitle("Players Present")
            }
            .accessibilityValue(context.participantSummary(in: store.snapshot.players).fallback("None"))
            Picker("Tournament", selection: $context.tournamentID) {
                Text("Other or no tournament").tag(Optional<UUID>.none)
                ForEach(store.snapshot.tournaments.filter { !$0.isCompleted }) { Text($0.name).tag(Optional($0.id)) }
            }
            if store.healthClient.available {
                Section("Apple Health") {
                    Toggle("Track Training as Workout", isOn: $useHealth)
                    WatchHealthAccessView(client: store.healthClient)
                    Text("Tennis Tracker can record workout duration, heart rate, active energy and available steps and distance in Apple Health. Tennis tracking still works if you decline.")
                }
            }
            Button("Begin Training Session") {
                context.captureLegacyNames(coaches: store.snapshot.setup.coaches, players: store.snapshot.players)
                context.coachesNeedDetails = otherCoaches
                context.participantsNeedDetails = otherPlayers
                let venue = store.snapshot.setup.venues.first { $0.id == context.venueID }
                store.trackTrainingSession(type: type, focus: focus, context: context, venue: venue?.name ?? "", location: venue?.town ?? "", useHealth: useHealth)
                dismiss()
            }
            .disabled(store.selectedPlayer == nil || store.activeTraining != nil || store.isFinishingWorkout)
        }
        .navigationTitle("Training")
        .onChange(of: useHealth) { _, _ in store.sendHealthStatus() }
    }
}

private struct WatchMatchSetupView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Environment(\.dismiss) private var dismiss
    @State private var match = MatchRecord(playerID: UUID())
    @State private var configured = false

    var body: some View {
        Form {
            Picker("Singles or doubles", selection: $match.matchType) {
                ForEach(MatchKind.allCases) { Text($0.rawValue).tag($0) }
            }
            TennisPersonPicker(title: "Opponent", players: store.snapshot.players.filter { $0.id != match.playerID }, selection: $match.opponentID, name: $match.opponentName)
            if match.matchType == .doubles {
                TennisPersonPicker(title: "Partner", players: store.snapshot.players.filter { $0.id != match.playerID && $0.id != match.opponentID }, selection: $match.partnerID, name: $match.partnerName, regularPartnersFirst: true)
                TennisPersonPicker(title: "Second opponent", players: store.snapshot.players.filter { $0.id != match.playerID && $0.id != match.opponentID && $0.id != match.partnerID }, selection: $match.opponent2ID, name: $match.opponent2Name)
            }
            OrderedChoicePicker(title: "Match format", selection: $match.matchFormat, values: MatchFormat.allCases) { $0.label }
            Picker("Venue", selection: $match.venueID) {
                Text("Other").tag(Optional<UUID>.none)
                ForEach(store.snapshot.setup.venues.filter(\.usedForMatches)) { Text($0.summary).tag(Optional($0.id)) }
            }
            Picker("Tournament", selection: $match.tournamentID) {
                Text("Other or no tournament").tag(Optional<UUID>.none)
                ForEach(store.snapshot.tournaments.filter { !$0.isCompleted }) { Text($0.name).tag(Optional($0.id)) }
            }
            Button("Begin Match Scoring") {
                if let venue = store.snapshot.setup.venues.first(where: { $0.id == match.venueID }) {
                    match.venue = venue.name; match.location = venue.town
                }
                match.needsDetails = match.opponentID == nil || (match.matchType == .doubles && (match.partnerID == nil || match.opponent2ID == nil)) || match.venueID == nil
                store.beginMatch(match)
                if match.needsDetails { store.announce("Match ready. Details can be edited on Watch.") }
                dismiss()
            }
            .disabled(!configured || store.activeMatch != nil)
        }
        .navigationTitle("Live Score a Match")
        .onAppear {
            guard !configured, let player = store.selectedPlayer else { return }
            match = TennisWatchActivityFactory.match(player: player, kind: .singles)
            match.opponentName = ""
            configured = true
        }
    }
}

private struct WatchTournamentSetupView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Environment(\.dismiss) private var dismiss
    @State private var templateID: UUID?
    var body: some View {
        Form {
            Section("Existing tournament") {
                ForEach(store.snapshot.tournaments.filter { !$0.isCompleted }) { tournament in
                    Button(tournament.name) { store.beginTournament(tournament); dismiss() }
                }
            }
            Section("New occurrence") {
                Picker("Regular tournament", selection: $templateID) {
                    Text("Other").tag(Optional<UUID>.none)
                    ForEach(store.snapshot.setup.tournamentTemplates) { Text($0.name).tag(Optional($0.id)) }
                }
                Button("Begin Tournament") {
                    guard let player = store.selectedPlayer else { return }
                    var tournament = TennisWatchActivityFactory.tournament(playerID: player.id)
                    if let template = store.snapshot.setup.tournamentTemplates.first(where: { $0.id == templateID }) {
                        tournament.templateID = template.id; tournament.name = template.name
                        tournament.format = template.format; tournament.venueID = template.venueID
                        if let venue = store.snapshot.setup.venues.first(where: { $0.id == template.venueID }) {
                            tournament.venue = venue.name; tournament.location = venue.town
                        }
                    }
                    store.beginTournament(tournament)
                    store.announce("Tournament started. Dates and details can be edited on Watch.")
                    dismiss()
                }
            }
        }
        .navigationTitle("Tournament")
    }
}

private struct WatchLiveView: View {
    @EnvironmentObject private var store: WatchTennisStore
    var body: some View {
        List {
            if let training = store.activeTraining {
                WatchTrainingRow(training: training)
            }
            if let tournament = store.snapshot.tournaments.first(where: { $0.id == store.activeTournamentID }) {
                WatchTournamentRow(tournament: tournament)
            }
            if store.activeTraining == nil, let training = store.completedTraining {
                WatchTrainingRow(training: training, identifier: "Completed training summary")
                if store.isFinishingWorkout { ProgressView("Saving workout") }
                if training.trainingType == .matchPlay {
                    NavigationLink("Record Practice Result") { WatchPracticeResultView() }
                }
            } else if store.activeTraining == nil && store.activeTournamentID == nil {
                Text("No tennis activity in progress.")
            }
        }
        .navigationTitle("Live")
    }
}

private struct WatchHealthAccessView: View {
    @ObservedObject var client: WatchHealthWorkout
    var body: some View { Text("Health access: \(client.accessDescription)") }
}

private struct WatchPracticeResultView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Environment(\.dismiss) private var dismiss
    @State private var result = TennisPracticeResult()
    var body: some View {
        Form {
            Picker("Singles or doubles", selection: $result.kind) {
                ForEach(MatchKind.allCases) { Text($0.rawValue).tag($0) }
            }
            TennisPersonPicker(title: "Opponent", players: store.snapshot.players.filter { $0.id != store.selectedPlayer?.id && $0.id != result.partnerID && $0.id != result.opponent2ID }, selection: $result.opponentID, name: $result.opponentName)
            if result.kind == .doubles {
                TennisPersonPicker(title: "Partner", players: store.snapshot.players.filter { $0.id != store.selectedPlayer?.id && $0.id != result.opponentID && $0.id != result.opponent2ID }, selection: $result.partnerID, name: $result.partnerName, regularPartnersFirst: true)
                TennisPersonPicker(title: "Second opponent", players: store.snapshot.players.filter { $0.id != store.selectedPlayer?.id && $0.id != result.partnerID && $0.id != result.opponentID }, selection: $result.opponent2ID, name: $result.opponent2Name)
            }
            OrderedChoicePicker(title: "Your games", selection: $result.playerGames, values: Array(0...30)) { "\($0) games" }
            OrderedChoicePicker(title: "Opponent games", selection: $result.opponentGames, values: Array(0...30)) { "\($0) games" }
            Button("Save Practice Result") {
                result.result = result.playerGames == result.opponentGames ? .draw : result.playerGames > result.opponentGames ? .win : .loss
                store.savePracticeResult(result); dismiss()
            }
        }.navigationTitle("Practice Result")
    }
}

private struct WatchRecentView: View {
    @EnvironmentObject private var store: WatchTennisStore
    var body: some View {
        List {
            Section("Matches") {
                ForEach(store.snapshot.matches.filter { $0.status == .completed && !$0.needsDetails }.sorted { $0.date > $1.date }.prefix(5)) { match in
                    WatchMatchRow(match: match)
                }
            }
            Section("Training") {
                ForEach(store.snapshot.trainingSessions.filter { !$0.needsDetails && !$0.isActive && ($0.actualFinish != nil || $0.expectedEndDate < Date()) }.sorted { $0.date > $1.date }.prefix(5)) { training in
                    WatchTrainingRow(training: training)
                }
            }
            Section("Tournaments") {
                ForEach(store.snapshot.tournaments.filter { $0.isCompleted && !$0.needsDetails }.sorted { $0.date > $1.date }.prefix(3)) {
                    WatchTournamentRow(tournament: $0)
                }
            }
            if store.needsDetailsCount > 0 {
                Section("Needs Details") {
                    ForEach(store.snapshot.trainingSessions.filter { $0.needsDetails && !$0.isActive }) { WatchTrainingRow(training: $0) }
                    ForEach(store.snapshot.matches.filter { $0.needsDetails && $0.status != .inProgress }) { WatchMatchRow(match: $0) }
                    ForEach(store.snapshot.tournaments.filter { $0.needsDetails && $0.id != store.activeTournamentID }) { WatchTournamentRow(tournament: $0) }
                }
            }
        }.navigationTitle("Recent")
    }
}

private struct WatchScoreView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @AccessibilityFocusState private var pointFocus: PointWinner?
    @State private var confirmFinish = false
    @State private var editingMatch: MatchRecord?
    @State private var deletingMatch = false
    var body: some View {
        List {
            if let match = store.activeMatch {
                Text(scoreText)
                    .accessibilityLabel("Current match score")
                    .accessibilityValue(scoreText)
                    .accessibilityAction(named: "Undo Last Point") { store.undoLastPoint() }
                    .accessibilityAction(named: "Save Match Progress") { store.saveMatchProgress() }
                    .accessibilityAction(named: "Edit Match") { editingMatch = match }
                    .accessibilityAction(named: "Hear Full Score") { store.announce(scoreText) }
                    .accessibilityActions {
                        if !store.scoreState.isTiebreak && !store.scoreState.isMatchComplete {
                            Button("Start Tie-break") { store.startTieBreak() }
                        }
                    }
                    .accessibilityAction(named: "Finish Match") { confirmFinish = true }
                    .accessibilityAction(named: "Delete") { deletingMatch = true }
                    .accessibilityAction { store.announce(scoreText) }
                HStack(spacing: 8) {
                    pointButton(name: match.playerTeam, winner: .player)
                    pointButton(name: match.opponentSummary.fallback("Opponent"), winner: .opponent)
                }.accessibilityElement(children: .contain)
                if hideScoreActions {
                    scoreActions(for: match).accessibilityRepresentation { EmptyView() }
                } else {
                    scoreActions(for: match)
                }
            } else {
                Text("No match in progress.")
                ForEach(store.snapshot.matches.filter { $0.status == .scheduled || $0.status == .inProgress }) { match in
                    Button("Score \(match.playerTeam) against \(match.opponentSummary)") { store.beginMatch(match) }
                }
                NavigationLink("Live Score a Match") { WatchMatchSetupView() }
            }
        }
        .navigationTitle("Score")
        .sheet(item: $editingMatch) { match in NavigationStack { WatchMatchEditor(draft: match) } }
        .sheet(isPresented: $deletingMatch) {
            if let match = store.activeMatch {
                WatchDeleteSheet(isPresented: $deletingMatch, deletion: TennisRecordDeletion(id: match.id, kind: .match))
            }
        }
        .confirmationDialog("Finish match with the recorded score?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish Match") { store.finishMatch() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var hideScoreActions: Bool { voiceOver || WatchAccessibilityNavigation.testingEnabled }

    private func pointButton(name: String, winner: PointWinner) -> some View {
        Button {
            store.recordPoint(winner); pointFocus = winner
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                Text(name).font(.caption).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .foregroundStyle(store.snapshot.settings.theme == .tennis ? TennisSportStyle.ink : .white)
        .accessibilityLabel("Record Point for \(name)")
        .accessibilityFocused($pointFocus, equals: winner)
    }

    private func scoreActions(for match: MatchRecord) -> some View {
        VStack(spacing: 8) {
            Button("Undo Last Point") { store.undoLastPoint() }
            Button("Edit Match") { editingMatch = match }
            Button("Save Match Progress") { store.saveMatchProgress() }
            Button("Start Tie-break") { store.startTieBreak() }
                .disabled(store.scoreState.isTiebreak || store.scoreState.isMatchComplete)
            Button("Finish Match") { confirmFinish = true }
            Button("Delete", role: .destructive) { deletingMatch = true }
        }.buttonStyle(.bordered)
    }

    private var scoreText: String {
        guard let match = store.activeMatch else { return "No match in progress." }
        return store.scoreState.spokenScore(playerName: match.playerTeam, opponentName: match.opponentSummary.fallback("Opponent"), suddenDeathDeuce: match.suddenDeathDeuce)
    }
}
