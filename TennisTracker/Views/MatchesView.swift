import SwiftUI
import UIKit

struct MatchesView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var showingNewMatch = false
    @State private var showingLiveScorer = false
    @State private var liveMatchToResume: MatchRecord?
    @State private var matchToEdit: MatchRecord?
    @State private var matchToDelete: MatchRecord?
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section("Match scoring") {
                    Button("Track Match Scoring") {
                        showingLiveScorer = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Opens a point by point scorer with player and opponent names.")

                    ForEach(store.resumableMatches()) { match in
                        Button("Resume Match Scoring, \(match.opponentSummary.fallback("match"))") {
                            liveMatchToResume = match
                            showingLiveScorer = true
                        }
                        .accessibilityHint("Continues this saved live score from where you left it.")
                    }
                }

                Section("Record") {
                    Button("Record Match") { showingNewMatch = true }
                        .accessibilityLabel("Record Match")
                        .accessibilityIdentifier("addMatchButton")
                }

                Section("Match history") {
                    if store.selectedMatches.isEmpty {
                        EmptyStateView(title: "No matches recorded yet", message: "Use Record Match or Track Match Scoring.")
                    } else {
                        ForEach(store.selectedMatches) { match in
                            NavigationLink {
                                MatchDetailView(match: match)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(TennisSummaryFormatter.match(match, tournaments: store.selectedTournaments, style: .long))
                                    Text(match.matchType.rawValue)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityLabel("Match")
                            .accessibilityValue(TennisSummaryFormatter.match(match, tournaments: store.selectedTournaments, style: .accessibility))
                            .accessibilityAction(named: "Edit match") {
                                matchToEdit = match
                            }
                            .accessibilityAction(named: "Add to Calendar") {
                                addToCalendar(match)
                            }
                            .accessibilityAction(named: "Delete match") {
                                matchToDelete = match
                                confirmDelete = true
                            }
                            .modifier(MatchResumeAction(match: match, resume: {
                                liveMatchToResume = match
                                showingLiveScorer = true
                            }))
                        }
                    }
                }
            }
            .tennisThemedList()
            .navigationTitle("Matches")
            .sheet(isPresented: $showingNewMatch) {
                if let match = store.makeDefaultMatch() {
                    MatchEditorView(match: match)
                }
            }
            .sheet(item: $matchToEdit) { match in
                MatchEditorView(match: match)
            }
            .sheet(isPresented: $showingLiveScorer) {
                LiveMatchView(existingMatch: liveMatchToResume)
                    .onDisappear { liveMatchToResume = nil }
            }
            .confirmationDialog("Delete this match?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Match", role: .destructive) {
                    if let matchToDelete {
                        store.deleteMatch(matchToDelete)
                    }
                    matchToDelete = nil
                }
                Button("Cancel", role: .cancel) { matchToDelete = nil }
            }
        }
    }

    private func addToCalendar(_ match: MatchRecord) {
        Task {
            let success = await TennisCalendarService.shared.save(TennisCalendarMapper.event(for: match))
            store.announce(success ? "Added match to Apple Calendar." : "Calendar access was not granted or the event could not be saved.")
        }
    }

    private func scoreSummary(_ match: MatchRecord) -> String {
        TennisSummaryFormatter.matchSummary(match, tournaments: store.selectedTournaments).scoreText
    }
}

private struct MatchResumeAction: ViewModifier {
    let match: MatchRecord
    let resume: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if match.status == .inProgress && match.liveScore != nil {
            content.accessibilityAction(named: "Resume Match Scoring") { resume() }
        } else {
            content
        }
    }
}

struct MatchDetailView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State var match: MatchRecord
    @State private var showingEditor = false
    @State private var confirmDelete = false
    @State private var calendarMessage = ""

    var body: some View {
        List {
            Section("Summary") {
                SummaryRow(title: TennisSummaryFormatter.match(match, tournaments: store.selectedTournaments, style: .short), value: "\(match.matchType.rawValue). \(match.date.shortTennisDate).")
                SummaryRow(title: "Players", value: "\(match.playerTeam) against \(match.opponentSummary.fallback("opponent not recorded")).")
                SummaryRow(title: "Score", value: TennisSummaryFormatter.matchSummary(match).scoreText)
                SummaryRow(title: "Rules", value: "\(match.sightLevel.label). \(match.allowedBounces) bounces. Sudden-death deuce \(match.suddenDeathDeuce ? "on" : "off").")
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
        .onChange(of: store.data.matches) { _, matches in
            if let updated = matches.first(where: { $0.id == match.id }) { match = updated }
            else { dismiss() }
        }
        .toolbar {
            Button("Edit") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            MatchEditorView(match: match)
        }
        .confirmationDialog("Delete this match?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Match", role: .destructive) {
                store.deleteMatch(match)
            }
            Button("Cancel", role: .cancel) {}
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
    @State private var setCount = 0
    @State private var playerGames = Array(repeating: 0, count: 5)
    @State private var opponentGames = Array(repeating: 0, count: 5)
    @State private var tiebreakSets = Set<Int>()

    var body: some View {
        NavigationStack {
            Form {
                Section("Match details") {
                    AccessibleDateTimeEditor(dateTitle: "Date", timeTitle: "Start time", date: $match.date, hasStartTime: $match.hasStartTime)
                        .accessibilityIdentifier("matchDatePicker")
                    Toggle("Expected duration known", isOn: $match.hasExpectedDuration)
                    if match.hasExpectedDuration {
                        DurationFields(minutes: $match.expectedDurationMinutes, minimumMinutes: 15)
                    }
                    Picker("Status", selection: $match.status) {
                        ForEach(MatchStatus.allCases) { status in Text(status.rawValue).tag(status) }
                    }
                    Picker("Match type", selection: $match.matchType) {
                        ForEach(MatchKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
                    }
                }

                Section("Players") {
                    TextField("Player name", text: $match.playerName)
                        .accessibilityIdentifier("matchPlayerNameField")
                    TennisPersonPicker(title: "Opponent name", players: store.data.players.filter { $0.id != match.playerID }, selection: $match.opponentID, name: $match.opponentName, fieldIdentifier: "matchOpponentNameField")
                    if match.matchType == .doubles {
                        TennisPersonPicker(title: "Partner", players: store.data.players.filter { $0.id != match.playerID && $0.id != match.opponentID }, selection: $match.partnerID, name: $match.partnerName, regularPartnersFirst: true)
                        TennisPersonPicker(title: "Second opponent", players: store.data.players.filter { $0.id != match.playerID && $0.id != match.opponentID && $0.id != match.partnerID }, selection: $match.opponent2ID, name: $match.opponent2Name)
                    }
                }

                Section("Place") {
                    StoredVenuePicker(id: $match.venueID, venue: $match.venue, location: $match.location)
                }

                Section("Format") {
                    Picker("Match format", selection: $match.matchFormat) {
                        ForEach(MatchFormat.allCases) { format in Text(format.label).tag(format) }
                    }
                    .accessibilityIdentifier("matchFormatPicker")
                    .onChange(of: match.matchFormat) { _, newValue in
                        setCount = min(max(setCount, newValue.defaultSetsToEnter), newValue.maximumSetsToEnter)
                    }
                    Picker("Sight level", selection: $match.sightLevel) {
                        ForEach(SightLevel.allCases) { level in Text(level.label).tag(level) }
                    }
                    .onChange(of: match.sightLevel) { _, newValue in
                        match.allowedBounces = newValue.allowedBounces
                        match.suddenDeathDeuce = newValue != .fullySighted
                    }
                    Picker("Allowed bounces", selection: $match.allowedBounces) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                    }
                    .accessibilityValue("\(match.allowedBounces)")
                    Toggle("Sudden-death deuce", isOn: $match.suddenDeathDeuce)
                        .accessibilityIdentifier("matchSuddenDeathToggle")
                    Picker("Tie-break rule", selection: $match.tieBreakRule) {
                        ForEach(TieBreakRule.allCases) { rule in Text(rule.rawValue).tag(rule) }
                    }
                    if match.tieBreakRule == .manual {
                        Picker("Tie-break target", selection: $match.tieBreakTarget) {
                            ForEach([7, 10, 12, 21], id: \.self) { target in
                                Text("\(target)").tag(target)
                            }
                        }
                        .accessibilityValue("\(match.tieBreakTarget)")
                        Toggle("Win tie-break by two", isOn: $match.tieBreakWinByTwo)
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
                        .onChange(of: match.tournamentID) { _, _ in
                            applyTournamentDefaults()
                        }
                        if let tournament = linkedTournament {
                            SummaryRow(title: "Tournament date range", value: tournamentDateRange(tournament))
                        }

                        Picker("Training session", selection: $match.trainingSessionID) {
                            Text("No training session").tag(Optional<UUID>.none)
                            ForEach(store.selectedTraining) { session in
                                Text("\(session.date.shortTennisDate), \(session.trainingType.rawValue)").tag(Optional(session.id))
                            }
                        }
                        .accessibilityIdentifier("matchTrainingPicker")
                    }
                }

                Section("Result") {
                    if match.status == .completed {
                        if match.matchFormat == .custom {
                            Picker("Result", selection: $match.result) {
                                ForEach(MatchResult.allCases) { result in Text(result.rawValue).tag(result) }
                            }
                            NumberChoicePicker(title: "Player sets won", value: $match.yourSetsWon, range: 0...5, suffix: "sets")
                            NumberChoicePicker(title: "Opponent sets won", value: $match.opponentSetsWon, range: 0...5, suffix: "sets")
                            TextField("Set scores", text: $match.setScores)
                        } else {
                            ForEach(0..<setCount, id: \.self) { index in
                                SetScoreEntryRow(
                                    setNumber: index + 1,
                                    playerGames: binding($playerGames, index: index),
                                    opponentGames: binding($opponentGames, index: index),
                                    hadTiebreak: tiebreakBinding(index)
                                )
                            }
                            SummaryRow(title: "Calculated result", value: calculatedResultSummary)
                        }
                        if match.matchFormat == .custom || !tiebreakSets.isEmpty || match.hadTiebreak {
                            TextField("Tie-break notes", text: $match.tiebreakScore)
                        }
                    } else if match.status == .inProgress {
                        SummaryRow(title: "In-progress score", value: match.liveScore == nil ? "No live score saved yet." : liveScoreSummary)
                    } else {
                        Text("No result needed for a scheduled match.")
                            .foregroundStyle(.secondary)
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
                        NumberChoicePicker(title: "Aces", value: $match.aces, range: 0...99)
                        NumberChoicePicker(title: "Double faults", value: $match.doubleFaults, range: 0...99)
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
            .onAppear(perform: loadScoreRows)
            .onChange(of: playerGames) { _, _ in updateRequiredSets() }
            .onChange(of: opponentGames) { _, _ in updateRequiredSets() }
            .onChange(of: match.matchFormat) { _, _ in updateRequiredSets() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        keepDateInsideLinkedTournament()
                        applyCalculatedScoreIfNeeded()
                        match.needsDetails = match.opponentName.isBlank || match.opponentName == "Opponent"
                            || (match.matchType == .doubles && (match.partnerName.isBlank || match.opponent2Name.isBlank))
                            || (match.status == .completed && match.setScores.isBlank)
                        store.upsertMatch(match)
                        dismiss()
                    }
                    .accessibilityIdentifier("saveMatchButton")
                }
            }
        }
    }

    private var calculatedResultSummary: String {
        let score = calculatedScore()
        let result = score.playerSets > score.opponentSets ? "Win" : score.opponentSets > score.playerSets ? "Loss" : "Draw"
        let setText = score.setScores.isBlank ? "no completed sets entered" : score.setScores
        return "\(result), \(setText)."
    }

    private func updateRequiredSets() {
        guard match.matchFormat != .custom else { return }
        setCount = TennisSetEntry.requiredRows(format: match.matchFormat, player: playerGames, opponent: opponentGames)
    }

    private var liveScoreSummary: String {
        guard let liveScore = match.liveScore else { return "No live score saved yet." }
        let sets = "sets \(liveScore.playerSets)-\(liveScore.opponentSets)"
        let games = "games \(liveScore.playerGames)-\(liveScore.opponentGames)"
        return "\(games), \(sets)."
    }

    private var linkedTournament: TournamentRecord? {
        guard let tournamentID = match.tournamentID else { return nil }
        return store.selectedTournaments.first { $0.id == tournamentID }
    }

    private func applyTournamentDefaults() {
        guard let tournament = linkedTournament else { return }
        match.date = tournament.date
        match.hasStartTime = tournament.hasStartTime && !tournament.isAllDay
        match.venueID = tournament.venueID
        match.venue = tournament.venue
        match.location = tournament.location
        match.sightLevel = sightLevel(from: tournament.category) ?? match.sightLevel
        match.allowedBounces = match.sightLevel.allowedBounces
        if tournament.format == .roundRobin {
            match.matchPosition = .roundRobin
        }
    }

    private func keepDateInsideLinkedTournament() {
        guard let tournament = linkedTournament else { return }
        let calendar = Calendar.current
        let matchDay = calendar.startOfDay(for: match.date)
        let startDay = calendar.startOfDay(for: tournament.date)
        let endDay = calendar.startOfDay(for: tournament.endDate)
        if matchDay < startDay {
            match.date = calendar.dateByKeepingTime(from: match.date, on: tournament.date)
        } else if matchDay > endDay {
            match.date = calendar.dateByKeepingTime(from: match.date, on: tournament.endDate)
        }
    }

    private func tournamentDateRange(_ tournament: TournamentRecord) -> String {
        if Calendar.current.isDate(tournament.date, inSameDayAs: tournament.endDate) {
            return tournament.date.shortTennisDate
        }
        return "\(tournament.date.shortTennisDate) to \(tournament.endDate.shortTennisDate)"
    }

    private func sightLevel(from category: String) -> SightLevel? {
        let normalized = category.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return nil }
        return SightLevel.allCases.first { $0.rawValue.uppercased().hasPrefix(normalized) }
    }

    private func loadScoreRows() {
        guard setCount == 0 else { return }
        setCount = min(max(match.setsPlayed, match.matchFormat.defaultSetsToEnter), match.matchFormat.maximumSetsToEnter)
        let parsed = match.setScores
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for (index, score) in parsed.prefix(5).enumerated() {
            let parts = score.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            guard parts.count == 2 else { continue }
            playerGames[index] = parts[0]
            opponentGames[index] = parts[1]
            if abs(parts[0] - parts[1]) == 1 && max(parts[0], parts[1]) >= 7 {
                tiebreakSets.insert(index)
            }
        }
        if match.hadTiebreak && tiebreakSets.isEmpty {
            tiebreakSets.insert(0)
        }
    }

    private func calculatedScore() -> (playerSets: Int, opponentSets: Int, setScores: String, hadTiebreak: Bool) {
        var playerSets = 0
        var opponentSets = 0
        var entered: [String] = []
        var hadTiebreak = false
        for index in 0..<setCount {
            let player = playerGames[index]
            let opponent = opponentGames[index]
            guard player > 0 || opponent > 0 else { continue }
            entered.append("\(player)-\(opponent)")
            if player > opponent { playerSets += 1 }
            if opponent > player { opponentSets += 1 }
            if tiebreakSets.contains(index) || (abs(player - opponent) == 1 && max(player, opponent) >= 7) {
                hadTiebreak = true
            }
        }
        return (playerSets, opponentSets, entered.joined(separator: ", "), hadTiebreak)
    }

    private func applyCalculatedScoreIfNeeded() {
        guard match.status == .completed, match.matchFormat != .custom else { return }
        let score = calculatedScore()
        match.yourSetsWon = score.playerSets
        match.opponentSetsWon = score.opponentSets
        match.setScores = score.setScores
        match.hadTiebreak = score.hadTiebreak
        if score.playerSets > score.opponentSets {
            match.result = .win
        } else if score.opponentSets > score.playerSets {
            match.result = .loss
        } else {
            match.result = .draw
        }
    }

    private func binding(_ values: Binding<[Int]>, index: Int) -> Binding<Int> {
        Binding(
            get: { values.wrappedValue[index] },
            set: {
                var copy = values.wrappedValue
                copy[index] = $0
                values.wrappedValue = copy
            }
        )
    }

    private func tiebreakBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { tiebreakSets.contains(index) },
            set: { isOn in
                if isOn {
                    tiebreakSets.insert(index)
                } else {
                    tiebreakSets.remove(index)
                }
            }
        )
    }
}

struct SetScoreEntryRow: View {
    let setNumber: Int
    @Binding var playerGames: Int
    @Binding var opponentGames: Int
    @Binding var hadTiebreak: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text("Set \(setNumber)")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Picker("Player games", selection: $playerGames) {
                ForEach(0...30, id: \.self) { games in
                    Text("\(games)").tag(games)
                }
            }
            .accessibilityValue("\(playerGames)")
            Picker("Opponent games", selection: $opponentGames) {
                ForEach(0...30, id: \.self) { games in
                    Text("\(games)").tag(games)
                }
            }
            .accessibilityValue("\(opponentGames)")
            Toggle("Set decided by tie-break", isOn: $hadTiebreak)
        }
        .accessibilityElement(children: .contain)
    }
}

struct LiveMatchView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    let existingMatch: MatchRecord?

    @State private var match: MatchRecord?
    @State private var scorer = TennisScoringEngine()
    @State private var isScoring = false
    @State private var confirmDiscard = false
    @State private var confirmReset = false

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
                    Button(isScoring ? "Close" : "Cancel") {
                        if isScoring {
                            saveProgress(dismissAfterSave: true, quiet: true)
                        } else {
                            confirmDiscard = true
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isScoring {
                        Button("Save Match Progress") { saveProgress(dismissAfterSave: false) }
                            .accessibilityLabel("Save Match Progress")
                    } else {
                        Button("Track Match Scoring") { startScoring() }
                            .disabled(match == nil)
                            .accessibilityIdentifier("startConfiguredLiveScoringButton")
                    }
                }
            }
            .onAppear(perform: configure)
            .confirmationDialog("Discard this live match setup?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard Setup", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Reset the recorded score?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset Score", role: .destructive) {
                    scorer.reset()
                    saveProgress(dismissAfterSave: false, quiet: true)
                    announce("Score reset.", force: true)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func setupSections(match: MatchRecord) -> some View {
        Section("Format") {
            Picker("Match format", selection: binding(\.matchFormat)) {
                ForEach(MatchFormat.allCases) { format in Text(format.label).tag(format) }
            }
            Picker("Match type", selection: binding(\.matchType)) {
                ForEach(MatchKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
            }
            AccessibleDateTimeEditor(dateTitle: "Date", timeTitle: "Start time", date: binding(\.date), hasStartTime: binding(\.hasStartTime))
            Toggle("Expected duration known", isOn: binding(\.hasExpectedDuration))
            if match.hasExpectedDuration {
                DurationFields(minutes: binding(\.expectedDurationMinutes), minimumMinutes: 15)
            }
        }

        Section("Players") {
            TextField("Player name", text: binding(\.playerName))
                .accessibilityIdentifier("livePlayerNameField")
            if match.matchType == .doubles {
                TennisPersonPicker(title: "Partner", players: store.data.players.filter { $0.id != match.playerID }, selection: binding(\.partnerID), name: binding(\.partnerName), regularPartnersFirst: true)
                TennisPersonPicker(title: "Opponent team player one", players: store.data.players.filter { $0.id != match.playerID && $0.id != match.partnerID }, selection: binding(\.opponentID), name: binding(\.opponentName))
                TennisPersonPicker(title: "Opponent team player two", players: store.data.players.filter { $0.id != match.playerID && $0.id != match.partnerID && $0.id != match.opponentID }, selection: binding(\.opponent2ID), name: binding(\.opponent2Name))
            } else {
                TennisPersonPicker(title: "Opponent name", players: store.data.players.filter { $0.id != match.playerID }, selection: binding(\.opponentID), name: binding(\.opponentName), fieldIdentifier: "liveOpponentNameField")
            }
        }

        Section("Place") {
            StoredVenuePicker(id: binding(\.venueID), venue: binding(\.venue), location: binding(\.location))
        }

        Section("Rules") {
            Picker("Sight level", selection: binding(\.sightLevel)) {
                ForEach(SightLevel.allCases) { level in Text(level.label).tag(level) }
            }
            .onChange(of: match.sightLevel) { _, newValue in
                self.match?.allowedBounces = newValue.allowedBounces
                self.match?.suddenDeathDeuce = newValue != .fullySighted
            }
            Picker("Allowed bounces", selection: binding(\.allowedBounces)) {
                Text("1").tag(1)
                Text("2").tag(2)
                Text("3").tag(3)
            }
            .accessibilityValue("\(match.allowedBounces)")
            Toggle("Sudden-death deuce", isOn: binding(\.suddenDeathDeuce))
                .accessibilityIdentifier("liveSuddenDeathToggle")
            Picker("Tie-break rule", selection: binding(\.tieBreakRule)) {
                ForEach(TieBreakRule.allCases) { rule in Text(rule.rawValue).tag(rule) }
            }
            if match.tieBreakRule == .manual {
                Picker("Tie-break target", selection: binding(\.tieBreakTarget)) {
                    ForEach([7, 10, 12, 21], id: \.self) { target in
                        Text("\(target)").tag(target)
                    }
                }
                .accessibilityValue("\(match.tieBreakTarget)")
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
            Button("Track Match Scoring") { startScoring() }
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
                .accessibilityAction(named: "Save Match Progress") {
                    saveProgress(dismissAfterSave: false)
                }
                .accessibilityAction(named: "Start tie-break") {
                    startTieBreak()
                }
                .accessibilityAction(named: "Finish Match") {
                    endMatch(winner: scorer.state.playerSets >= scorer.state.opponentSets ? .player : .opponent)
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
            Button("Start Tie-break") {
                startTieBreak()
            }
            .disabled(scorer.state.isTiebreak || scorer.state.isMatchComplete)

            if scorer.state.isTiebreak && match.tieBreakRule == .manual {
                Button("Finish tie-break for \(teamName(for: .player, match: match))") {
                    finishTieBreak(winner: .player)
                }
                Button("Finish tie-break for \(teamName(for: .opponent, match: match))") {
                    finishTieBreak(winner: .opponent)
                }
            }
        }

        Section("Actions") {
            Button("Undo") {
                announce(scorer.undo(), force: store.data.settings.scoreAnnouncementMode != .off)
                saveProgress(dismissAfterSave: false, quiet: true)
            }
            .accessibilityIdentifier("undoScoreButton")
            Button("Save Match Progress") {
                saveProgress(dismissAfterSave: false)
            }
            .accessibilityIdentifier("saveLiveProgressButton")
            Button("Save Match Progress and Close") {
                saveProgress(dismissAfterSave: true)
            }
            Button("Hear full score") {
                announce(scorer.fullScore, force: true)
            }
            .accessibilityIdentifier("hearFullScoreButton")
            Button("Reset score", role: .destructive) {
                confirmReset = true
            }
            .accessibilityIdentifier("resetScoreButton")
            Button("Finish Match for \(teamName(for: .player, match: match))") {
                endMatch(winner: .player)
            }
            Button("Finish Match for \(teamName(for: .opponent, match: match))") {
                endMatch(winner: .opponent)
            }
        }
    }

    private func configure() {
        guard match == nil else { return }
        if let existingMatch {
            match = existingMatch
            scorer = TennisScoringEngine(
                playerName: existingMatch.playerTeam,
                opponentName: teamName(for: .opponent, match: existingMatch),
                suddenDeathDeuce: existingMatch.suddenDeathDeuce,
                tieBreakRule: existingMatch.tieBreakRule,
                tieBreakTarget: existingMatch.tieBreakTarget,
                tieBreakWinByTwo: existingMatch.tieBreakWinByTwo,
                setsNeededToWin: existingMatch.matchFormat.setsNeededToWin,
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
            setsNeededToWin: match.matchFormat.setsNeededToWin,
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
            announce("\(TennisSummaryFormatter.scoreAnnouncement(state: scorer.state, playerName: teamName(for: .player, match: match), opponentName: teamName(for: .opponent, match: match), suddenDeathDeuce: match?.suddenDeathDeuce ?? false)) Point to \(name).", force: true)
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

    private func startTieBreak() {
        announce(scorer.startTieBreak(), force: true)
        saveProgress(dismissAfterSave: false, quiet: true)
    }

    private func finishTieBreak(winner: PointWinner) {
        announce(scorer.finishTieBreak(winner: winner), force: true)
        saveProgress(dismissAfterSave: false, quiet: true)
    }

    private func endMatch(winner: PointWinner) {
        guard let match else { return }
        var finished = TennisWatchActivityFactory.finishMatch(match, score: scorer.state)
        finished.result = winner == .player ? .win : .loss
        store.upsertMatch(finished)
        announce(TennisSummaryFormatter.match(finished), force: true)
        dismiss()
    }

    private func saveProgress(dismissAfterSave: Bool, quiet: Bool = false) {
        guard var saved = match, store.selectedPlayerID != nil else { return }
        saved.liveScore = scorer.state.snapshot
        saved.status = scorer.state.isMatchComplete ? .completed : .inProgress
        saved.yourSetsWon = scorer.state.playerSets
        saved.opponentSetsWon = scorer.state.opponentSets
        saved.setScores = scorer.state.completedSetScores.joined(separator: ", ")
        saved.hadTiebreak = saved.setScores.contains("7-6") || saved.setScores.contains("6-7") || scorer.state.isTiebreak
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
