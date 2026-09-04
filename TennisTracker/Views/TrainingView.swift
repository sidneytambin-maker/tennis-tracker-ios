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
                                    Text(TennisSummaryFormatter.training(session))
                                }
                            }
                            .accessibilityLabel("Training session")
                            .accessibilityValue(TennisSummaryFormatter.training(session, style: .accessibility))
                            .accessibilityAction(named: session.needsDetails ? "Complete Training Details" : "Edit Training Session") {
                                sessionToEdit = session
                            }
                            .accessibilityAction(named: "Add to Calendar") {
                                addToCalendar(session)
                            }
                            .accessibilityAction(named: "Delete session") {
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
            let success = await TennisCalendarService.shared.save(TennisCalendarMapper.event(for: session))
            store.announce(success ? "Added training to Apple Calendar." : "Calendar access was not granted or the event could not be saved.")
        }
    }
}

struct TrainingDetailView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State var session: TrainingSession
    @State private var showingEditor = false
    @State private var confirmDelete = false
    @State private var calendarMessage = ""

    var body: some View {
        List {
            Section("Summary") {
                Text(TennisSummaryFormatter.training(session, style: .detailed))
                SummaryRow(title: "Focus", value: session.focus.fallback("not recorded"))
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
            }
        }
        .tennisThemedList()
        .navigationTitle("Training detail")
        .onChange(of: store.data.trainingSessions) { _, sessions in
            if let updated = sessions.first(where: { $0.id == session.id }) { session = updated }
            else { dismiss() }
        }
        .toolbar {
            Button("Edit") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            TrainingEditorView(session: session)
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
            let success = await TennisCalendarService.shared.save(TennisCalendarMapper.event(for: session))
            calendarMessage = success ? "Added to Apple Calendar." : "Calendar access was not granted or the event could not be saved."
            store.announce(calendarMessage)
        }
    }
}

struct TrainingEditorView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State var session: TrainingSession
    @State private var validationMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                if !validationMessage.isBlank {
                    Section("Needs attention") {
                        Text(validationMessage)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                Section("Training") {
                    Picker("Session type", selection: $session.trainingType) {
                        ForEach(TrainingType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("trainingTypePicker")
                    AccessibleDateTimeEditor(dateTitle: "Date", timeTitle: "Start time", date: $session.date, hasStartTime: $session.hasStartTime)
                        .accessibilityIdentifier("trainingDatePicker")
                    StoredVenuePicker(id: $session.context.venueID, venue: $session.venue, location: $session.location, training: true)
                    Picker("Coach", selection: $session.context.coachID) {
                        Text("Other or no coach").tag(Optional<UUID>.none)
                        ForEach(store.data.setup.coaches) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .onChange(of: session.context.coachID) { _, id in
                        session.context.coachName = store.data.setup.coaches.first(where: { $0.id == id })?.name ?? ""
                    }
                    if session.context.coachID == nil { TextField("Coach name", text: $session.context.coachName) }
                    NavigationLink("Players Present") {
                        List {
                            ForEach(store.data.players.filter { $0.id != session.playerID }) { player in
                                Toggle(player.displayName, isOn: Binding(
                                    get: { session.context.participantIDs.contains(player.id) },
                                    set: { selected in
                                        session.context.participantIDs.removeAll { $0 == player.id }
                                        if selected { session.context.participantIDs.append(player.id) }
                                        session.context.participantNames = store.data.players.filter { session.context.participantIDs.contains($0.id) }.map(\.displayName)
                                    }
                                ))
                            }
                        }.navigationTitle("Players Present")
                    }
                    Picker("Tournament", selection: $session.context.tournamentID) {
                        Text("No tournament").tag(Optional<UUID>.none)
                        ForEach(store.selectedTournaments) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("Surface", selection: $session.surface) {
                        ForEach(CourtSurface.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("trainingSurfacePicker")
                    TextField("Focus", text: $session.focus)
                }

                DurationPicker(title: "Duration", minutes: $session.durationMinutes)

                Section("Detail") {
                    Toggle("Include body ratings", isOn: $session.hasSessionDetails)
                    if session.hasSessionDetails {
                        Picker("Effort", selection: $session.effortLevel) {
                            ForEach(RatingLevel.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Confidence", selection: $session.confidenceLevel) {
                            ForEach(RatingLevel.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Energy", selection: $session.energyLevel) {
                            ForEach(RatingLevel.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Pain", selection: $session.painLevel) {
                            ForEach(PainLevel.allCases) { Text($0.rawValue).tag($0) }
                        }
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
        }
    }

    private func save() {
        guard session.durationMinutes > 0 else {
            validationMessage = "Enter a training duration."
            UIAccessibility.post(notification: .announcement, argument: validationMessage)
            return
        }
        session.needsDetails = false
        store.upsertTraining(session)
        dismiss()
    }
}
