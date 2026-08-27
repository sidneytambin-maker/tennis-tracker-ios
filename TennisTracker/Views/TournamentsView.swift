import SwiftUI

struct TournamentsView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var showingNewTournament = false

    private var upcoming: [TournamentRecord] {
        store.selectedTournaments.filter { !$0.isCompleted }.sorted { $0.date < $1.date }
    }

    private var completed: [TournamentRecord] {
        store.selectedTournaments.filter(\.isCompleted).sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.selectedTournaments.isEmpty {
                    Section {
                        EmptyStateView(title: "No tournaments added yet", message: "Add an upcoming tournament, then link matches to it later.")
                    }
                } else {
                    Section("Upcoming tournaments") {
                        if upcoming.isEmpty {
                            Text("No upcoming tournaments.")
                        } else {
                            ForEach(upcoming) { tournamentRow($0) }
                        }
                    }

                    Section("Completed tournaments") {
                        if completed.isEmpty {
                            Text("No completed tournaments.")
                        } else {
                            ForEach(completed) { tournamentRow($0) }
                        }
                    }
                }
            }
            .tennisThemedList()
            .navigationTitle("Tournaments")
            .toolbar {
                Button("Add") { showingNewTournament = true }
                    .accessibilityLabel("Add tournament")
                    .accessibilityIdentifier("addTournamentButton")
            }
            .sheet(isPresented: $showingNewTournament) {
                if let tournament = store.makeDefaultTournament() {
                    TournamentEditorView(tournament: tournament)
                }
            }
        }
    }

    private func tournamentRow(_ tournament: TournamentRecord) -> some View {
        NavigationLink {
            TournamentDetailView(tournament: tournament)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(tournament.date.shortTennisDate): \(tournament.name.fallback("Unnamed tournament"))")
                Text("\(tournament.location.fallback("location not recorded")). \(tournament.finalResult.rawValue).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(tournament.name.fallback("Unnamed tournament"))
        .accessibilityValue("\(tournament.date.shortTennisDate), \(tournament.location.fallback("location not recorded")), \(tournament.finalResult.rawValue)")
    }
}

struct TournamentDetailView: View {
    @EnvironmentObject private var store: TennisStore
    @State var tournament: TournamentRecord
    @State private var showingEditor = false
    @State private var showingNewMatch = false
    @State private var confirmDelete = false

    private var linkedMatches: [MatchRecord] {
        store.selectedMatches.filter { $0.tournamentID == tournament.id }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section("Summary") {
                SummaryRow(title: tournament.name.fallback("Unnamed tournament"), value: dateRangeText)
                SummaryRow(title: "Status", value: "\(tournament.finalResult.rawValue). \(tournament.format.rawValue). Stage: \(tournament.stageReached.rawValue).")
                SummaryRow(title: "Matches", value: linkedMatches.isEmpty ? "No matches linked yet." : "\(linkedMatches.count) matches linked.")
            }

            Section("Matches") {
                Button("Add match to this tournament") { showingNewMatch = true }
                    .accessibilityIdentifier("addTournamentMatchButton")
                if linkedMatches.isEmpty {
                    Text("Tournament matches will appear here after they are saved.")
                } else {
                    ForEach(linkedMatches) { match in
                        NavigationLink("\(match.result.rawValue) against \(match.opponentSummary.fallback("opponent not recorded"))") {
                            MatchDetailView(match: match)
                        }
                    }
                }
            }

            if !tournament.goal.isBlank {
                Section("Goal") {
                    Text(tournament.goal)
                }
            }

            Section("Notes") {
                Text(tournament.notes.fallback("No notes recorded."))
            }

            Section {
                Button("Delete tournament", role: .destructive) { confirmDelete = true }
            }
        }
        .tennisThemedList()
        .navigationTitle(tournament.name.fallback("Tournament"))
        .toolbar {
            Button("Edit") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            TournamentEditorView(tournament: tournament)
        }
        .sheet(isPresented: $showingNewMatch) {
            if let match = store.makeDefaultMatch(tournamentID: tournament.id) {
                MatchEditorView(match: match)
            }
        }
        .confirmationDialog("Delete this tournament?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete tournament", role: .destructive) {
                store.deleteTournament(tournament)
            }
        }
    }

    private var dateRangeText: String {
        let base = "\(tournament.date.shortTennisDate), \(tournament.location.fallback("location not recorded"))."
        if Calendar.current.isDate(tournament.date, inSameDayAs: tournament.endDate) {
            return base
        }
        return "\(tournament.date.shortTennisDate) to \(tournament.endDate.shortTennisDate), \(tournament.location.fallback("location not recorded"))."
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
                        .accessibilityIdentifier("tournamentNameField")
                    TextField("Venue", text: $tournament.location)
                        .accessibilityIdentifier("tournamentVenueField")
                    DateShortcutPicker(title: "Start date", date: $tournament.date)
                        .accessibilityIdentifier("tournamentStartDatePicker")
                    DateShortcutPicker(title: "End date", date: $tournament.endDate)
                        .accessibilityIdentifier("tournamentEndDatePicker")
                }

                Section("Category and status") {
                    TextField("Category", text: $tournament.category)
                    Picker("Format", selection: $tournament.format) {
                        ForEach(TournamentFormat.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("tournamentFormatPicker")
                    Picker("Status", selection: $tournament.finalResult) {
                        ForEach(TournamentResult.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("tournamentStatusPicker")
                    Picker("Stage reached", selection: $tournament.stageReached) {
                        ForEach(TournamentStage.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("tournamentStagePicker")
                    Stepper("Matches expected or played \(tournament.matchesPlayed)", value: $tournament.matchesPlayed, in: 0...99)
                }

                if store.data.settings.trackingMode != .basic {
                    Section("Goal") {
                        TextField("Goal", text: $tournament.goal, axis: .vertical)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $tournament.notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("tournamentNotesField")
                }
            }
            .tennisThemedList()
            .navigationTitle("Tournament")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if tournament.endDate < tournament.date {
                            tournament.endDate = tournament.date
                        }
                        store.upsertTournament(tournament)
                        dismiss()
                    }
                    .accessibilityIdentifier("saveTournamentButton")
                }
            }
        }
    }
}
