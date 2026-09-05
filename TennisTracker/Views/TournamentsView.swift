import SwiftUI

struct TournamentsView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var showingNewTournament = false
    @State private var tournamentToEdit: TournamentRecord?
    @State private var tournamentToDelete: TournamentRecord?
    @State private var matchTournament: TournamentRecord?
    @State private var confirmDelete = false

    private var upcoming: [TournamentRecord] {
        store.selectedTournaments.filter { !$0.isCompleted }.sorted { $0.date < $1.date }
    }

    private var completed: [TournamentRecord] {
        store.selectedTournaments.filter(\.isCompleted).sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Track") {
                    Button("Track Tournament") { showingNewTournament = true }
                        .accessibilityLabel("Track Tournament")
                        .accessibilityIdentifier("addTournamentButton")
                }
                if store.selectedTournaments.isEmpty {
                    Section {
                        EmptyStateView(title: "No tournaments added yet", message: "Track an upcoming tournament, then link matches to it later.")
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
            .sheet(isPresented: $showingNewTournament) {
                if let tournament = store.makeDefaultTournament() {
                    TournamentEditorView(tournament: tournament)
                }
            }
            .sheet(item: $tournamentToEdit) { tournament in
                TournamentEditorView(tournament: tournament)
            }
            .sheet(item: $matchTournament) { tournament in
                if let match = store.makeDefaultMatch(tournamentID: tournament.id) {
                    MatchEditorView(match: match)
                }
            }
            .confirmationDialog("Delete this tournament?", isPresented: $confirmDelete, titleVisibility: .visible) {
                if let selectedTournament = tournamentToDelete, !store.linkedMatches(for: selectedTournament).isEmpty {
                    Button("Delete Tournament Only, Keep Matches", role: .destructive) {
                        store.deleteTournamentKeepingMatches(selectedTournament)
                        tournamentToDelete = nil
                    }
                    Button("Delete Tournament and Linked Matches", role: .destructive) {
                        store.deleteTournamentAndLinkedMatches(selectedTournament)
                        tournamentToDelete = nil
                    }
                } else {
                    Button("Delete Tournament", role: .destructive) {
                        if let selectedTournament = tournamentToDelete {
                            store.deleteTournamentKeepingMatches(selectedTournament)
                        }
                        tournamentToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { tournamentToDelete = nil }
            }
        }
    }

    private func tournamentRow(_ tournament: TournamentRecord) -> some View {
        NavigationLink {
            TournamentDetailView(tournament: tournament)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(tournament.date.shortTennisDate): \(tournament.name.fallback("Unnamed tournament"))")
                Text(TennisSummaryFormatter.tournament(tournament, matches: store.linkedMatches(for: tournament)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(tournament.name.fallback("Unnamed tournament"))
        .accessibilityValue("\(tournament.date.shortTennisDate), \(tournament.location.fallback("location not recorded")), \(tournament.finalResult.rawValue)")
        .accessibilityAction(named: "Edit tournament") {
            tournamentToEdit = tournament
        }
        .accessibilityAction(named: "Add Match to Tournament") {
            matchTournament = tournament
        }
        .accessibilityAction(named: "Add to Calendar") {
            addToCalendar(tournament)
        }
        .accessibilityAction(named: "Delete tournament") {
            tournamentToDelete = tournament
            confirmDelete = true
        }
    }

    private func addToCalendar(_ tournament: TournamentRecord) {
        Task {
            let success = await TennisCalendarService.shared.save(TennisCalendarMapper.event(for: tournament))
            store.announce(success ? "Added tournament to Apple Calendar." : "Calendar access was not granted or the event could not be saved.")
        }
    }
}

struct TournamentDetailView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State var tournament: TournamentRecord
    @State private var showingEditor = false
    @State private var showingNewMatch = false
    @State private var confirmDelete = false
    @State private var calendarMessage = ""

    private var linkedMatches: [MatchRecord] {
        store.linkedMatches(for: tournament)
    }

    var body: some View {
        List {
            Section("Summary") {
                Text(TennisSummaryFormatter.tournament(tournament, style: .detailed, matches: linkedMatches))
                SummaryRow(title: "Status", value: "\(tournament.finalResult.rawValue). \(tournament.format.rawValue). Stage: \(tournament.stageReached.rawValue).")
                SummaryRow(title: "Matches", value: linkedMatches.isEmpty ? "No matches linked yet." : "\(linkedMatches.count) matches linked.")
            }

            Section("Matches") {
                Button("Add Match to Tournament") { showingNewMatch = true }
                    .accessibilityIdentifier("addTournamentMatchButton")
                if linkedMatches.isEmpty {
                    Text("Tournament matches will appear here after they are saved.")
                } else {
                    ForEach(linkedMatches) { match in
                        NavigationLink {
                            MatchDetailView(match: match)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(TennisSummaryFormatter.match(match, tournaments: store.selectedTournaments, style: .short))
                                Text(match.matchPosition.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Tournament match")
                        .accessibilityValue(TennisSummaryFormatter.match(match, tournaments: store.selectedTournaments, style: .accessibility))
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

            Section("Calendar") {
                Button("Add to Apple Calendar") {
                    addToCalendar()
                }
                if !calendarMessage.isBlank {
                    Text(calendarMessage)
                }
            }

            Section {
                Button("Delete tournament", role: .destructive) { confirmDelete = true }
            }
        }
        .tennisThemedList()
        .navigationTitle(tournament.name.fallback("Tournament"))
        .onChange(of: store.data.tournaments) { _, tournaments in
            if let updated = tournaments.first(where: { $0.id == tournament.id }) { tournament = updated }
            else { dismiss() }
        }
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
            if linkedMatches.isEmpty {
                Button("Delete Tournament", role: .destructive) {
                    store.deleteTournamentKeepingMatches(tournament)
                }
            } else {
                Button("Delete Tournament Only, Keep Matches", role: .destructive) {
                    store.deleteTournamentKeepingMatches(tournament)
                }
                Button("Delete Tournament and Linked Matches", role: .destructive) {
                    store.deleteTournamentAndLinkedMatches(tournament)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func addToCalendar() {
        Task {
            let success = await TennisCalendarService.shared.save(TennisCalendarMapper.event(for: tournament))
            calendarMessage = success ? "Added to Apple Calendar." : "Calendar access was not granted or the event could not be saved."
            store.announce(calendarMessage)
        }
    }

    private var dateRangeText: String {
        let base = "\(tournament.date.shortTennisDate), \(tournament.location.fallback("location not recorded"))."
        if Calendar.current.isDate(tournament.date, inSameDayAs: tournament.endDate) {
            return base
        }
        return "\(tournament.date.shortTennisDate) to \(tournament.endDate.shortTennisDate), \(tournament.location.fallback("location not recorded"))."
    }

    private func scoreSummary(_ match: MatchRecord) -> String {
        TennisSummaryFormatter.matchSummary(match, tournaments: store.selectedTournaments).scoreText
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
                    Picker("Regular tournament", selection: $tournament.templateID) {
                        Text("Other").tag(Optional<UUID>.none)
                        ForEach(store.data.setup.tournamentTemplates) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .onChange(of: tournament.templateID) { _, id in
                        if let template = store.data.setup.tournamentTemplates.first(where: { $0.id == id }) {
                            tournament.name = template.name
                            tournament.format = template.format
                            tournament.venueID = template.venueID
                            if let venue = store.data.setup.venues.first(where: { $0.id == template.venueID }) {
                                tournament.venue = venue.name; tournament.location = venue.town
                            }
                        }
                    }
                    TextField("Name", text: $tournament.name)
                        .accessibilityIdentifier("tournamentNameField")
                    StoredVenuePicker(id: $tournament.venueID, venue: $tournament.venue, location: $tournament.location)
                    Toggle("All-day tournament", isOn: $tournament.isAllDay)
                    AccessibleDateTimeEditor(
                        dateTitle: "Start date",
                        timeTitle: "Start time",
                        date: $tournament.date,
                        hasStartTime: $tournament.hasStartTime,
                        allowsUnspecifiedTime: !tournament.isAllDay
                    )
                        .accessibilityIdentifier("tournamentStartDatePicker")
                    DatePicker("End date", selection: $tournament.endDate, in: tournament.date..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .accessibilityLabel("Tournament end date")
                        .accessibilityValue(tournament.endDate.fullTennisDate)
                        .accessibilityHint("Opens the native date picker. The end date cannot be before the start date.")
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
                    NumberChoicePicker(title: "Matches expected or played", value: $tournament.matchesPlayed, range: 0...99, suffix: "matches")
                        .accessibilityIdentifier("tournamentMatchesPlayedPicker")
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
            .onChange(of: tournament.isAllDay) { _, isAllDay in
                if isAllDay {
                    tournament.hasStartTime = false
                }
            }
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
