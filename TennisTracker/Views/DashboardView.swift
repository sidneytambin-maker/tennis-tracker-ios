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
    @State private var focusToEdit: TrainingSession?
    @State private var showingGoals = false
    @State private var showingMatchReviews = false

    private var stats: TennisStatistics {
        TennisStatistics.build(matches: store.selectedMatches, training: store.selectedTraining, tournaments: store.selectedTournaments)
    }

    private var progress: TennisPlayerProgress {
        TennisPlayerProgress.build(player: store.selectedPlayer, matches: store.selectedMatches, training: store.selectedTraining, coaches: store.data.setup.coaches)
    }

    private var nextTournament: TournamentRecord? {
        store.selectedTournaments
            .filter { !$0.isCompleted }
            .sorted { $0.date < $1.date }
            .first
    }

    var body: some View {
        NavigationStack {
            TennisList {
                Section {
                    if store.data.settings.theme == .tennis {
                        TennisDashboardHeader(name: store.selectedPlayer?.displayName ?? "Player")
                    } else {
                        Text("Welcome, \(store.selectedPlayer?.displayName ?? "player")").font(.title2.bold())
                    }
                }

                TennisSection("Match results, all time") {
                    TennisResultDashboardRow(title: "Singles matches", totals: progress.singles, symbol: "person.fill", trainingMatchCount: progress.singlesPractice.count)
                    TennisResultDashboardRow(title: "Doubles matches", totals: progress.doubles, symbol: "person.2.fill", trainingMatchCount: progress.doublesPractice.count)
                }

                if store.selectedTraining.contains(where: \.isActive) || store.selectedMatches.contains(where: { $0.status == .inProgress }) {
                  TennisSection("Current activity") {
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
                  }
                }

                TennisSection("Next activity") {
                    if let training = store.selectedTraining.filter({ $0.actualStart == nil && $0.date >= Date() }).min(by: { $0.date < $1.date }) {
                        NavigationLink(store.trainingSummary(training)) { TrainingDetailView(session: training) }
                    }
                    if let match = store.selectedMatches.filter({ $0.status == .scheduled && $0.date >= Date() }).min(by: { $0.date < $1.date }) {
                        NavigationLink(TennisSummaryFormatter.match(match, tournaments: store.selectedTournaments)) { MatchDetailView(match: match) }
                    }
                    if !store.selectedTraining.contains(where: { $0.actualStart == nil && $0.date >= Date() }) &&
                        !store.selectedMatches.contains(where: { $0.status == .scheduled && $0.date >= Date() }) {
                        Text("Nothing scheduled.")
                    }
                }

                TennisSection("Recent matches") {
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

                TennisSection("Training activity") {
                    SummaryRow(title: "Last 30 days", value: stats.trainingCountLast30Days == 0 ? "No training recorded." : "\(stats.trainingCountLast30Days) \(stats.trainingCountLast30Days == 1 ? "session" : "sessions") recorded. \(TennisDurationFormatter.text(seconds: stats.trainingSecondsLast30Days)).")
                        .accessibilityAction(named: "Track Training Session") {
                            showingNewTraining = true
                        }
                    ForEach(progress.trainingTypes) { item in
                        SummaryRow(title: item.focus, value: item.summary)
                    }
                }

                Section {
                    NavigationLink { TennisAchievementsView(achievements: store.data.achievements).tennisThemedList() } label: {
                        TennisAchievementsSummary(achievements: store.data.achievements)
                    }
                }

                TennisSection("Training focus, last 30 days") {
                    if progress.focus.isEmpty { Text("No completed training recorded in the last 30 days.") }
                    ForEach(progress.focus) { item in
                        TennisFocusDashboardRow(item: item, maximum: progress.focus.map(\.sessions).max() ?? 1)
                    }
                    if let id = progress.trainingNeedingFocus.first, let session = store.selectedTraining.first(where: { $0.id == id }) {
                        Button { focusToEdit = session } label: {
                            Label("Choose Focus for \(session.date.fullTennisDate)", systemImage: "scope")
                        }
                        .accessibilityIdentifier("dashboardChooseFocus")
                        .accessibilityLabel("Choose training focus for \(session.date.fullTennisDate), \(session.trainingType.rawValue), \(session.placeText)")
                        .accessibilityHint("Opens the focus choices directly. Choose one or more, then Save.")
                    }
                }

                TennisSection("What to work on") {
                    if progress.suggestions.isEmpty {
                        Text("No personal goals or match-review priorities recorded.")
                            .accessibilityHint("Use Edit Goals and Priorities to add a personal goal or coaching priority. Use Review a Match to record what to practise next.")
                    }
                    ForEach(progress.suggestions) { suggestion in
                        SummaryRow(title: suggestion.source, value: suggestion.detail,
                            hint: suggestion.source.hasPrefix("Your match review") ? "Use Review a Match to update this priority." : "Use Edit Goals and Priorities to change this.")
                            .accessibilityAction(named: suggestion.source.hasPrefix("Your match review") ? "Review a Match" : "Edit Goals and Priorities") {
                                if suggestion.source.hasPrefix("Your match review") { showingMatchReviews = true } else { showingGoals = true }
                            }
                    }
                    Button("Edit Goals and Priorities") { showingGoals = true }
                        .accessibilityIdentifier("dashboardEditGoals")
                        .accessibilityHint("Opens your personal tennis goal and coaching priority. Save to update this dashboard.")
                    Button("Review a Match") { showingMatchReviews = true }
                        .accessibilityIdentifier("dashboardReviewMatch")
                        .accessibilityHint("Choose a completed match and record your next practice focus.")
                    Button("Plan Next Training Session") { showingNewTraining = true }
                }

                if store.data.settings.showUpcomingTournaments {
                    TennisSection("Upcoming tournaments") {
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

                if store.data.settings.showNeedsAttention {
                    Section {
                        SummaryRow(title: "Needs attention", value: stats.needsAttention.isEmpty ? "Nothing needs attention." : stats.needsAttention.joined(separator: " "),
                            hint: "Checks for activities marked as needing details and tournament matches still waiting to be entered. Matches without a tournament are allowed.")
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
            .sheet(item: $focusToEdit) { TrainingFocusEditor(session: $0) }
            .sheet(isPresented: $showingGoals) {
                if let player = store.selectedPlayer { PlayerGoalsEditor(player: player) }
            }
            .sheet(isPresented: $showingMatchReviews) {
                NavigationStack {
                    TennisList {
                        ForEach(store.selectedMatches.filter { $0.status == .completed }) { match in
                            NavigationLink(TennisSummaryFormatter.match(match, style: .short)) { MatchReviewEditor(match: match) }
                        }
                        if !store.selectedMatches.contains(where: { $0.status == .completed }) {
                            Text("No completed matches to review.")
                        }
                    }
                    .navigationTitle("Review a Match")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showingMatchReviews = false } } }
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
