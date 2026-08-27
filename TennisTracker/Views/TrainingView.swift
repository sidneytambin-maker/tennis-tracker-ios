import SwiftUI

struct TrainingView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var showingNewTraining = false

    var body: some View {
        NavigationStack {
            List {
                Section("Training History") {
                    if store.selectedTraining.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            EmptyStateView(title: "No training sessions recorded yet", message: "Training sessions will appear here after you add them.")
                            Button("Add training session") { showingNewTraining = true }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("emptyAddTrainingButton")
                        }
                    } else {
                        ForEach(store.selectedTraining) { session in
                            NavigationLink {
                                TrainingDetailView(session: session)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(session.date.shortTennisDate): \(session.placeText)")
                                    Text("\(session.durationMinutes) minutes. Focus: \(session.focus.fallback("not recorded")).")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Training")
            .toolbar {
                Button("Add") { showingNewTraining = true }
                    .accessibilityLabel("Add training")
                    .accessibilityIdentifier("addTrainingButton")
            }
            .sheet(isPresented: $showingNewTraining) {
                if let playerID = store.selectedPlayerID {
                    TrainingEditorView(session: TrainingSession(playerID: playerID))
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
                SummaryRow(title: session.placeText, value: "\(session.date.shortTennisDate). \(session.durationMinutes) minutes.")
                SummaryRow(title: "Focus", value: session.focus.fallback("not recorded"))
                SummaryRow(title: "Outcome", value: session.sessionOutcome.fallback("not recorded"))
            }
            Section("Body and Conditions") {
                SummaryRow(title: "Effort", value: session.effortLevel)
                SummaryRow(title: "Confidence", value: session.confidenceLevel)
                SummaryRow(title: "Energy", value: session.energyLevel)
                SummaryRow(title: "Pain", value: session.painLevel)
                Text(session.trainingConditions.fallback("No training conditions recorded."))
                Text(session.weatherConditions.fallback("No weather conditions recorded."))
                Text(session.equipmentNotes.fallback("No equipment notes recorded."))
            }
            Section("Notes") {
                Text(session.notes.fallback("No notes recorded."))
            }
            Section {
                Button("Delete training session", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle("Training Detail")
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
                    Toggle("Has session details", isOn: $session.hasSessionDetails)
                    DatePicker("Date", selection: $session.date, displayedComponents: .date)
                    Stepper("Duration \(session.durationMinutes) minutes", value: $session.durationMinutes, in: 0...480, step: 5)
                    TextField("Location", text: $session.location)
                    TextField("Venue", text: $session.venue)
                    TextField("Venue type", text: $session.venueType)
                    TextField("Focus", text: $session.focus)
                }
                if session.hasSessionDetails {
                    Section("Session Detail") {
                        TextField("Effort level", text: $session.effortLevel)
                        TextField("Confidence level", text: $session.confidenceLevel)
                        TextField("Session outcome", text: $session.sessionOutcome, axis: .vertical)
                        TextField("Energy level", text: $session.energyLevel)
                        TextField("Pain level", text: $session.painLevel)
                        TextField("Training conditions", text: $session.trainingConditions, axis: .vertical)
                        TextField("Weather conditions", text: $session.weatherConditions, axis: .vertical)
                        TextField("Equipment notes", text: $session.equipmentNotes, axis: .vertical)
                        TextField("Notes", text: $session.notes, axis: .vertical)
                    }
                }
            }
            .navigationTitle("Training")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.upsertTraining(session)
                        dismiss()
                    }
                }
            }
        }
    }
}
