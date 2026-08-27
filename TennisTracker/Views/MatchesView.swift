import SwiftUI
import UIKit

struct MatchesView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var showingNewMatch = false
    @State private var showingLiveScorer = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Start live scoring") {
                        showingLiveScorer = true
                    }
                    .accessibilityHint("Opens a point by point tennis scorer.")
                }

                Section("Match History") {
                    if store.selectedMatches.isEmpty {
                        EmptyStateView(title: "No matches", message: "Add a match result or use live scoring.")
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
            .navigationTitle("Matches")
            .toolbar {
                Button("Add") { showingNewMatch = true }
                    .accessibilityLabel("Add match")
            }
            .sheet(isPresented: $showingNewMatch) {
                if let playerID = store.selectedPlayerID {
                    MatchEditorView(match: MatchRecord(playerID: playerID))
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
                SummaryRow(title: "Score", value: "\(match.yourSetsWon)-\(match.opponentSetsWon) sets. \(match.setScores.fallback("set scores not recorded")).")
                if match.hadTiebreak {
                    SummaryRow(title: "Tiebreak", value: match.tiebreakScore.fallback("tiebreak score not recorded"))
                }
            }
            Section("Performance") {
                SummaryRow(title: "Key stats", value: "\(match.aces) aces, \(match.doubleFaults) double faults, \(match.winners) winners, \(match.unforcedErrors) unforced errors.")
                SummaryRow(title: "Strengths", value: match.matchStrengths.fallback("not recorded"))
                SummaryRow(title: "Needs work", value: match.matchNeedsWork.fallback("not recorded"))
                SummaryRow(title: "Next practice focus", value: match.nextPracticeFocus.fallback("not recorded"))
            }
            Section("Notes") {
                Text(match.matchStory.fallback("No match story recorded."))
                Text(match.notes.fallback("No extra notes recorded."))
            }
            Section {
                Button("Delete match", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle("Match Detail")
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
                    DatePicker("Date", selection: $match.date, displayedComponents: .date)
                    Picker("Match type", selection: $match.matchType) {
                        ForEach(MatchKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
                    }
                    Picker("Result", selection: $match.result) {
                        ForEach(MatchResult.allCases) { result in Text(result.rawValue).tag(result) }
                    }
                    TextField("Opponent 1", text: $match.opponentName)
                    if match.matchType == .doubles {
                        TextField("Partner", text: $match.partnerName)
                        TextField("Opponent 2", text: $match.opponent2Name)
                    }
                    TextField("Match position", text: $match.matchPosition)
                    TextField("Court surface", text: $match.courtSurface)
                    TextField("Match conditions", text: $match.matchConditions)
                }
                Section("Score") {
                    Stepper("Your sets won \(match.yourSetsWon)", value: $match.yourSetsWon, in: 0...5)
                    Stepper("Opponent sets won \(match.opponentSetsWon)", value: $match.opponentSetsWon, in: 0...5)
                    TextField("Set scores", text: $match.setScores)
                    Toggle("Had tiebreak", isOn: $match.hadTiebreak)
                    TextField("Tiebreak score", text: $match.tiebreakScore)
                }
                Section("Performance") {
                    Stepper("Aces \(match.aces)", value: $match.aces, in: 0...99)
                    Stepper("Double faults \(match.doubleFaults)", value: $match.doubleFaults, in: 0...99)
                    Stepper("Winners \(match.winners)", value: $match.winners, in: 0...999)
                    Stepper("Unforced errors \(match.unforcedErrors)", value: $match.unforcedErrors, in: 0...999)
                    TextField("Opponent style", text: $match.opponentStyle, axis: .vertical)
                    TextField("Pressure moment", text: $match.pressureMoment, axis: .vertical)
                    TextField("Match strengths", text: $match.matchStrengths, axis: .vertical)
                    TextField("Needs work", text: $match.matchNeedsWork, axis: .vertical)
                    TextField("Next practice focus", text: $match.nextPracticeFocus, axis: .vertical)
                    TextField("Match story", text: $match.matchStory, axis: .vertical)
                    TextField("Notes", text: $match.notes, axis: .vertical)
                }
            }
            .navigationTitle("Match")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.upsertMatch(match)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LiveMatchView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State private var scorer = TennisScoringEngine()
    @State private var opponentName = ""
    @AccessibilityFocusState private var focusedScore: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(scorer.state.spokenScore)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel("Current score")
                    .accessibilityValue(scorer.state.spokenScore)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityFocused($focusedScore)

                TextField("Opponent name", text: $opponentName)
                    .textFieldStyle(.roundedBorder)

                Button("Player wins point") {
                    score(.player)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Opponent wins point") {
                    score(.opponent)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                HStack {
                    Button("Undo") {
                        announce(scorer.undo())
                    }
                    Button("Reset") {
                        scorer.reset()
                        announce("Score reset. \(scorer.state.spokenScore).")
                    }
                }
                .buttonStyle(.bordered)

                Button("Save completed match") {
                    saveLiveMatch()
                }
                .disabled(!scorer.state.isMatchComplete || store.selectedPlayerID == nil)

                Spacer()
            }
            .padding()
            .navigationTitle("Live Scoring")
            .toolbar {
                Button("Done") { dismiss() }
            }
            .onAppear {
                focusedScore = true
            }
        }
    }

    private func score(_ winner: PointWinner) {
        let message = scorer.awardPoint(to: winner)
        if store.data.settings.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        announce(message)
    }

    private func announce(_ message: String) {
        store.announce(message)
        focusedScore = true
        if store.data.settings.announceScores {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    private func saveLiveMatch() {
        guard let playerID = store.selectedPlayerID else { return }
        let playerWon = scorer.state.playerSets > scorer.state.opponentSets
        var match = MatchRecord(playerID: playerID)
        match.opponentName = opponentName
        match.result = playerWon ? .win : .loss
        match.yourSetsWon = scorer.state.playerSets
        match.opponentSetsWon = scorer.state.opponentSets
        match.setScores = scorer.state.completedSetScores.joined(separator: ", ")
        match.hadTiebreak = match.setScores.contains("7-6") || match.setScores.contains("6-7")
        store.upsertMatch(match)
        dismiss()
    }
}
