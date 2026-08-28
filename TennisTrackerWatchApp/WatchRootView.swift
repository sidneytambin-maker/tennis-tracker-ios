import SwiftUI

struct WatchRootView: View {
    @StateObject private var store = WatchTennisStore()

    var body: some View {
        TabView {
            WatchTodayView()
                .environmentObject(store)
            WatchTrackView()
                .environmentObject(store)
            WatchLiveView()
                .environmentObject(store)
            WatchRecentView()
                .environmentObject(store)
        }
        .tabViewStyle(.page)
        .onAppear {
            store.activate()
        }
    }
}

private struct WatchTodayView: View {
    @EnvironmentObject private var store: WatchTennisStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(activeText)
                    .font(.headline)
                    .foregroundStyle(.green)
                if let tournament = store.upcomingTournament {
                    WatchSummaryLine(title: "Next", value: "\(tournament.name.fallback("Tournament")), \(tournament.date.shortTennisDate)")
                }
                WatchSummaryLine(title: "Needs Details", value: "\(store.needsDetailsCount)")
                Text(store.lastAnnouncement)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var activeText: String {
        if store.activeMatch != nil { return "Match in progress" }
        if store.activeTraining != nil { return "Training in progress" }
        return "Ready to track"
    }
}

private struct WatchTrackView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @State private var choosingMatchKind = false
    @State private var choosingTournamentMatch = false

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                Text("Track Tennis Activity")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Button("Track Training Session") {
                    store.trackTrainingSession()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Record Match") {
                    choosingMatchKind = true
                }
                .buttonStyle(.bordered)

                Button("Track Tournament") {
                    if store.upcomingTournament == nil {
                        store.trackTournament()
                    } else {
                        choosingTournamentMatch = true
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .sheet(isPresented: $choosingMatchKind) {
            WatchMatchKindSheet(tournament: nil)
                .environmentObject(store)
        }
        .sheet(isPresented: $choosingTournamentMatch) {
            WatchTournamentSheet()
                .environmentObject(store)
        }
    }
}

private struct WatchMatchKindSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WatchTennisStore
    let tournament: TournamentRecord?

    var body: some View {
        List {
            Button("Singles") {
                store.recordMatch(kind: .singles, tournament: tournament)
                dismiss()
            }
            Button("Doubles") {
                store.recordMatch(kind: .doubles, tournament: tournament)
                dismiss()
            }
            Button("Set Up on iPhone") {
                store.send(.requestSnapshot)
                dismiss()
            }
        }
        .navigationTitle("Record Match")
    }
}

private struct WatchTournamentSheet: View {
    @EnvironmentObject private var store: WatchTennisStore

    var body: some View {
        List {
            if let tournament = store.upcomingTournament {
                Section(tournament.name.fallback("Tournament")) {
                    NavigationLink("Record Match") {
                        WatchMatchKindSheet(tournament: tournament)
                            .environmentObject(store)
                    }
                }
            }
            Button("Create Tournament") {
                store.trackTournament()
            }
        }
        .navigationTitle("Track Tournament")
    }
}

private struct WatchLiveView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @FocusState private var scoringFocus: PointWinner?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Live")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)

                if let training = store.activeTraining {
                    WatchSummaryLine(title: "Training", value: elapsedText(since: training.date))
                    Button("Finish Training Session") {
                        store.finishTrainingSession()
                    }
                    .buttonStyle(.borderedProminent)
                } else if let match = store.activeMatch {
                    Text(scoreText)
                        .font(.system(.title3, design: .rounded).bold())
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Score")
                        .accessibilityValue(scoreText)
                        .accessibilityAddTraits(.updatesFrequently)

                    Button("Record Point for \(teamName(.player, match: match))") {
                        store.recordPoint(.player)
                        scoringFocus = .player
                    }
                    .buttonStyle(.borderedProminent)
                    .focused($scoringFocus, equals: .player)
                    .accessibilityHint("Records the point and keeps focus on this scoring button.")

                    Button("Record Point for \(teamName(.opponent, match: match))") {
                        store.recordPoint(.opponent)
                        scoringFocus = .opponent
                    }
                    .buttonStyle(.borderedProminent)
                    .focused($scoringFocus, equals: .opponent)
                    .accessibilityHint("Records the point and keeps focus on this scoring button.")

                    Button("Hear Full Score") {
                        store.lastAnnouncement = scoreText
                    }
                    .buttonStyle(.bordered)

                    Menu("Match Actions") {
                        Button("Undo Last Point") { store.undoLastPoint() }
                        Button("Save Match Progress") { store.saveMatchProgress() }
                        Button("Start Tie-break") { store.startTieBreak() }
                        Button("Finish Match") { store.finishMatch() }
                    }
                } else {
                    Text("No tennis activity in progress.")
                        .foregroundStyle(.secondary)
                    Button("Track Tennis Activity") {
                        store.send(.requestSnapshot)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }

    private var scoreText: String {
        guard let match = store.activeMatch else { return "No match in progress." }
        return store.scoreState.spokenScore(
            playerName: teamName(.player, match: match),
            opponentName: teamName(.opponent, match: match),
            suddenDeathDeuce: match.suddenDeathDeuce
        )
    }

    private func teamName(_ winner: PointWinner, match: MatchRecord) -> String {
        if match.matchType == .doubles {
            if winner == .player {
                return [match.playerName, match.partnerName].filter { !$0.isBlank }.joined(separator: " and ").fallback("Your team")
            }
            return [match.opponentName, match.opponent2Name].filter { !$0.isBlank }.joined(separator: " and ").fallback("Opponent team")
        }
        return winner == .player ? match.playerName.fallback("Player") : match.opponentName.fallback("Opponent")
    }

    private func elapsedText(since date: Date) -> String {
        max(1, Int(Date().timeIntervalSince(date) / 60)).durationText
    }
}

private struct WatchRecentView: View {
    @EnvironmentObject private var store: WatchTennisStore

    var body: some View {
        List {
            Section("Recent") {
                if store.recentSummary.isEmpty {
                    Text("No recent tennis activity.")
                } else {
                    ForEach(store.recentSummary, id: \.self) { item in
                        Text(item)
                    }
                }
            }
            if store.needsDetailsCount > 0 {
                Section("Needs Details") {
                    Text("\(store.needsDetailsCount) activities need details.")
                    Button("Mark Complete") {
                        store.markDetailsComplete()
                    }
                }
            }
            Section("Resume") {
                ForEach(store.snapshot.matches.filter { $0.status == .inProgress && $0.liveScore != nil }.prefix(5)) { match in
                    Button("Resume Match Scoring, \(match.opponentSummary.fallback("opponent"))") {
                        store.resume(match)
                    }
                }
            }
        }
        .navigationTitle("Recent")
    }
}

private struct WatchSummaryLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
