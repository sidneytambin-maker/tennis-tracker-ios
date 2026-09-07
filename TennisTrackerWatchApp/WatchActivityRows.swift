import SwiftUI

struct WatchTrainingRow: View {
    @EnvironmentObject private var store: WatchTennisStore
    let training: TrainingSession
    @State private var editing = false

    var body: some View {
        Button { editing = true } label: {
            Text(store.trainingSummary(training, style: .short) + " " + (training.workout?.fitnessSummary ?? ""))
        }
        .accessibilityHint("Edits this training session.")
        .accessibilityActions {
            if training.needsDetails && !training.isActive {
                Button("Mark Complete") { store.markTrainingComplete(training.id) }
            }
        }
        .contextMenu {
            Button("Edit Training") { editing = true }
            if training.needsDetails && !training.isActive { Button("Mark Complete") { store.markTrainingComplete(training.id) } }
        }
        .sheet(isPresented: $editing) { NavigationStack { WatchTrainingEditor(draft: training) } }
    }
}

struct WatchMatchRow: View {
    @EnvironmentObject private var store: WatchTennisStore
    let match: MatchRecord
    @State private var editing = false

    var body: some View {
        Button { editing = true } label: { Text(TennisSummaryFormatter.match(match, tournaments: store.snapshot.tournaments, style: .short)) }
        .accessibilityHint("Edits this match's details.")
        .accessibilityActions {
            if match.needsDetails && match.status == .completed { Button("Mark Complete") { store.markMatchComplete(match.id) } }
        }
        .contextMenu {
            Button("Edit Match") { editing = true }
            if match.needsDetails && match.status == .completed { Button("Mark Complete") { store.markMatchComplete(match.id) } }
        }
        .sheet(isPresented: $editing) { NavigationStack { WatchMatchEditor(draft: match) } }
    }
}

struct WatchTournamentRow: View {
    @EnvironmentObject private var store: WatchTennisStore
    let tournament: TournamentRecord
    @State private var editing = false

    var body: some View {
        Button { editing = true } label: { Text(TennisSummaryFormatter.tournament(tournament, style: .short)) }
        .accessibilityHint("Edits this tournament.")
        .accessibilityActions {
            if tournament.needsDetails && tournament.isCompleted { Button("Mark Complete") { store.markTournamentComplete(tournament.id) } }
        }
        .contextMenu {
            Button("Edit Tournament") { editing = true }
            if tournament.needsDetails && tournament.isCompleted { Button("Mark Complete") { store.markTournamentComplete(tournament.id) } }
        }
        .sheet(isPresented: $editing) { NavigationStack { WatchTournamentEditor(draft: tournament) } }
    }
}
