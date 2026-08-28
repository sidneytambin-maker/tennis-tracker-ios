import SwiftUI
import UIKit

struct MatchesView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var showingNewMatch = false
    @State private var showingLiveScorer = false
    @State private var liveMatchToResume: MatchRecord?

    var body: some View {
        NavigationStack {
            List {
                Section("Live scorer") {
                    Button("Start live scoring") {
                        showingLiveScorer = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Opens a point by point scorer with player and opponent names.")

                    ForEach(store.resumableMatches()) { match in
                        Button("Resume \(match.opponentSummary.fallback("match"))") {
                            liveMatchToResume = match
                            showingLiveScorer = true
                        }
                        .accessibilityHint("Continues this saved live score from where you left it.")
                    }
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
                            .accessibilityValue("\(match.date.shortTennisDate), \(match.matchType.rawValue), \(match.status.rawValue), \(match.result.rawValue), \(scoreSummary(match))")
                            .accessibilityAction(named: "Resume live score") {
                                if match.status == .inProgress {
                                    liveMatchToResume = match
                                    showingLiveScorer = true
                                }
                            }
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
                LiveMatchView(existingMatch: liveMatchToResume)
                    .onDisappear { liveMatchToResume = nil }
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
    @State private var calendarMessage = ""

    var body: some View {
        List {
            Section("Summary") {
                SummaryRow(title: "\(match.status.rawValue) against \(match.opponentSummary.fallback("opponent not recorded"))", value: "\(match.matchType.rawValue). \(match.date.shortTennisDate).")
                SummaryRow(title: "Players", value: "\(match.playerName.fallback("Player")) against \(match.opponentSummary.fallback("opponent not recorded")).")
                SummaryRow(title: "Score", value: "\(match.yourSetsWon)-\(match.opponentSetsWon) sets. \(match.setScores.fallback("set scores not recorded")).")
                SummaryRow(title: "Rules", value: "\(match.sightLevel.rawValue). \(match.allowedBounces) bounces. Sudden-death deuce \(match.suddenDeathDeuce ? "on" : "off").")
                SummaryRow(title: "Place", value: [match.venue, match.location].filter { !$0.isBlank }.joined(separator: ", ").fallback("not recorded"))
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

            Section("Calendar") {
                Button("Add to Apple Calendar") {
                    addToCalendar()
                }
                if !calendarMessage.isBlank {
                    Text(calendarMessage)
                }
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

    private func addToCalendar() {
        Task {
            let success = await TennisCalendarService.shared.save(TennisCalendarMapper.event(for: match))
            calendarMessage = success ? "Added to Apple Calendar." : "Calendar access was not granted or the event could not be saved."
            store.announce(calendarMessage)
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
                    Picker("Status", selection: $match.status) {
                        ForEach(MatchStatus.allCases) { status in Text(status.rawValue).tag(status) }
                    }
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
                    Picker("Tie-break rule", selection: $match.tieBreakRule) {
                        ForEach(TieBreakRule.allCases) { rule in Text(rule.rawValue).tag(rule) }
                    }
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
    let existingMatch: MatchRecord?

    @State private var match: MatchRecord?
    @State private var scorer = TennisScoringEngine()
    @State private var isScoring = false

    var body: some View {
        NavigationStack {
            List {
                if let match {
                    if isScoring {
                        scoringSections(match: match)
                    } else {
                        setupSections(match: match)
                    }
                } else {
                    EmptyStateView(title: "No player set up", message: "Create a player before live scoring.")
                }
            }
            .tennisThemedList()
            .navigationTitle(isScoring ? "Live score" : "Match setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isScoring {
                        Button("Save") { saveProgress(dismissAfterSave: false) }
                            .accessibilityLabel("Save match progress")
                    } else {
                        Button("Start") { startScoring() }
                            .disabled(match == nil)
                    }
                }
            }
            .onAppear(perform: configure)
        }
    }

    @ViewBuilder
    private func setupSections(match: MatchRecord) -> some View {
        Section("Format") {
            Picker("Match type", selection: binding(\.matchType)) {
                ForEach(MatchKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
            }
            DateShortcutPicker(title: "Date", date: binding(\.date))
            Stepper("Expected duration \(match.expectedDurationMinutes) minutes", value: binding(\.expectedDurationMinutes), in: 15...360, step: 15)
        }

        Section("Players") {
            TextField("Player name", text: binding(\.playerName))
                .accessibilityIdentifier("livePlayerNameField")
            if match.matchType == .doubles {
                TextField("Partner", text: binding(\.partnerName))
                TextField("Opponent team player one", text: binding(\.opponentName))
                TextField("Opponent team player two", text: binding(\.opponent2Name))
            } else {
                TextField("Opponent name", text: binding(\.opponentName))
                    .accessibilityIdentifier("liveOpponentNameField")
            }
        }

        Section("Place") {
            TextField("Venue", text: binding(\.venue))
            TextField("Location", text: binding(\.location))
        }

        Section("Rules") {
            Picker("Sight level", selection: binding(\.sightLevel)) {
                ForEach(SightLevel.allCases) { level in Text(level.rawValue).tag(level) }
            }
            .onChange(of: match.sightLevel) { _, newValue in
                self.match?.allowedBounces = newValue.allowedBounces
                self.match?.suddenDeathDeuce = newValue != .fullySighted
            }
            Stepper("Allowed bounces \(match.allowedBounces)", value: binding(\.allowedBounces), in: 1...3)
            Toggle("Sudden-death deuce", isOn: binding(\.suddenDeathDeuce))
                .accessibilityIdentifier("liveSuddenDeathToggle")
            Picker("Tie-break rule", selection: binding(\.tieBreakRule)) {
                ForEach(TieBreakRule.allCases) { rule in Text(rule.rawValue).tag(rule) }
            }
            if match.tieBreakRule != .standardAtSixAll {
                Stepper("Tie-break target \(match.tieBreakTarget)", value: binding(\.tieBreakTarget), in: 1...21)
                Toggle("Win tie-break by two", isOn: binding(\.tieBreakWinByTwo))
            }
        }

        if !store.selectedTournaments.isEmpty || !store.selectedTraining.isEmpty {
            Section("Links") {
                Picker("Tournament", selection: binding(\.tournamentID)) {
                    Text("No tournament").tag(Optional<UUID>.none)
                    ForEach(store.selectedTournaments) { tournament in
                        Text(tournament.name.fallback("Unnamed tournament")).tag(Optional(tournament.id))
                    }
                }
                Picker("Training session", selection: binding(\.trainingSessionID)) {
                    Text("No training session").tag(Optional<UUID>.none)
                    ForEach(store.selectedTraining) { session in
                        Text("\(session.date.shortTennisDate), \(session.trainingType.rawValue)").tag(Optional(session.id))
                    }
                }
            }
        }

        Section {
            Button("Start live scoring") { startScoring() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("startConfiguredLiveScoringButton")
        }
    }

    @ViewBuilder
    private func scoringSections(match: MatchRecord) -> some View {
        Section("Score") {
            Text(scorer.fullScore)
                .font(.title2.bold())
                .accessibilityLabel("Current score")
                .accessibilityValue(scorer.fullScore)
                .accessibilityAddTraits(.isHeader)
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityAction(named: "Hear full score") {
                    announce(scorer.fullScore, force: true)
                }
                .accessibilityAction(named: "Undo last point") {
                    announce(scorer.undo(), force: store.data.settings.scoreAnnouncementMode != .off)
                }
        }

        Section(match.matchType == .doubles ? "Team points" : "Points") {
            Button("Point to \(teamName(for: .player, match: match))") {
                score(.player)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("playerWinsPointButton")

            Button("Point to \(teamName(for: .opponent, match: match))") {
                score(.opponent)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("opponentWinsPointButton")
        }

        Section("Tie-break") {
            Button("Start tie-break now") {
                announce(scorer.startTieBreak(), force: true)
                saveProgress(dismissAfterSave: false, quiet: true)
            }
            .disabled(scorer.state.isTiebreak || scorer.state.isMatchComplete)

            if scorer.state.isTiebreak && match.tieBreakRule == .manual {
                Button("Finish tie-break for \(teamName(for: .player, match: match))") {
                    announce(scorer.finishTieBreak(winner: .player), force: true)
                    saveProgress(dismissAfterSave: false, quiet: true)
                }
                Button("Finish tie-break for \(teamName(for: .opponent, match: match))") {
                    announce(scorer.finishTieBreak(winner: .opponent), force: true)
                    saveProgress(dismissAfterSave: false, quiet: true)
                }
            }
        }

        Section("Actions") {
            Button("Undo") {
                announce(scorer.undo(), force: store.data.settings.scoreAnnouncementMode != .off)
                saveProgress(dismissAfterSave: false, quiet: true)
            }
            .accessibilityIdentifier("undoScoreButton")
            Button("Save progress") {
                saveProgress(dismissAfterSave: false)
            }
            .accessibilityIdentifier("saveLiveProgressButton")
            Button("Save and close") {
                saveProgress(dismissAfterSave: true)
            }
            Button("Hear full score") {
                announce(scorer.fullScore, force: true)
            }
            .accessibilityIdentifier("hearFullScoreButton")
            Button("Reset score", role: .destructive) {
                scorer.reset()
                announce("Score reset. \(scorer.fullScore).", force: store.data.settings.scoreAnnouncementMode != .off)
                saveProgress(dismissAfterSave: false, quiet: true)
            }
            .accessibilityIdentifier("resetScoreButton")
        }
    }

    private func configure() {
        guard match == nil else { return }
        if let existingMatch {
            match = existingMatch
            scorer = TennisScoringEngine(
                playerName: existingMatch.playerName,
                opponentName: teamName(for: .opponent, match: existingMatch),
                suddenDeathDeuce: existingMatch.suddenDeathDeuce,
                tieBreakRule: existingMatch.tieBreakRule,
                tieBreakTarget: existingMatch.tieBreakTarget,
                tieBreakWinByTwo: existingMatch.tieBreakWinByTwo,
                snapshot: existingMatch.liveScore
            )
            isScoring = true
            return
        }
        match = store.makeDefaultMatch()
    }

    private func startScoring() {
        guard let match else { return }
        scorer = TennisScoringEngine(
            playerName: teamName(for: .player, match: match),
            opponentName: teamName(for: .opponent, match: match),
            suddenDeathDeuce: match.suddenDeathDeuce,
            tieBreakRule: match.tieBreakRule,
            tieBreakTarget: match.tieBreakTarget,
            tieBreakWinByTwo: match.tieBreakWinByTwo,
            snapshot: match.liveScore
        )
        isScoring = true
        saveProgress(dismissAfterSave: false, quiet: true)
    }

    private func score(_ winner: PointWinner) {
        let message = scorer.awardPoint(to: winner)
        if store.data.settings.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        saveProgress(dismissAfterSave: false, quiet: true)
        switch store.data.settings.scoreAnnouncementMode {
        case .automatic:
            announce(message, force: true)
        case .reduced:
            let name = winner == .player ? teamName(for: .player, match: match) : teamName(for: .opponent, match: match)
            announce("Point to \(name). \(scorer.state.pointScore(suddenDeathDeuce: match?.suddenDeathDeuce ?? false)).", force: true)
        case .off:
            store.announce(message)
        }
    }

    private func announce(_ message: String, force: Bool) {
        store.announce(message)
        if force {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    private func saveProgress(dismissAfterSave: Bool, quiet: Bool = false) {
        guard var saved = match, store.selectedPlayerID != nil else { return }
        saved.liveScore = scorer.state.snapshot
        saved.status = scorer.state.isMatchComplete ? .completed : .inProgress
        saved.yourSetsWon = scorer.state.playerSets
        saved.opponentSetsWon = scorer.state.opponentSets
        saved.setScores = scorer.state.completedSetScores.joined(separator: ", ")
        saved.hadTiebreak = saved.setScores.contains("7-6") || saved.setScores.contains("6-7") || scorer.state.isTiebreak
        saved.suddenDeathDeuce = saved.suddenDeathDeuce
        if scorer.state.isMatchComplete {
            saved.liveScore = nil
            saved.result = scorer.state.playerSets > scorer.state.opponentSets ? .win : .loss
        }
        match = saved
        store.upsertMatch(saved)
        if !quiet {
            announce(scorer.state.isMatchComplete ? "Saved completed match." : "Saved match progress.", force: store.data.settings.scoreAnnouncementMode != .off)
        }
        if dismissAfterSave {
            dismiss()
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<MatchRecord, Value>) -> Binding<Value> {
        Binding(
            get: { match![keyPath: keyPath] },
            set: { match![keyPath: keyPath] = $0 }
        )
    }

    private func teamName(for winner: PointWinner, match: MatchRecord?) -> String {
        guard let match else { return winner == .player ? "Player" : "Opponent" }
        if match.matchType == .doubles {
            switch winner {
            case .player:
                return [match.playerName, match.partnerName].filter { !$0.isBlank }.joined(separator: " and ").fallback("Your team")
            case .opponent:
                return [match.opponentName, match.opponent2Name].filter { !$0.isBlank }.joined(separator: " and ").fallback("Opponent team")
            }
        }
        return winner == .player ? match.playerName.fallback("Player") : match.opponentName.fallback("Opponent")
    }
}
