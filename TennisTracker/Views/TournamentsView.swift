import SwiftUI

struct TournamentsView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var showingNewTournament = false

    var body: some View {
        NavigationStack {
            List {
                Section("Tournaments") {
                    if store.selectedTournaments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            EmptyStateView(title: "No tournaments added yet", message: "Upcoming and completed tournaments will appear here.")
                            Button("Add tournament") { showingNewTournament = true }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("emptyAddTournamentButton")
                        }
                    } else {
                        ForEach(store.selectedTournaments) { tournament in
                            NavigationLink {
                                TournamentDetailView(tournament: tournament)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(tournament.date.shortTennisDate): \(tournament.name.fallback("Unnamed tournament"))")
                                    Text("\(tournament.location.fallback("location not recorded")). \(tournament.stageReached).")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tournaments")
            .toolbar {
                Button("Add") { showingNewTournament = true }
                    .accessibilityLabel("Add tournament")
                    .accessibilityIdentifier("addTournamentButton")
            }
            .sheet(isPresented: $showingNewTournament) {
                if let playerID = store.selectedPlayerID {
                    TournamentEditorView(tournament: TournamentRecord(playerID: playerID))
                }
            }
        }
    }
}

struct TournamentDetailView: View {
    @EnvironmentObject private var store: TennisStore
    @State var tournament: TournamentRecord
    @State private var showingEditor = false
    @State private var confirmDelete = false

    private var linkedMatches: [MatchRecord] {
        store.selectedMatches.filter { $0.tournamentID == tournament.id }
    }

    var body: some View {
        List {
            Section("Summary") {
                SummaryRow(title: tournament.name.fallback("Unnamed tournament"), value: "\(tournament.date.shortTennisDate), \(tournament.location.fallback("location not recorded")).")
                SummaryRow(title: "Status", value: "\(tournament.finalResult). \(tournament.format). Stage: \(tournament.stageReached).")
                SummaryRow(title: "Matches", value: "\(linkedMatches.count) linked. \(tournament.outstandingMatches(linkedMatchCount: linkedMatches.count)) still need adding.")
            }
            Section("Preparation") {
                Text(tournament.goal.fallback("No goal recorded."))
                Text(tournament.preparationNotes.fallback("No preparation notes recorded."))
            }
            Section("Review") {
                Text(tournament.reviewNotes.fallback("No review notes recorded."))
                Text(tournament.notes.fallback("No extra notes recorded."))
            }
            Section {
                Button("Delete tournament", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle("Tournament")
        .toolbar {
            Button("Edit") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            TournamentEditorView(tournament: tournament)
        }
        .confirmationDialog("Delete this tournament?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete tournament", role: .destructive) {
                store.deleteTournament(tournament)
            }
        }
    }
}

struct TournamentEditorView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State var tournament: TournamentRecord

    var body: some View {
        NavigationStack {
            Form {
                Section("Tournament") {
                    TextField("Name", text: $tournament.name)
                    TextField("Location", text: $tournament.location)
                    DatePicker("Date", selection: $tournament.date, displayedComponents: .date)
                    TextField("Format", text: $tournament.format)
                    TextField("Final result", text: $tournament.finalResult)
                    TextField("Stage reached", text: $tournament.stageReached)
                    Stepper("Matches planned or played \(tournament.matchesPlayed)", value: $tournament.matchesPlayed, in: 0...99)
                }
                Section("Goal and Notes") {
                    TextField("Goal", text: $tournament.goal, axis: .vertical)
                    TextField("Preparation notes", text: $tournament.preparationNotes, axis: .vertical)
                    TextField("Review notes", text: $tournament.reviewNotes, axis: .vertical)
                    TextField("Notes", text: $tournament.notes, axis: .vertical)
                }
            }
            .navigationTitle("Tournament")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.upsertTournament(tournament)
                        dismiss()
                    }
                }
            }
        }
    }
}
