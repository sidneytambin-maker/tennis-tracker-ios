import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var matchToEdit: MatchRecord?
    @State private var matchToDelete: MatchRecord?
    @State private var resumeMatch: MatchRecord?
    @State private var showingLiveScorer = false
    @State private var tournamentToEdit: TournamentRecord?
    @State private var matchTournament: TournamentRecord?
    @State private var trainingToEdit: TrainingSession?
    @State private var showingNewTraining = false
    @State private var confirmDeleteMatch = false

    private var stats: TennisStatistics {
        TennisStatistics.build(matches: store.selectedMatches, training: store.selectedTraining, tournaments: store.selectedTournaments)
    }

    private var progress: TennisPlayerProgress {
        TennisPlayerProgress.build(player: store.selectedPlayer, matches: store.selectedMatches, training: store.selectedTraining)
    }

    private var nextTournament: TournamentRecord? {
        store.selectedTournaments
            .filter { !$0.isCompleted }
            .sorted { $0.date < $1.date }
            .first
    }

    private var needsDetailsCount: Int {
        store.selectedMatches.filter(\.needsDetails).count
        + store.selectedTraining.filter(\.needsDetails).count
        + store.selectedTournaments.filter(\.needsDetails).count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.data.settings.theme == .tennis {
                        TennisDashboardHeader(name: store.selectedPlayer?.displayName ?? "Player", stats: stats)
                            .listRowBackground(TennisSportStyle.ink)
                    } else {
                        SummaryRow(title: "Welcome, \(store.selectedPlayer?.displayName ?? "player")", value: stats.spokenSummary)
                    }
                }

                Section("Match results, all time") {
                    TennisResultDashboardRow(title: "Singles matches", totals: progress.singles, symbol: "person.fill")
                    TennisResultDashboardRow(title: "Doubles matches", totals: progress.doubles, symbol: "person.2.fill")
                }

                Section("Current activity") {
                    if let training = store.selectedTraining.first(where: \.isActive) {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            NavigationLink(store.trainingSummary(training, now: context.date)) {
                                TrainingDetailView(session: training)
                            }
                        }
                    }
                    if let match = store.selectedMatches.first(where: { $0.status == .inProgress }) {
                        Button(TennisSummaryFormatter.match(match)) {
                            resumeMatch = match
                            showingLiveScorer = true
                        }
                        .accessibilityHint("Resumes match scoring.")
                    }
                    if !store.selectedTraining.contains(where: \.isActive) && !store.selectedMatches.contains(where: { $0.status == .inProgress }) {
                        Text("No activity in progress.")
                    }
                }

                Section("Next activity") {
                    if let training = store.selectedTraining.filter({ $0.actualStart == nil && $0.date >= Date() }).min(by: { $0.date < $1.date }) {
                        NavigationLink(store.trainingSummary(training)) { TrainingDetailView(session: training) }
                    }
                    if let match = store.selectedMatches.filter({ $0.status == .scheduled && $0.date >= Date() }).min(by: { $0.date < $1.date }) {
                        NavigationLink(TennisSummaryFormatter.match(match, tournaments: store.selectedTournaments)) { MatchDetailView(match: match) }
                    }
                }

                Section("Recent matches") {
                    if !store.selectedMatches.contains(where: { $0.status == .completed }) {
                        Text("No recent matches recorded.")
                    } else {
                        ForEach(store.selectedMatches.filter { $0.status == .completed }.prefix(3)) { match in
                            NavigationLink(TennisSummaryFormatter.match(match, tournaments: store.selectedTournaments, style: .long)) {
                                MatchDetailView(match: match)
                            }
                            .accessibilityAction(named: "Edit match") {
                                matchToEdit = match
                            }
                            .accessibilityAction(named: "Add Match to Calendar") {
                                addMatchToCalendar(match)
                            }
                            .accessibilityAction(named: "Delete match") {
                                matchToDelete = match
                                confirmDeleteMatch = true
                            }
                            .modifier(ResumeLiveScoreAction(match: match, resume: {
                                resumeMatch = match
                                showingLiveScorer = true
                            }))
                        }
                    }
                }

                Section("Training activity") {
                    if let recent = store.selectedTraining.filter({ !$0.isActive && ($0.actualFinish != nil || $0.expectedEndDate < Date()) }).first {
                        NavigationLink(store.trainingSummary(recent)) { TrainingDetailView(session: recent) }
                    }
                    SummaryRow(title: "Training activity", value: stats.trainingCountLast30Days == 0 ? "No training recorded in the last 30 days." : "\(stats.trainingCountLast30Days) \(stats.trainingCountLast30Days == 1 ? "session" : "sessions") recorded. \(TennisDurationFormatter.text(seconds: stats.trainingSecondsLast30Days)) in the last 30 days.")
                        .accessibilityAction(named: "Track Training Session") {
                            showingNewTraining = true
                        }
                }

                Section("Training focus, last 30 days") {
                    if progress.focus.isEmpty { Text("No completed training recorded in the last 30 days.") }
                    ForEach(progress.focus) { item in
                        TennisFocusDashboardRow(item: item, maximum: progress.focus.map(\.sessions).max() ?? 1)
                    }
                    Button("Plan Training Focus") { showingNewTraining = true }
                    if let session = store.selectedTraining.first(where: { $0.focus.isBlank }) {
                        Button { trainingToEdit = session } label: {
                            Label("Choose Focus for \(session.date.fullTennisDate)", systemImage: "scope")
                        }
                    }
                }

                Section("Training types, last 30 days") {
                    if progress.trainingTypes.isEmpty { Text("No completed training recorded in the last 30 days.") }
                    ForEach(progress.trainingTypes) { item in
                        SummaryRow(title: item.focus, value: item.summary)
                    }
                }

                Section("Training practice results, all time") {
                    TennisResultDashboardRow(title: "Singles practice matches", totals: progress.singlesPractice, symbol: "figure.tennis")
                    TennisResultDashboardRow(title: "Doubles practice matches", totals: progress.doublesPractice, symbol: "person.2.fill")
                }

                Section("What to work on") {
                    if progress.suggestions.isEmpty {
                        Text("No personal goals or match-review priorities recorded.")
                    }
                    ForEach(progress.suggestions) { suggestion in
                        SummaryRow(title: suggestion.source, value: suggestion.detail)
                    }
                    Button("Plan Next Training Session") { showingNewTraining = true }
                }

                if store.data.settings.showUpcomingTournaments {
                    Section("Upcoming tournaments") {
                        if let nextTournament {
                            SummaryRow(title: "Next tournament", value: TennisSummaryFormatter.tournament(nextTournament, matches: store.selectedMatches))
                                .accessibilityAction(named: "Edit tournament") {
                                    tournamentToEdit = nextTournament
                                }
                                .accessibilityAction(named: "Add Match to Tournament") {
                                    matchTournament = nextTournament
                                }
                                .accessibilityAction(named: "Add tournament to Calendar") {
                                    addTournamentToCalendar(nextTournament)
                                }
                        } else {
                            Text("No upcoming tournaments recorded.")
                        }
                    }
                }

                if store.data.settings.showNeedsAttention && !stats.needsAttention.isEmpty {
                    Section("Needs attention") {
                        ForEach(stats.needsAttention, id: \.self) { item in
                            Text(item)
                        }
                    }
                }

                if store.data.settings.showNeedsAttention && needsDetailsCount > 0 {
                    Section("Activities Need Details") {
                        Text("\(needsDetailsCount) activities need details.")
                        if let training = store.selectedTraining.first(where: \.needsDetails) {
                            Button("Complete Training Details") {
                                var draft = training
                                draft.markDetailsComplete()
                                trainingToEdit = draft
                            }
                        }
                        if let match = store.selectedMatches.first(where: \.needsDetails) {
                            Button("Complete Match Details") {
                                matchToEdit = match
                            }
                            Button("Mark Match Complete") {
                                store.completeMatchDetails(match.id)
                            }
                        }
                    }
                }

            }
            .tennisThemedList()
            .navigationTitle("Dashboard")
            .sheet(item: $matchToEdit) { match in
                MatchEditorView(match: match)
            }
            .sheet(isPresented: $showingLiveScorer) {
                LiveMatchView(existingMatch: resumeMatch)
                    .onDisappear { resumeMatch = nil }
            }
            .sheet(item: $tournamentToEdit) { tournament in
                TournamentEditorView(tournament: tournament)
            }
            .sheet(item: $matchTournament) { tournament in
                if let match = store.makeDefaultMatch(tournamentID: tournament.id) {
                    MatchEditorView(match: match)
                }
            }
            .sheet(isPresented: $showingNewTraining) {
                if let session = store.makeDefaultTraining() {
                    TrainingEditorView(session: session)
                }
            }
            .sheet(item: $trainingToEdit) { session in
                TrainingEditorView(session: session)
            }
            .confirmationDialog("Delete this match?", isPresented: $confirmDeleteMatch, titleVisibility: .visible) {
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

    private func matchLine(_ match: MatchRecord) -> String {
        TennisSummaryFormatter.match(match, tournaments: store.selectedTournaments, style: .long)
    }

    private func addMatchToCalendar(_ match: MatchRecord) {
        Task {
            await store.addToCalendar(TennisCalendarMapper.event(for: match))
        }
    }

    private func addTournamentToCalendar(_ tournament: TournamentRecord) {
        Task {
            await store.addToCalendar(TennisCalendarMapper.event(for: tournament))
        }
    }
}

private struct ResumeLiveScoreAction: ViewModifier {
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
