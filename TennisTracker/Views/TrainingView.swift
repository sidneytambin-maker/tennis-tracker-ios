import SwiftUI

struct TrainingView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var showingNewTraining = false

    var body: some View {
        NavigationStack {
            List {
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
                                    Text("\(session.durationMinutes) minutes. Focus: \(session.focus.fallback("not recorded")).")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityLabel("Training session")
                            .accessibilityValue("\(session.date.shortTennisDate), \(session.trainingType.rawValue), \(session.durationMinutes) minutes, focus \(session.focus.fallback("not recorded"))")
                        }
                    }
                }
            }
            .tennisThemedList()
            .navigationTitle("Training")
            .toolbar {
                Button("Add") { showingNewTraining = true }
                    .accessibilityLabel("Add training session")
                    .accessibilityIdentifier("addTrainingButton")
            }
            .sheet(isPresented: $showingNewTraining) {
                if let session = store.makeDefaultTraining() {
                    TrainingEditorView(session: session)
                }
            }
        }
    }
}

struct TrainingDetailView: View {
    @EnvironmentObject private var store: TennisStore
    @State var session: TrainingSession
    @State private var showingEditor = false
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section("Summary") {
                SummaryRow(title: session.trainingType.rawValue, value: "\(session.date.shortTennisDate). \(session.durationMinutes) minutes. \(session.placeText).")
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
            Button("Delete training session", role: .destructive) {
                store.deleteTraining(session)
            }
        }
    }
}

struct TrainingEditorView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State var session: TrainingSession

    var body: some View {
        NavigationStack {
            Form {
                Section("Training") {
                    Picker("Session type", selection: $session.trainingType) {
                        ForEach(TrainingType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("trainingTypePicker")
                    DateShortcutPicker(title: "Date", date: $session.date)
                        .accessibilityIdentifier("trainingDatePicker")
                    Stepper("Duration \(session.durationMinutes) minutes", value: $session.durationMinutes, in: 0...480, step: 5)
                    TextField("Venue", text: $session.venue)
                    TextField("Location", text: $session.location)
                    Picker("Surface", selection: $session.surface) {
                        ForEach(CourtSurface.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("trainingSurfacePicker")
                    TextField("Focus", text: $session.focus)
                }

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
                        store.upsertTraining(session)
                        dismiss()
                    }
                    .accessibilityIdentifier("saveTrainingButton")
                }
            }
        }
    }
}
