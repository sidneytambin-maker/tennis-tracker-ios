import SwiftUI
import UIKit

struct MatchesView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var showingNewMatch = false
    @State private var showingLiveScorer = false

    var body: some View {
        NavigationStack {
            List {
                Section("Live scorer") {
                    Button("Start live scoring") {
                        showingLiveScorer = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Opens a point by point scorer with player and opponent names.")
                }

                Section("Match history") {
                    if store.selectedMatches.isEmpty {
                        EmptyStateView(title: "No matches recorded yet", message: "Use Add to record a match or start live scoring.")
                    } else {
                        ForEach(store.selectedMatches) { match in
                            NavigationLink {
                                MatchDetailView(match: match)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(match.date.shortTennisDate): \(match.result.rawValue) against \(match.opponentSummary.fallback("opponent not recorded"))")
                                    Text(scoreSummary(match))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityLabel("Match")
                            .accessibilityValue("\(match.date.shortTennisDate), \(match.matchType.rawValue), \(match.result.rawValue), \(scoreSummary(match))")
                        }
                    }
                }
            }
            .tennisThemedList()
            .navigationTitle("Matches")
            .toolbar {
                Button("Add") { showingNewMatch = true }
                    .accessibilityLabel("Add match")
                    .accessibilityIdentifier("addMatchButton")
            }
            .sheet(isPresented: $showingNewMatch) {
                if let match = store.makeDefaultMatch() {
                    MatchEditorView(match: match)
                }
            }
            .sheet(isPresented: $showingLiveScorer) {
                LiveMatchView()
            }
        }
    }

    private func scoreSummary(_ match: MatchRecord) -> String {
        let sets = match.yourSetsWon + match.opponentSetsWon > 0 ? "sets \(match.yourSetsWon)-\(match.opponentSetsWon)" : "sets not recorded"
        return match.setScores.isBlank ? sets : "\(sets), \(match.setScores)"
    }
}

struct MatchDetailView: View {
    @EnvironmentObject private var store: TennisStore
    @State var match: MatchRecord
    @State private var showingEditor = false
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section("Summary") {
                SummaryRow(title: "\(match.result.rawValue) against \(match.opponentSummary.fallback("opponent not recorded"))", value: "\(match.matchType.rawValue). \(match.date.shortTennisDate).")
                SummaryRow(title: "Players", value: "\(match.playerName.fallback("Player")) against \(match.opponentSummary.fallback("opponent not recorded")).")
                SummaryRow(title: "Score", value: "\(match.yourSetsWon)-\(match.opponentSetsWon) sets. \(match.setScores.fallback("set scores not recorded")).")
                SummaryRow(title: "Rules", value: "\(match.sightLevel.rawValue). \(match.allowedBounces) bounces. Sudden-death deuce \(match.suddenDeathDeuce ? "on" : "off").")
            }

            if store.data.settings.trackingMode != .basic {
                Section("Performance") {
                    SummaryRow(title: "Key stats", value: "\(match.aces) aces, \(match.doubleFaults) double faults, \(match.winners) winners, \(match.unforcedErrors) unforced errors.")
                    SummaryRow(title: "Strengths", value: match.matchStrengths.fallback("not recorded"))
                    SummaryRow(title: "Needs work", value: match.matchNeedsWork.fallback("not recorded"))
                    SummaryRow(title: "Next practice focus", value: match.nextPracticeFocus.fallback("not recorded"))
                }
            }

            Section("Notes") {
                Text(match.notes.fallback(match.matchStory.fallback("No notes recorded.")))
            }

            Section {
                Button("Delete match", role: .destructive) { confirmDelete = true }
            }
        }
        .tennisThemedList()
        .navigationTitle("Match detail")
        .toolbar {
            Button("Edit") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            MatchEditorView(match: match)
        }
        .confirmationDialog("Delete this match?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete match", role: .destructive) {
                store.deleteMatch(match)
            }
        }
    }
}

struct MatchEditorView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State var match: MatchRecord

    var body: some View {
        NavigationStack {
            Form {
                Section("Match") {
                    DateShortcutPicker(title: "Date", date: $match.date)
                        .accessibilityIdentifier("matchDatePicker")
                    Picker("Match type", selection: $match.matchType) {
                        ForEach(MatchKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
                    }
                    Picker("Result", selection: $match.result) {
                        ForEach(MatchResult.allCases) { result in Text(result.rawValue).tag(result) }
                    }
                }

                Section("Players") {
                    TextField("Player name", text: $match.playerName)
                        .accessibilityIdentifier("matchPlayerNameField")
                    TextField("Opponent name", text: $match.opponentName)
                        .accessibilityIdentifier("matchOpponentNameField")
                    if match.matchType == .doubles {
                        TextField("Partner", text: $match.partnerName)
                        TextField("Second opponent", text: $match.opponent2Name)
                    }
                }

                Section("Rules") {
                    Picker("Sight level", selection: $match.sightLevel) {
                        ForEach(SightLevel.allCases) { level in Text(level.rawValue).tag(level) }
                    }
                    .onChange(of: match.sightLevel) { _, newValue in
                        match.allowedBounces = newValue.allowedBounces
                        match.suddenDeathDeuce = newValue != .fullySighted
                    }
                    Stepper("Allowed bounces \(match.allowedBounces)", value: $match.allowedBounces, in: 1...3)
                    Toggle("Sudden-death deuce", isOn: $match.suddenDeathDeuce)
                        .accessibilityIdentifier("matchSuddenDeathToggle")
                }

                if !store.selectedTournaments.isEmpty || !store.selectedTraining.isEmpty {
                    Section("Links") {
                        Picker("Tournament", selection: $match.tournamentID) {
                            Text("No tournament").tag(Optional<UUID>.none)
                            ForEach(store.selectedTournaments) { tournament in
                                Text(tournament.name.fallback("Unnamed tournament")).tag(Optional(tournament.id))
                            }
                        }
                        .accessibilityIdentifier("matchTournamentPicker")

                        Picker("Training session", selection: $match.trainingSessionID) {
                            Text("No training session").tag(Optional<UUID>.none)
                            ForEach(store.selectedTraining) { session in
                                Text("\(session.date.shortTennisDate), \(session.trainingType.rawValue)").tag(Optional(session.id))
                            }
                        }
                        .accessibilityIdentifier("matchTrainingPicker")
                    }
                }

                Section("Score") {
                    Stepper("Player sets won \(match.yourSetsWon)", value: $match.yourSetsWon, in: 0...5)
                    Stepper("Opponent sets won \(match.opponentSetsWon)", value: $match.opponentSetsWon, in: 0...5)
                    TextField("Set scores", text: $match.setScores)
                    Toggle("Had tiebreak", isOn: $match.hadTiebreak)
                    if match.hadTiebreak {
                        TextField("Tiebreak score", text: $match.tiebreakScore)
                    }
                }

                if store.data.settings.trackingMode != .basic {
                    Section("Performance") {
                        Picker("Round or position", selection: $match.matchPosition) {
                            ForEach(MatchPosition.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Court surface", selection: $match.courtSurface) {
                            ForEach(CourtSurface.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Stepper("Aces \(match.aces)", value: $match.aces, in: 0...99)
                        Stepper("Double faults \(match.doubleFaults)", value: $match.doubleFaults, in: 0...99)
                        TextField("Next practice focus", text: $match.nextPracticeFocus, axis: .vertical)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $match.notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("matchNotesField")
                }
            }
            .tennisThemedList()
            .navigationTitle("Match")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.upsertMatch(match)
                        dismiss()
                    }
                    .accessibilityIdentifier("saveMatchButton")
                }
            }
        }
    }
}

struct LiveMatchView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State private var scorer = TennisScoringEngine()
    @State private var playerName = ""
    @State private var opponentName = ""
    @State private var suddenDeathDeuce = true
    @AccessibilityFocusState private var focusedScore: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Players") {
                    TextField("Player name", text: $playerName)
                        .accessibilityIdentifier("livePlayerNameField")
                    TextField("Opponent name", text: $opponentName)
                        .accessibilityIdentifier("liveOpponentNameField")
                    Toggle("Sudden-death deuce", isOn: $suddenDeathDeuce)
                        .accessibilityIdentifier("liveSuddenDeathToggle")
                }

                Section("Score") {
                    Text(scorer.fullScore)
                        .font(.title2.bold())
                        .accessibilityLabel("Current score")
                        .accessibilityValue(scorer.fullScore)
                        .accessibilityAddTraits(.updatesFrequently)
                        .accessibilityFocused($focusedScore)
                }

                Section("Points") {
                    Button("Point to \(playerName.fallback("Player"))") {
                        score(.player)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("playerWinsPointButton")

                    Button("Point to \(opponentName.fallback("Opponent"))") {
                        score(.opponent)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("opponentWinsPointButton")
                }

                Section("Actions") {
                    Button("Undo") {
                        announce(scorer.undo(), force: store.data.settings.scoreAnnouncementMode != .off)
                    }
                    .accessibilityIdentifier("undoScoreButton")
                    Button("Hear full score") {
                        announce(scorer.fullScore, force: true)
                    }
                    .accessibilityIdentifier("hearFullScoreButton")
                    Button("Reset score") {
                        scorer.reset()
                        announce("Score reset. \(scorer.fullScore).", force: store.data.settings.scoreAnnouncementMode != .off)
                    }
                    .accessibilityIdentifier("resetScoreButton")
                }

                Section {
                    Button("Save completed match") {
                        saveLiveMatch()
                    }
                    .disabled(!scorer.state.isMatchComplete || store.selectedPlayerID == nil)
                    .accessibilityIdentifier("saveCompletedMatchButton")
                }
            }
            .tennisThemedList()
            .navigationTitle("Live scorer")
            .toolbar {
                Button("Done") { dismiss() }
            }
            .onAppear {
                configureDefaults()
                focusedScore = true
            }
            .onChange(of: playerName) { _, _ in syncScorerNames() }
            .onChange(of: opponentName) { _, _ in syncScorerNames() }
            .onChange(of: suddenDeathDeuce) { _, _ in syncScorerNames() }
        }
    }

    private func configureDefaults() {
        let player = store.selectedPlayer
        if playerName.isBlank {
            playerName = player?.displayName ?? "Player"
        }
        if opponentName.isBlank {
            opponentName = "Opponent"
        }
        suddenDeathDeuce = player?.playerMode == .blindTennis
        syncScorerNames()
    }

    private func syncScorerNames() {
        scorer.playerName = playerName.fallback("Player")
        scorer.opponentName = opponentName.fallback("Opponent")
        scorer.suddenDeathDeuce = suddenDeathDeuce
    }

    private func score(_ winner: PointWinner) {
        syncScorerNames()
        let message = scorer.awardPoint(to: winner)
        if store.data.settings.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        switch store.data.settings.scoreAnnouncementMode {
        case .automatic:
            announce(message, force: true)
        case .reduced:
            let name = winner == .player ? playerName.fallback("Player") : opponentName.fallback("Opponent")
            announce("Point to \(name). \(scorer.state.pointScore(suddenDeathDeuce: suddenDeathDeuce)).", force: true)
        case .off:
            store.announce(message)
        }
    }

    private func announce(_ message: String, force: Bool) {
        store.announce(message)
        focusedScore = true
        if force {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    private func saveLiveMatch() {
        guard let playerID = store.selectedPlayerID else { return }
        let playerWon = scorer.state.playerSets > scorer.state.opponentSets
        var match = store.makeDefaultMatch() ?? MatchRecord(playerID: playerID)
        match.playerName = playerName
        match.opponentName = opponentName
        match.result = playerWon ? .win : .loss
        match.yourSetsWon = scorer.state.playerSets
        match.opponentSetsWon = scorer.state.opponentSets
        match.setScores = scorer.state.completedSetScores.joined(separator: ", ")
        match.hadTiebreak = match.setScores.contains("7-6") || match.setScores.contains("6-7")
        match.suddenDeathDeuce = suddenDeathDeuce
        store.upsertMatch(match)
        announce(scorer.fullScore, force: store.data.settings.scoreAnnouncementMode != .off)
        dismiss()
    }
}
