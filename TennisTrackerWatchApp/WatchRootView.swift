import SwiftUI

struct WatchRootView: View {
    @StateObject private var store = WatchTennisStore()
    var body: some View {
        TabView(selection: $store.page) {
            NavigationStack { WatchTodayView() }.tag(TennisWatchPage.today)
            NavigationStack { WatchTrackView() }.tag(TennisWatchPage.track)
            NavigationStack { WatchLiveView() }.tag(TennisWatchPage.live)
            NavigationStack { WatchRecentView() }.tag(TennisWatchPage.recent)
            NavigationStack { WatchScoreView() }.tag(TennisWatchPage.score)
        }
        .environmentObject(store)
        .tabViewStyle(.page)
        .onAppear { store.activate() }
        .onOpenURL { url in
            if let page = TennisWatchPage.destination(for: url) { store.page = page }
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
                    Text(TennisSummaryFormatter.training(training))
                    Button("Start Training Session") {
                        if store.healthClient.available { trainingToStart = training; confirmHealth = true }
                        else { store.beginTraining(training) }
                    }
                    .disabled(store.activeTraining != nil || store.isFinishingWorkout)
                }
            }
            if let match = store.snapshot.matches.filter({ $0.status == .scheduled }).sorted(by: { $0.date < $1.date }).first {
                Section("Next match") { Text(TennisSummaryFormatter.match(match, tournaments: store.snapshot.tournaments)) }
            }
            if let tournament = store.upcomingTournament {
                Section("Next tournament") { Text(TennisSummaryFormatter.tournament(tournament, style: .short)) }
            }
            if store.activeTraining != nil {
                Button("Training in progress") { store.page = .live }
            }
            if store.activeMatch != nil {
                Button("Match in progress") { store.page = .score }
            }
            if store.needsDetailsCount > 0 {
                Section("Needs Details") { Text("\(store.needsDetailsCount) activities need details on iPhone.") }
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
            Text("With permission, Tennis Tracker records workout duration, heart rate and active energy. Training still works without Health access.")
        }
    }
}

private struct WatchTrackView: View {
    var body: some View {
        List {
            Section("Track Tennis Activity") {
                NavigationLink("Track Training Session") { WatchTrainingSetupView() }
                NavigationLink("Record Match") { WatchMatchSetupView() }
                NavigationLink("Track Tournament") { WatchTournamentSetupView() }
            }
        }
        .navigationTitle("Track")
    }
}

private struct WatchTrainingSetupView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Environment(\.dismiss) private var dismiss
    @State private var type: TrainingType = .singlesPractice
    @State private var context = TennisActivityContext()
    @State private var otherPlayers = false
    @State private var useHealth = false

    var body: some View {
        Form {
            Picker("Training type", selection: $type) {
                ForEach(TrainingType.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Coach", selection: $context.coachID) {
                Text("Other or no coach").tag(Optional<UUID>.none)
                ForEach(store.snapshot.setup.coaches) { Text($0.name).tag(Optional($0.id)) }
            }
            Picker("Venue", selection: $context.venueID) {
                Text("Other").tag(Optional<UUID>.none)
                ForEach(store.snapshot.setup.venues.filter(\.usedForTraining)) { Text($0.summary).tag(Optional($0.id)) }
            }
            NavigationLink("Players Present") {
                List {
                    ForEach(store.snapshot.players.filter { $0.id != store.selectedPlayer?.id }) { player in
                        Toggle(player.displayName, isOn: Binding(
                            get: { context.participantIDs.contains(player.id) },
                            set: { selected in
                                context.participantIDs.removeAll { $0 == player.id }
                                if selected { context.participantIDs.append(player.id) }
                            }
                        ))
                    }
                    Toggle("Other", isOn: $otherPlayers)
                }.navigationTitle("Players Present")
            }
            Picker("Tournament", selection: $context.tournamentID) {
                Text("Other or no tournament").tag(Optional<UUID>.none)
                ForEach(store.snapshot.tournaments.filter { !$0.isCompleted }) { Text($0.name).tag(Optional($0.id)) }
            }
            if store.healthClient.available {
                Section("Apple Health") {
                    Toggle("Record tennis workout", isOn: $useHealth)
                    Text("Tennis Tracker can record workout duration, heart rate and active energy in Apple Health during training. Tennis tracking still works if you decline.")
                }
            }
            Button("Begin Training Session") {
                context.coachName = store.snapshot.setup.coaches.first { $0.id == context.coachID }?.name ?? ""
                context.participantNames = store.snapshot.players.filter { context.participantIDs.contains($0.id) }.map(\.displayName)
                context.participantsNeedDetails = otherPlayers
                let venue = store.snapshot.setup.venues.first { $0.id == context.venueID }
                store.trackTrainingSession(type: type, context: context, venue: venue?.name ?? "", location: venue?.town ?? "", useHealth: useHealth)
                dismiss()
            }
            .disabled(store.selectedPlayer == nil || store.activeTraining != nil || store.isFinishingWorkout)
            Button("Cancel", role: .cancel) { dismiss() }
        }
        .navigationTitle("Training")
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
            Picker("Match format", selection: $match.matchFormat) {
                ForEach(MatchFormat.allCases) { Text($0.label).tag($0) }
            }
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
                if match.needsDetails { store.announce("Match ready. Complete missing details later on iPhone.") }
                dismiss()
            }
            .disabled(!configured || store.activeMatch != nil)
            Button("Cancel", role: .cancel) { dismiss() }
        }
        .navigationTitle("Record Match")
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
                    store.announce("Tournament started. Complete dates and details later on iPhone.")
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
        }
        .navigationTitle("Tournament")
    }
}

private struct WatchLiveView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @State private var confirmFinish = false
    var body: some View {
        List {
            if let training = store.activeTraining {
                Text(training.trainingType.rawValue).font(.headline)
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(max(0, Int(context.date.timeIntervalSince(training.actualStart ?? training.date) / 60)).durationText)
                        .accessibilityLabel("Elapsed duration")
                        .accessibilityValue(max(0, Int(context.date.timeIntervalSince(training.actualStart ?? training.date) / 60)).durationText)
                }
                if !training.context.coachName.isBlank { Text("Coach \(training.context.coachName)") }
                if !training.venue.isBlank { Text(training.venue) }
                WatchHealthMetricsView(client: store.healthClient)
                if !store.workoutMessage.isBlank { Text(store.workoutMessage) }
                Button("Finish Training Session") { confirmFinish = true }.buttonStyle(.borderedProminent)
                    .disabled(store.isPreparingWorkout)
            } else if let tournament = store.snapshot.tournaments.first(where: { $0.id == store.activeTournamentID }) {
                Text(TennisSummaryFormatter.tournament(tournament, style: .short))
                Button("Finish Tournament") { confirmFinish = true }
            } else if let training = store.completedTraining {
                Text(TennisSummaryFormatter.training(training, style: .detailed))
                NavigationLink("View Details") { Text(TennisSummaryFormatter.training(training, style: .detailed)).padding() }
                if training.trainingType == .matchPlay {
                    NavigationLink("Record Practice Result") { WatchPracticeResultView() }
                }
                Button("Mark Complete") {
                    store.send(.markTrainingDetailsComplete(training.id))
                    store.announce("Marked training complete.")
                }
                Button("Complete Details on iPhone") { store.announce("Open this training session on iPhone to complete its details.") }
            } else {
                Text("No tennis activity in progress.")
            }
        }
        .navigationTitle("Live")
        .confirmationDialog("Finish this activity?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish") {
                if store.activeTraining != nil { store.finishTrainingSession() }
                else { store.finishTournament() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct WatchHealthMetricsView: View {
    @ObservedObject var client: WatchHealthWorkout
    var body: some View {
        if let heart = client.latestHeartRate {
            Text("Heart rate \(Int(heart.rounded())) BPM")
        }
        if let energy = client.activeEnergy {
            Text("Active energy \(Int(energy.rounded())) calories")
        }
    }
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
            Picker("Your games", selection: $result.playerGames) { ForEach(0...30, id: \.self) { Text("\($0)").tag($0) } }
            Picker("Opponent games", selection: $result.opponentGames) { ForEach(0...30, id: \.self) { Text("\($0)").tag($0) } }
            Button("Save Practice Result") {
                result.result = result.playerGames == result.opponentGames ? .draw : result.playerGames > result.opponentGames ? .win : .loss
                store.savePracticeResult(result); dismiss()
            }
            Button("Cancel", role: .cancel) { dismiss() }
        }.navigationTitle("Practice Result")
    }
}

private struct WatchRecentView: View {
    @EnvironmentObject private var store: WatchTennisStore
    var body: some View {
        List {
            Section("Matches") {
                ForEach(store.snapshot.matches.filter { $0.status == .completed }.sorted { $0.date > $1.date }.prefix(5)) { match in
                    Text(TennisSummaryFormatter.match(match, tournaments: store.snapshot.tournaments, style: .short))
                        .accessibilityAction(named: "Complete Match Details") { store.announce("Complete this match on iPhone.") }
                }
            }
            Section("Training") {
                ForEach(store.snapshot.trainingSessions.filter { !$0.isActive && ($0.actualFinish != nil || $0.expectedEndDate < Date()) }.sorted { $0.date > $1.date }.prefix(5)) { training in
                    Text(TennisSummaryFormatter.training(training, style: .short))
                        .accessibilityAction(named: "Complete Training Details") { store.announce("Complete this training session on iPhone.") }
                }
            }
            Section("Tournaments") {
                ForEach(store.snapshot.tournaments.filter(\.isCompleted).sorted { $0.date > $1.date }.prefix(3)) {
                    Text(TennisSummaryFormatter.tournament($0, style: .short))
                }
            }
            if store.needsDetailsCount > 0 {
                Section("Needs Details") { Text("\(store.needsDetailsCount) activities need details on iPhone.") }
            }
        }.navigationTitle("Recent")
    }
}

private struct WatchScoreView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @AccessibilityFocusState private var pointFocus: PointWinner?
    @State private var confirmFinish = false
    var body: some View {
        List {
            if let match = store.activeMatch {
                Text(scoreText)
                    .accessibilityLabel("Current match score")
                    .accessibilityValue(scoreText)
                    .accessibilityAction(named: "Undo Last Point") { store.undoLastPoint() }
                    .accessibilityAction(named: "Save Match Progress") { store.saveMatchProgress() }
                    .accessibilityAction(named: "Hear Full Score") { store.announce(scoreText) }
                    .accessibilityAction(named: "Start Tie-break") { store.startTieBreak() }
                    .accessibilityAction(named: "Finish Match") { confirmFinish = true }
                Button("Record Point for \(match.playerTeam)") {
                    store.recordPoint(.player); pointFocus = .player
                }
                .buttonStyle(.borderedProminent)
                .accessibilityFocused($pointFocus, equals: .player)
                Button("Record Point for \(match.opponentSummary.fallback("Opponent"))") {
                    store.recordPoint(.opponent); pointFocus = .opponent
                }
                .buttonStyle(.borderedProminent)
                .accessibilityFocused($pointFocus, equals: .opponent)
                Button("Undo Last Point") { store.undoLastPoint() }
                Button("Hear Full Score") { store.announce(scoreText) }
                Button("Save Match Progress") { store.saveMatchProgress() }
                Button("Start Tie-break") { store.startTieBreak() }
                    .disabled(store.scoreState.isTiebreak || store.scoreState.isMatchComplete)
                Button("Finish Match") { confirmFinish = true }
            } else {
                Text("No match in progress.")
                ForEach(store.snapshot.matches.filter { $0.status == .scheduled || $0.status == .inProgress }) { match in
                    Button("Score \(match.playerTeam) against \(match.opponentSummary)") { store.beginMatch(match) }
                }
                Button("Record Match") { store.page = .track }
            }
        }
        .navigationTitle("Score")
        .confirmationDialog("Finish match with the recorded score?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish Match") { store.finishMatch() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var scoreText: String {
        guard let match = store.activeMatch else { return "No match in progress." }
        return store.scoreState.spokenScore(playerName: match.playerTeam, opponentName: match.opponentSummary.fallback("Opponent"), suddenDeathDeuce: match.suddenDeathDeuce)
    }
}
