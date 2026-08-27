import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: TennisStore

    private var stats: TennisStatistics {
        TennisStatistics.build(matches: store.selectedMatches, training: store.selectedTraining, tournaments: store.selectedTournaments)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SummaryRow(
                        title: store.selectedPlayer.map { "Welcome back, \($0.displayName)" } ?? "Welcome to Tennis Tracker",
                        value: stats.spokenSummary,
                        hint: "A plain language summary of current tennis activity."
                    )
                }

                Section("Key Cards") {
                    SummaryRow(title: "Matches", value: "\(stats.matchCount) recorded. \(stats.winCount) wins and \(stats.lossCount) losses.")
                    SummaryRow(title: "Training", value: "\(stats.trainingCount) sessions. \(stats.trainingMinutesLast30Days) minutes in the last 30 days.")
                    SummaryRow(title: "Tiebreaks", value: "\(stats.tiebreakSetsLast30Days) tiebreak sets in the last 30 days.")
                    SummaryRow(title: "Upcoming tournaments", value: "\(stats.upcomingTournamentCount) saved.")
                }

                if store.data.settings.showNeedsAttention {
                    Section("Needs Attention") {
                        ForEach(stats.needsAttention, id: \.self) { item in
                            Text(item)
                                .accessibilityLabel("Needs attention")
                                .accessibilityValue(item)
                        }
                    }
                }

                Section("Next Focus") {
                    Text(nextFocus)
                        .accessibilityLabel("Next focus")
                        .accessibilityValue(nextFocus)
                }

                if store.data.settings.showRecentActivity {
                    Section("Recent Matches") {
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
                }
            }
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
        return "Add a training session or match to unlock a useful next focus."
    }

    private func matchLine(_ match: MatchRecord) -> String {
        "\(match.date.shortTennisDate): \(match.matchType.rawValue) \(match.result.rawValue) against \(match.opponentSummary.fallback("opponent not recorded"))"
    }
}
