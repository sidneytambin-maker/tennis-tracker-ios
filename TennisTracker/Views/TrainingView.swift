import SwiftUI
import UIKit

struct TrainingView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var showingNewTraining = false
    @State private var sessionToEdit: TrainingSession?
    @State private var sessionToDelete: TrainingSession?
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section("Track") {
                    Button("Track Training Session") { showingNewTraining = true }
                        .accessibilityLabel("Track Training Session")
                        .accessibilityIdentifier("addTrainingButton")
                }
                Section("Training history") {
                    if store.selectedTraining.isEmpty {
                        EmptyStateView(title: "No training sessions recorded yet", message: "Use Track Training Session to save your first session.")
                    } else {
                        ForEach(store.selectedTraining) { session in
                            NavigationLink {
                                TrainingDetailView(session: session)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.trainingSummary(session))
                                }
                            }
                            .accessibilityLabel("Training session")
                            .accessibilityValue(store.trainingSummary(session, style: .accessibility))
                            .accessibilityAction(named: "Edit Training and Focus") {
                                sessionToEdit = session
                            }
                            .accessibilityActions {
                                if session.needsDetails && !session.isActive {
                                    Button("Review and Complete Training") {
                                        var draft = session
                                        draft.markDetailsComplete()
                                        sessionToEdit = draft
                                    }
                                }
                            }
                            .accessibilityAction(named: "Add to Calendar") {
                                addToCalendar(session)
                            }
                            .accessibilityAction(named: "Delete") {
                                sessionToDelete = session
                                confirmDelete = true
                            }
                        }
                    }
                }
            }
            .tennisThemedList()
            .navigationTitle("Training")
            .sheet(isPresented: $showingNewTraining) {
                if let session = store.makeDefaultTraining() {
                    TrainingEditorView(session: session)
                }
            }
            .sheet(item: $sessionToEdit) { session in
                TrainingEditorView(session: session)
            }
            .confirmationDialog("Delete this training session?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Training Session", role: .destructive) {
                    if let sessionToDelete {
                        store.deleteTraining(sessionToDelete)
                    }
                    sessionToDelete = nil
                }
                Button("Cancel", role: .cancel) { sessionToDelete = nil }
            }
        }
    }

    private func addToCalendar(_ session: TrainingSession) {
        Task {
            await store.addToCalendar(TennisCalendarMapper.event(for: session, coaches: store.data.setup.coaches, players: store.data.players))
        }
    }
}

struct TrainingDetailView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State var session: TrainingSession
    @State private var showingEditor = false
    @State private var reviewingCompletion = false
    @State private var confirmDelete = false
    @State private var calendarMessage = ""

    var body: some View {
        List {
            Section("Summary") {
                Text(store.trainingSummary(session, style: .detailed))
                    .accessibilityAction(named: "Edit Training and Focus") { reviewingCompletion = false; showingEditor = true }
                    .accessibilityAction(named: "Delete") { confirmDelete = true }
                    .accessibilityActions {
                        if session.needsDetails && !session.isActive {
                            Button("Review and Complete Training") { reviewingCompletion = true; showingEditor = true }
                        }
                    }
                SummaryRow(title: "Outcome", value: session.sessionOutcome.fallback("not recorded"))
            }

            if session.hasSessionDetails {
                Section("Body") {
                    SummaryRow(title: "Effort", value: session.effortLevel.rawValue)
                    SummaryRow(title: "Confidence", value: session.confidenceLevel.rawValue)
                    SummaryRow(title: "Energy", value: session.energyLevel.rawValue)
                    SummaryRow(title: "Pain", value: session.painLevel.rawValue)
                }
            }

            Section("Notes") {
                Text(session.notes.fallback("No notes recorded."))
            }

            Section("Calendar") {
                Button("Add to Apple Calendar") {
                    addToCalendar()
                }
                if !calendarMessage.isBlank {
                    Text(calendarMessage)
                }
            }

            Section {
                Button("Delete training session", role: .destructive) { confirmDelete = true }
                    .accessibilityHidden(voiceOver)
            }
        }
        .tennisThemedList()
        .navigationTitle("Training detail")
        .onChange(of: store.data.trainingSessions) { _, sessions in
            if let updated = sessions.first(where: { $0.id == session.id }) { session = updated }
            else { dismiss() }
        }
        .toolbar {
            Button("Edit") { reviewingCompletion = false; showingEditor = true }
                .accessibilityHidden(voiceOver)
        }
        .sheet(isPresented: $showingEditor) {
            TrainingEditorView(session: editorDraft)
        }
        .confirmationDialog("Delete this training session?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Training Session", role: .destructive) {
                store.deleteTraining(session)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func addToCalendar() {
        Task {
            calendarMessage = await store.addToCalendar(TennisCalendarMapper.event(for: session, coaches: store.data.setup.coaches, players: store.data.players))
        }
    }

    private var editorDraft: TrainingSession {
        var draft = session
        if reviewingCompletion { draft.markDetailsComplete() }
        return draft
    }
}

struct TrainingEditorView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State var session: TrainingSession
    @State private var validationMessage = ""
    @State private var participantName = ""
    @State private var coachName = ""
    @State private var newPlayers: [PlayerProfile] = []
    @State private var newCoaches: [TennisCoach] = []
    @FocusState private var personNameFocused: Bool

    private var coaches: [TennisCoach] { store.data.setup.coaches + newCoaches }
    private var players: [PlayerProfile] { store.data.players + newPlayers }

    var body: some View {
        NavigationStack {
            Form {
                if !validationMessage.isBlank {
                    Section("Needs attention") {
                        Text(validationMessage)
                    }
                }
                Section("Session") {
                    Picker("Training type", selection: $session.trainingType) {
                        ForEach(TrainingType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("trainingTypePicker")
                    TennisTrainingFocusPicker(focus: $session.focus)
                    AccessibleDateTimeEditor(dateTitle: "Date", timeTitle: "Start time", date: $session.date, hasStartTime: $session.hasStartTime)
                        .accessibilityIdentifier("trainingDatePicker")
                    StoredVenuePicker(id: $session.context.venueID, venue: $session.venue, location: $session.location, training: true)
                    NavigationLink("Coaches") {
                        List {
                            ForEach(coaches) { coach in
                                TennisSelectionRow(name: coach.name, id: coach.id, selectedIDs: $session.context.coachIDs)
                            }
                            TextField("New coach name", text: $coachName)
                                .focused($personNameFocused)
                            Button("Add Coach") {
                                let name = coachName.trimmingCharacters(in: .whitespacesAndNewlines)
                                var coach = coaches.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame } ?? TennisCoach()
                                coach.name = name
                                if !coaches.contains(where: { $0.id == coach.id }) { newCoaches.append(coach) }
                                if !session.context.coachIDs.contains(coach.id) { session.context.coachIDs.append(coach.id) }
                                coachName = ""
                                personNameFocused = false
                            }.disabled(coachName.isBlank)
                            Toggle("Coaches need details", isOn: Binding(
                                get: { session.context.coachesNeedDetails == true },
                                set: { session.context.coachesNeedDetails = $0 }
                            ))
                        }.navigationTitle("Coaches")
                    }
                    .accessibilityValue(session.context.coachSummary(in: coaches).fallback("None"))
                    NavigationLink("Players Present") {
                        List {
                            ForEach(players.filter { $0.id != session.playerID }) { player in
                                TennisSelectionRow(name: player.displayName, id: player.id, selectedIDs: $session.context.participantIDs)
                            }
                            TextField("Other player name", text: $participantName)
                                .focused($personNameFocused)
                            Button("Add Player") {
                                let name = participantName.trimmingCharacters(in: .whitespacesAndNewlines)
                                var player = players.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame } ?? PlayerProfile()
                                player.name = name
                                player.sightLevel = .notKnown
                                player.bCategory = "Not known"
                                if !players.contains(where: { $0.id == player.id }) { newPlayers.append(player) }
                                if player.id != session.playerID && !session.context.participantIDs.contains(player.id) { session.context.participantIDs.append(player.id) }
                                participantName = ""
                                personNameFocused = false
                            }.disabled(participantName.isBlank)
                            Toggle("All participants recorded", isOn: Binding(
                                get: { session.context.participantsNeedDetails != true },
                                set: { session.context.participantsNeedDetails = !$0 }
                            ))
                        }.navigationTitle("Players Present")
                    }
                    .accessibilityValue(session.context.participantSummary(in: players).fallback("None"))
                    Picker("Tournament", selection: $session.context.tournamentID) {
                        Text("No tournament").tag(Optional<UUID>.none)
                        ForEach(store.selectedTournaments) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("Surface", selection: $session.surface) {
                        ForEach(CourtSurface.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("trainingSurfacePicker")
                }

                DurationPicker(title: "Duration", minutes: $session.durationMinutes)

                Section("Detail") {
                    Toggle("Include body ratings", isOn: $session.hasSessionDetails)
                    if session.hasSessionDetails {
                        OrderedChoicePicker(title: "Effort", selection: $session.effortLevel, values: RatingLevel.allCases) { $0.rawValue }
                        OrderedChoicePicker(title: "Confidence", selection: $session.confidenceLevel, values: RatingLevel.allCases) { $0.rawValue }
                        OrderedChoicePicker(title: "Energy", selection: $session.energyLevel, values: RatingLevel.allCases) { $0.rawValue }
                        OrderedChoicePicker(title: "Pain", selection: $session.painLevel, values: PainLevel.allCases) { $0.rawValue }
                        TextField("Outcome", text: $session.sessionOutcome, axis: .vertical)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $session.notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("trainingNotesField")
                }
            }
            .tennisThemedList()
            .navigationTitle("Training")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .accessibilityIdentifier("saveTrainingButton")
                }
            }
            .onChange(of: session.context.coachIDs) { _, _ in session.context.coachName = "" }
            .onChange(of: session.context.participantIDs) { _, ids in
                if ids.isEmpty { session.context.participantNames = [] }
            }
        }
    }

    private func save() {
        guard session.durationMinutes > 0 else {
            validationMessage = "Enter a training duration."
            UIAccessibility.post(notification: .announcement, argument: validationMessage)
            return
        }
        session.needsDetails = session.context.participantsNeedDetails == true || session.context.coachesNeedDetails == true
        store.upsertTraining(session, newPlayers: newPlayers, newCoaches: newCoaches)
        dismiss()
    }
}
