import SwiftUI

struct WatchActivityCard: View {
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    let title: String
    let detail: String
    let summary: String
    let symbol: String
    var fitness: [WatchFitnessMetric] = []
    var identifier = "Activity summary"
    var editTitle = "Edit"
    let edit: () -> Void
    var completeTitle: String?
    var complete: () -> Void = {}
    let delete: () -> Void
    @State private var showingDetails = false

    var body: some View {
        visualContent
        .sheet(isPresented: $showingDetails) {
            NavigationStack {
                ScrollView {
                    Text(summary).frame(maxWidth: .infinity, alignment: .leading).padding()
                        .accessibilityIdentifier("watchActivityDetailsSummary")
                }
                    .navigationTitle("Summary")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showingDetails = false } } }
            }
        }
    }

    private var visualContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showingDetails = true } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Label(title, systemImage: symbol).font(.headline).foregroundStyle(TennisSportStyle.ball)
                    Text(detail).font(.title3).monospacedDigit().foregroundStyle(.primary)
                    if !fitness.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                            ForEach(fitness) { metric in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metric.label).font(.caption2).foregroundStyle(.secondary)
                                    Text(metric.value).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(summary)
            .accessibilityIdentifier(identifier)
            .accessibilityActions {
                Button(editTitle, action: edit)
                if let completeTitle { Button(completeTitle, action: complete) }
                Button("Delete", role: .destructive, action: delete)
            }
            if voiceOver || WatchAccessibilityNavigation.testingEnabled {
                actionButtons.accessibilityRepresentation { EmptyView() }
            } else {
                actionButtons
            }
        }.padding(.vertical, 5)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            action(editTitle, symbol: "pencil", perform: edit)
            if let completeTitle { action(completeTitle, symbol: "checkmark", perform: complete) }
            action("Delete", symbol: "trash", perform: delete).foregroundStyle(.red)
        }
    }

    private func action(_ title: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { Image(systemName: symbol).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle()) }
            .buttonStyle(.plain).accessibilityLabel(title)
    }
}

struct WatchFitnessMetric: Identifiable {
    let label: String
    let value: String
    var id: String { label }

    static func make(heart: Double?, energy: Double?, distance: Double?, steps: Double?) -> [Self] {
        func value(_ number: Double?, suffix: String) -> String {
            guard let number, number.isFinite, number >= 0, number < Double(Int.max) else { return "Unavailable" }
            return "\(Int(number.rounded())) \(suffix)"
        }
        return [Self(label: "Heart rate", value: value(heart, suffix: "bpm")),
                Self(label: "Energy", value: value(energy, suffix: "kcal")),
                Self(label: "Distance", value: value(distance, suffix: "m")),
                Self(label: "Steps", value: value(steps, suffix: "steps"))]
    }
}

struct WatchTrainingRow: View {
    @EnvironmentObject private var store: WatchTennisStore
    let training: TrainingSession
    var identifier = "Training summary"
    @State private var editingTraining: TrainingSession?
    @State private var deleting = false
    @State private var finishing = false

    var body: some View {
        Group {
            if training.isActive {
                WatchLiveTrainingCard(training: training, client: store.healthClient,
                    edit: { editingTraining = training }, finish: { finishing = true }, delete: { deleting = true })
            } else {
                WatchActivityCard(title: training.trainingType.rawValue,
                    detail: TennisDurationFormatter.compact(seconds: TennisDurationFormatter.trainingSeconds(training)),
                    summary: store.trainingSummary(training, style: .detailed), symbol: "figure.tennis",
                    fitness: training.workout.map { WatchFitnessMetric.make(heart: $0.averageHeartRate, energy: $0.activeEnergyKcal, distance: $0.distanceMeters, steps: $0.stepCount) } ?? [], identifier: identifier,
                    editTitle: "Edit Training and Focus", edit: { editingTraining = training }, completeTitle: training.needsDetails ? "Review and Complete Training" : nil,
                    complete: {
                        var draft = training
                        draft.markDetailsComplete()
                        editingTraining = draft
                    }, delete: { deleting = true })
            }
        }
        .sheet(item: $editingTraining) { draft in NavigationStack { WatchTrainingEditor(draft: draft) } }
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
                detail: TennisDurationFormatter.compact(seconds: time.date.timeIntervalSince(training.actualStart ?? training.date)),
                summary: store.trainingSummary(training, style: .short, now: time.date) + " " +
                    TennisWorkoutResult.fitnessSummary(heartRate: client.latestHeartRate, energy: client.activeEnergy,
                        distance: client.distanceMeters, steps: client.stepCount) + " " + client.statusMessage,
                symbol: "figure.tennis", fitness: WatchFitnessMetric.make(heart: client.latestHeartRate, energy: client.activeEnergy,
                    distance: client.distanceMeters, steps: client.stepCount), identifier: "Active training summary", editTitle: "Edit Training and Focus", edit: edit,
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
    @Binding var isPresented: Bool
    let deletion: TennisRecordDeletion

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            WatchDeleteSheet(isPresented: $isPresented, deletion: deletion)
        }
    }
}

struct WatchDeleteSheet: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Binding var isPresented: Bool
    let deletion: TennisRecordDeletion

    var body: some View {
            NavigationStack {
                List {
                    Text(deletion.kind == .training
                        ? "Removes this session from Watch and iPhone, and stops it if running. Workouts already saved in Apple Health are kept."
                        : "This deletion will also sync to your iPhone.")
                    Button(deletion.kind == .tournament ? "Delete Tournament, Keep Matches" : "Delete", role: .destructive) {
                        isPresented = false
                        store.deleteActivity(deletion)
                    }.disabled(store.isPreparingWorkout || store.isFinishingWorkout)
                        .accessibilityIdentifier("Confirm activity deletion")
                    if deletion.kind == .tournament {
                        Button("Delete Tournament and Linked Matches", role: .destructive) {
                            var withMatches = deletion; withMatches.includeLinkedMatches = true
                            isPresented = false
                            store.deleteActivity(withMatches)
                        }.disabled(store.isPreparingWorkout || store.isFinishingWorkout)
                    }
                }.navigationTitle("Delete \(deletion.kind == .training ? "Session" : deletion.kind.rawValue.capitalized)")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
            }
    }
}
