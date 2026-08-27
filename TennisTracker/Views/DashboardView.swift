import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: TennisStore

    private var stats: TennisStatistics {
        TennisStatistics.build(matches: store.selectedMatches, training: store.selectedTraining, tournaments: store.selectedTournaments)
    }

    private var nextTournament: TournamentRecord? {
        store.selectedTournaments
            .filter { !$0.isCompleted }
            .sorted { $0.date < $1.date }
            .first
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
                            NavigationLink(matchLine(match)) {
                                MatchDetailView(match: match)
                            }
                        }
                    }
                }

                Section("Training activity") {
                    SummaryRow(title: "Training activity", value: stats.trainingCount == 0 ? "No sessions recorded this month." : "\(stats.trainingCount) sessions saved. \(stats.trainingMinutesLast30Days) minutes in the last 30 days.")
                }

                if store.data.settings.showUpcomingTournaments {
                    Section("Upcoming tournaments") {
                        if let nextTournament {
                            SummaryRow(title: "Next tournament", value: "\(nextTournament.name.fallback("Unnamed tournament")), \(nextTournament.date.shortTennisDate), \(nextTournament.location.fallback("location not recorded")).")
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

                Section("Next focus") {
                    Text(nextFocus)
                }
            }
            .tennisThemedList()
            .navigationTitle("Dashboard")
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
        "\(match.date.shortTennisDate): \(match.matchType.rawValue) \(match.result.rawValue) against \(match.opponentSummary.fallback("opponent not recorded"))"
    }
}
