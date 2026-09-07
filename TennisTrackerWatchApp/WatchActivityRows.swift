import SwiftUI

struct WatchActivityCard: View {
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    let title: String
    let detail: String
    let summary: String
    let symbol: String
    var identifier = "Activity summary"
    let edit: () -> Void
    var completeTitle: String?
    var complete: () -> Void = {}
    let delete: () -> Void
    @State private var showingDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showingDetails = true } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Label(title, systemImage: symbol).font(.headline).foregroundStyle(TennisSportStyle.ball)
                    Text(detail).font(.body).foregroundStyle(.primary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)
            .accessibilityIdentifier(identifier)
            .accessibilityActions {
                Button("Edit") { edit() }
                if let completeTitle { Button(completeTitle) { complete() } }
                Button("Delete", role: .destructive) { delete() }
            }
            HStack(spacing: 8) {
                action("Edit", symbol: "pencil", perform: edit)
                if let completeTitle { action(completeTitle, symbol: "checkmark", perform: complete) }
                action("Delete", symbol: "trash", perform: delete).foregroundStyle(.red)
            }
            // The same commands live on the summary's Actions rotor for VoiceOver.
            .accessibilityHidden(voiceOver || WatchAccessibilityNavigation.testingEnabled)
        }.padding(.vertical, 5)
        .sheet(isPresented: $showingDetails) {
            NavigationStack {
                ScrollView { Text(summary).frame(maxWidth: .infinity, alignment: .leading).padding() }
                    .navigationTitle("Summary")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showingDetails = false } } }
            }
        }
    }

    private func action(_ title: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { Image(systemName: symbol).frame(maxWidth: .infinity, minHeight: 44) }
            .buttonStyle(.plain).accessibilityLabel(title)
    }
}

struct WatchTrainingRow: View {
    @EnvironmentObject private var store: WatchTennisStore
    let training: TrainingSession
    var identifier = "Training summary"
    @State private var editing = false
    @State private var deleting = false
    @State private var finishing = false

    var body: some View {
        Group {
            if training.isActive {
                WatchLiveTrainingCard(training: training, client: store.healthClient,
                    edit: { editing = true }, finish: { finishing = true }, delete: { deleting = true })
            } else {
                WatchActivityCard(title: training.trainingType.rawValue, detail: TennisDurationFormatter.training(training) + "\n" + (training.workout?.fitnessSummary ?? ""),
                    summary: store.trainingSummary(training, style: .detailed), symbol: "figure.tennis", identifier: identifier,
                    edit: { editing = true }, completeTitle: training.needsDetails ? "Mark Complete" : nil,
                    complete: { store.markTrainingComplete(training.id) }, delete: { deleting = true })
            }
        }
        .sheet(isPresented: $editing) { NavigationStack { WatchTrainingEditor(draft: training) } }
        .modifier(WatchDeleteConfirmation(isPresented: $deleting, deletion: TennisRecordDeletion(id: training.id, kind: .training)))
        .confirmationDialog("Finish training session?", isPresented: $finishing, titleVisibility: .visible) {
            Button("Finish") { store.finishTrainingSession() }.disabled(store.isPreparingWorkout || store.isFinishingWorkout)
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct WatchLiveTrainingCard: View {
    @EnvironmentObject private var store: WatchTennisStore
    let training: TrainingSession
    @ObservedObject var client: WatchHealthWorkout
    let edit: () -> Void
    let finish: () -> Void
    let delete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { time in
            WatchActivityCard(title: training.trainingType.rawValue,
                detail: TennisDurationFormatter.training(training, now: time.date) + "\n" +
                    TennisWorkoutResult.fitnessSummary(heartRate: client.latestHeartRate, energy: client.activeEnergy,
                        distance: client.distanceMeters, steps: client.stepCount),
                summary: store.trainingSummary(training, style: .short, now: time.date) + " " +
                    TennisWorkoutResult.fitnessSummary(heartRate: client.latestHeartRate, energy: client.activeEnergy,
                        distance: client.distanceMeters, steps: client.stepCount) + " " + client.statusMessage,
                symbol: "figure.tennis", identifier: "Active training summary", edit: edit,
                completeTitle: store.isPreparingWorkout ? nil : "Finish", complete: finish, delete: delete)
        }
    }
}

struct WatchMatchRow: View {
    @EnvironmentObject private var store: WatchTennisStore
    let match: MatchRecord
    @State private var editing = false
    @State private var deleting = false

    var body: some View {
        WatchActivityCard(title: match.matchType.rawValue, detail: TennisSummaryFormatter.match(match, style: .short),
            summary: TennisSummaryFormatter.match(match, tournaments: store.snapshot.tournaments, style: .detailed),
            symbol: "tennisball.fill", identifier: "Match summary", edit: { editing = true },
            completeTitle: match.needsDetails && match.status == .completed ? "Mark Complete" : nil,
            complete: { store.markMatchComplete(match.id) }, delete: { deleting = true })
            .sheet(isPresented: $editing) { NavigationStack { WatchMatchEditor(draft: match) } }
            .modifier(WatchDeleteConfirmation(isPresented: $deleting, deletion: TennisRecordDeletion(id: match.id, kind: .match)))
    }
}

struct WatchTournamentRow: View {
    @EnvironmentObject private var store: WatchTennisStore
    let tournament: TournamentRecord
    @State private var editing = false
    @State private var deleting = false
    @State private var finishing = false
    private var active: Bool { store.activeTournamentID == tournament.id }

    var body: some View {
        TimelineView(.periodic(from: .now, by: active ? 1 : 60)) { time in
            card(now: time.date)
        }
    }

    private func card(now: Date) -> some View {
        WatchActivityCard(title: tournament.name, detail: tournament.stageReached.rawValue,
            summary: TennisSummaryFormatter.tournament(tournament, matches: store.snapshot.matches) +
                (active ? " Elapsed " + TennisDurationFormatter.text(seconds: now.timeIntervalSince(tournament.actualStart ?? now)) + "." : ""),
            symbol: "trophy.fill", identifier: "Tournament summary", edit: { editing = true },
            completeTitle: active ? "Finish" : tournament.needsDetails && tournament.isCompleted ? "Mark Complete" : nil,
            complete: { if active { finishing = true } else { store.markTournamentComplete(tournament.id) } },
            delete: { deleting = true })
            .sheet(isPresented: $editing) { NavigationStack { WatchTournamentEditor(draft: tournament) } }
            .modifier(WatchDeleteConfirmation(isPresented: $deleting, deletion: TennisRecordDeletion(id: tournament.id, kind: .tournament)))
            .confirmationDialog("Finish tournament?", isPresented: $finishing, titleVisibility: .visible) {
                Button("Finish") { store.finishTournament() }
                Button("Cancel", role: .cancel) {}
            }
    }
}

struct WatchDeleteConfirmation: ViewModifier {
    @EnvironmentObject private var store: WatchTennisStore
    @Binding var isPresented: Bool
    let deletion: TennisRecordDeletion

    func body(content: Content) -> some View {
        content.confirmationDialog("Delete this \(deletion.kind.rawValue)?", isPresented: $isPresented, titleVisibility: .visible) {
            Button(deletion.kind == .tournament ? "Delete Tournament, Keep Matches" : "Delete", role: .destructive) {
                store.deleteActivity(deletion)
            }.disabled(store.isPreparingWorkout || store.isFinishingWorkout)
                .accessibilityIdentifier("Confirm activity deletion")
            if deletion.kind == .tournament {
                Button("Delete Tournament and Linked Matches", role: .destructive) {
                    var withMatches = deletion; withMatches.includeLinkedMatches = true
                    store.deleteActivity(withMatches)
                }.disabled(store.isPreparingWorkout || store.isFinishingWorkout)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deletion.kind == .training
                ? "This removes the session from Watch and iPhone, and stops it if running. Workouts already saved in Apple Health are kept."
                : "This deletion will also sync to your iPhone.")
        }
    }
}
