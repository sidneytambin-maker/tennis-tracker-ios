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
                    SummaryRow(
                        title: "Welcome, \(store.selectedPlayer?.displayName ?? "player")",
                        value: stats.spokenSummary,
                        hint: "Dashboard summary from your saved matches, training, and tournaments."
                    )
                }

                Section("Current record") {
                    SummaryRow(title: "Match record", value: stats.matchCount == 0 ? "No matches recorded yet." : "\(stats.winCount) wins, \(stats.lossCount) losses, \(Int((stats.winRate * 100).rounded())) percent win rate.")
                }

                Section("Recent matches") {
                    if store.selectedMatches.isEmpty {
                        Text("No recent matches recorded.")
                    } else {
                        ForEach(store.selectedMatches.prefix(3)) { match in
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
                    SummaryRow(title: "Training activity", value: stats.trainingCount == 0 ? "No sessions recorded this month." : "\(stats.trainingCount) sessions saved. \(stats.trainingMinutesLast30Days) minutes in the last 30 days.")
                        .accessibilityAction(named: "Track Training Session") {
                            showingNewTraining = true
                        }
                        .accessibilityAction(named: "Complete Training Details") {
                            trainingToEdit = store.selectedTraining.first
                        }
                }

                if store.data.settings.showUpcomingTournaments {
                    Section("Upcoming tournaments") {
                        if let nextTournament {
                            SummaryRow(title: "Next tournament", value: "\(nextTournament.name.fallback("Unnamed tournament")), \(nextTournament.date.shortTennisDate), \(nextTournament.location.fallback("location not recorded")).")
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
                                trainingToEdit = training
                            }
                            Button("Mark Complete") {
                                store.completeTrainingDetails(training.id)
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

                Section("Next focus") {
                    Text(nextFocus)
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

    private var nextFocus: String {
        if let match = store.selectedMatches.first, !match.nextPracticeFocus.isBlank {
            return match.nextPracticeFocus
        }
        if let training = store.selectedTraining.first, !training.focus.isBlank {
            return "Build from recent training focus: \(training.focus)."
        }
        return "Add a match, training session, or tournament when you are ready."
    }

    private func matchLine(_ match: MatchRecord) -> String {
        TennisSummaryFormatter.match(match, tournaments: store.selectedTournaments, style: .long)
    }

    private func addMatchToCalendar(_ match: MatchRecord) {
        Task {
            let success = await TennisCalendarService.shared.save(TennisCalendarMapper.event(for: match))
            store.announce(success ? "Added match to Apple Calendar." : "Calendar access was not granted or the event could not be saved.")
        }
    }

    private func addTournamentToCalendar(_ tournament: TournamentRecord) {
        Task {
            let success = await TennisCalendarService.shared.save(TennisCalendarMapper.event(for: tournament))
            store.announce(success ? "Added tournament to Apple Calendar." : "Calendar access was not granted or the event could not be saved.")
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
