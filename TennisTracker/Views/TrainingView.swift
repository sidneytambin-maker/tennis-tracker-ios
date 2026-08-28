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
                ScreenIntro(title: "Training", summary: "\(store.selectedTraining.count) sessions saved. Add sessions with date, start time, duration, focus, and notes.")
                Section("Add") {
                    Button("Add Training Session") { showingNewTraining = true }
                        .accessibilityLabel("Add Training Session")
                        .accessibilityIdentifier("addTrainingButton")
                }
                Section("Training history") {
                    if store.selectedTraining.isEmpty {
                        EmptyStateView(title: "No training sessions recorded yet", message: "Use Add to save your first session.")
                    } else {
                        ForEach(store.selectedTraining) { session in
                            NavigationLink {
                                TrainingDetailView(session: session)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(session.date.shortTennisDate): \(session.trainingType.rawValue)")
                                    Text("\(session.durationMinutes.durationText). Focus: \(session.focus.fallback("not recorded")).")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityLabel("Training session")
                            .accessibilityValue("\(session.date.shortTennisDate), \(session.hasStartTime ? session.date.shortTennisTime : "time not specified"), \(session.trainingType.rawValue), \(session.durationMinutes.durationText), focus \(session.focus.fallback("not recorded"))")
                            .accessibilityAction(named: "Edit session") {
                                sessionToEdit = session
                            }
                            .accessibilityAction(named: session.notes.isBlank ? "Add notes" : "Edit notes") {
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
    @State var session: TrainingSession
    @State private var showingEditor = false
    @State private var confirmDelete = false
    @State private var calendarMessage = ""

    var body: some View {
        List {
            Section("Summary") {
                SummaryRow(title: session.trainingType.rawValue, value: "\(session.date.shortTennisDate). \(session.hasStartTime ? "Starts \(session.date.shortTennisTime)." : "Start time not specified.") \(session.durationMinutes.durationText). Expected end \(session.hasStartTime ? session.expectedEndDate.shortTennisTime : "not available"). \(session.placeText).")
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
                    TextField("Venue", text: $session.venue)
                    TextField("Location", text: $session.location)
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
        store.upsertTraining(session)
        dismiss()
    }
}
