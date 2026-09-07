import SwiftUI

struct WatchTrainingEditor: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Environment(\.dismiss) private var dismiss
    @State var draft: TrainingSession

    var body: some View {
        Form {
            Picker("Training type", selection: $draft.trainingType) {
                ForEach(TrainingType.allCases) { Text($0.rawValue).tag($0) }
            }
            NavigationLink("Coaches") {
                List {
                    ForEach(store.snapshot.setup.coaches) { coach in
                        TennisSelectionRow(name: coach.name, id: coach.id, selectedIDs: $draft.context.coachIDs)
                    }
                }.navigationTitle("Coaches")
            }
            .accessibilityValue(draft.context.coachSummary(in: store.snapshot.setup.coaches).fallback("None"))
            .onChange(of: draft.context.coachIDs) { _, _ in draft.context.coachName = "" }
            NavigationLink("Players Present") {
                List {
                    ForEach(store.snapshot.players.filter { $0.id != draft.playerID }) { player in
                        TennisSelectionRow(name: player.displayName, id: player.id, selectedIDs: $draft.context.participantIDs)
                    }
                }.navigationTitle("Players Present")
            }
            .accessibilityValue(draft.context.participantSummary(in: store.snapshot.players).fallback("None"))
            .onChange(of: draft.context.participantIDs) { _, _ in draft.context.participantNames = [] }
            WatchVenueFields(venueID: $draft.context.venueID, venue: $draft.venue, location: $draft.location)
            Picker("Tournament", selection: $draft.context.tournamentID) {
                Text("No tournament").tag(Optional<UUID>.none)
                ForEach(store.snapshot.tournaments) { Text($0.name).tag(Optional($0.id)) }
            }
            TextField("Notes", text: $draft.notes)
            Toggle("Include session feedback", isOn: $draft.hasSessionDetails)
            if draft.hasSessionDetails {
                TextField("Session outcome", text: $draft.sessionOutcome)
                OrderedChoicePicker(title: "Effort", selection: $draft.effortLevel, values: RatingLevel.allCases) { $0.rawValue }
            }
            Toggle("Details complete", isOn: Binding(get: { !draft.needsDetails }, set: { draft.needsDetails = !$0 }))
        }
        .navigationTitle("Edit Training")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    draft.context.captureLegacyNames(coaches: store.snapshot.setup.coaches, players: store.snapshot.players)
                    store.updateTrainingDetails(draft)
                    dismiss()
                }
            }
        }
    }
}

struct WatchMatchEditor: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Environment(\.dismiss) private var dismiss
    @State var draft: MatchRecord

    var body: some View {
        Form {
            TennisPersonPicker(title: "Opponent", players: store.snapshot.players.filter { $0.id != draft.playerID && $0.id != draft.partnerID && $0.id != draft.opponent2ID }, selection: $draft.opponentID, name: $draft.opponentName)
            if draft.matchType == .doubles {
                TennisPersonPicker(title: "Partner", players: store.snapshot.players.filter { $0.id != draft.playerID && $0.id != draft.opponentID && $0.id != draft.opponent2ID }, selection: $draft.partnerID, name: $draft.partnerName, regularPartnersFirst: true)
                TennisPersonPicker(title: "Second opponent", players: store.snapshot.players.filter { $0.id != draft.playerID && $0.id != draft.opponentID && $0.id != draft.partnerID }, selection: $draft.opponent2ID, name: $draft.opponent2Name)
            }
            WatchVenueFields(venueID: $draft.venueID, venue: $draft.venue, location: $draft.location)
            Picker("Tournament", selection: $draft.tournamentID) {
                Text("No tournament").tag(Optional<UUID>.none)
                ForEach(store.snapshot.tournaments) { Text($0.name).tag(Optional($0.id)) }
            }
            TextField("Notes", text: $draft.notes)
            Toggle("Details complete", isOn: Binding(get: { !draft.needsDetails }, set: { draft.needsDetails = !$0 }))
        }
        .navigationTitle("Edit Match")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { store.updateMatchDetails(draft); dismiss() } }
        }
    }
}

struct WatchTournamentEditor: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Environment(\.dismiss) private var dismiss
    @State var draft: TournamentRecord

    var body: some View {
        Form {
            TextField("Tournament name", text: $draft.name)
            WatchDateField(title: "Start date", date: $draft.date)
                .onChange(of: draft.date) { _, date in if draft.endDate < date { draft.endDate = date } }
            WatchDateField(title: "End date", date: $draft.endDate)
                .onChange(of: draft.endDate) { _, date in if date < draft.date { draft.endDate = draft.date } }
            WatchVenueFields(venueID: $draft.venueID, venue: $draft.venue, location: $draft.location)
            Picker("Stage reached", selection: $draft.stageReached) {
                ForEach(TournamentStage.allCases) { Text($0.rawValue).tag($0) }
            }
            TextField("Notes", text: $draft.notes)
            Toggle("Details complete", isOn: Binding(get: { !draft.needsDetails }, set: { draft.needsDetails = !$0 }))
        }
        .navigationTitle("Edit Tournament")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { store.updateTournamentDetails(draft); dismiss() }.disabled(draft.name.isBlank)
            }
        }
    }
}

private struct WatchVenueFields: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Binding var venueID: UUID?
    @Binding var venue: String
    @Binding var location: String

    var body: some View {
        Picker("Venue", selection: $venueID) {
            Text("Other or no venue").tag(Optional<UUID>.none)
            ForEach(store.snapshot.setup.venues) { Text($0.summary).tag(Optional($0.id)) }
        }
        .onChange(of: venueID) { _, id in
            if let saved = store.snapshot.setup.venues.first(where: { $0.id == id }) {
                venue = saved.name; location = saved.town
            } else { venue = ""; location = "" }
        }
        if venueID == nil {
            TextField("Venue name", text: $venue)
            TextField("Location", text: $location)
        }
    }
}

private struct WatchDateField: View {
    let title: String
    @Binding var date: Date
    private let calendar = Calendar.current

    var body: some View {
        NavigationLink(title) {
            Form {
                OrderedChoicePicker(title: "Day", selection: component(.day), values: Array(calendar.range(of: .day, in: .month, for: date) ?? 1..<32)) { String($0) }
                OrderedChoicePicker(title: "Month", selection: component(.month), values: Array(1...12)) { calendar.monthSymbols[$0 - 1] }
                OrderedChoicePicker(title: "Year", selection: component(.year), values: Array(min(1900, calendar.component(.year, from: date))...max(2100, calendar.component(.year, from: date)))) { String($0) }
            }.navigationTitle(title)
        }.accessibilityValue(date.fullTennisDate)
    }

    private func component(_ component: Calendar.Component) -> Binding<Int> {
        Binding(get: { calendar.component(component, from: date) }, set: { value in
            var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            parts.setValue(value, for: component)
            let requestedDay = parts.day ?? 1
            parts.day = 1
            guard let first = calendar.date(from: parts), let range = calendar.range(of: .day, in: .month, for: first) else { return }
            parts.day = min(requestedDay, range.count)
            date = calendar.date(from: parts) ?? date
        })
    }
}
