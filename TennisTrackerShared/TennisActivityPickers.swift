import SwiftUI

private enum VenueSelection: Hashable {
    case none, other, saved(String)
}

struct TennisVenuePicker: View {
    let choices: [TennisVenueChoice]
    @Binding var venueID: UUID?
    @Binding var venue: String
    @Binding var location: String
    @State private var otherSelected = false

    private var saved: TennisVenueChoice? {
        choices.first { ($0.venueID != nil && $0.venueID == venueID) || $0.id == TennisVenueChoice.key(venue, location) }
    }
    private var isOther: Bool { otherSelected || (saved == nil && (!venue.isBlank || !location.isBlank)) }
    private var value: String { isOther ? "Other" : saved?.summary ?? "No venue" }
    private var selection: Binding<VenueSelection> {
        Binding {
            if isOther { return .other }
            return saved.map { .saved($0.id) } ?? .none
        } set: { option in
            switch option {
            case .none:
                venueID = nil; venue = ""; location = ""; otherSelected = false
            case .other:
                venueID = nil; otherSelected = true
            case .saved(let key):
                guard let choice = choices.first(where: { $0.id == key }) else { return }
                venueID = choice.venueID; venue = choice.name; location = choice.location
                otherSelected = false
            }
        }
    }

    var body: some View {
        Picker("Venue", selection: selection) {
            Text("No venue").tag(VenueSelection.none)
            ForEach(choices) { Text($0.summary).tag(VenueSelection.saved($0.id)) }
            Text("Other").tag(VenueSelection.other)
        }
        #if os(watchOS)
        .pickerStyle(.navigationLink)
        #else
        .pickerStyle(.menu)
        #endif
        .accessibilityLabel("Venue")
        .accessibilityValue(value)
        .accessibilityIdentifier("activityVenuePicker")
        if isOther {
            TextField("Other venue name", text: $venue).accessibilityIdentifier("otherVenueName")
            TextField("Town or city", text: $location)
        }
    }
}

private enum TournamentSelection: Hashable {
    case none, other, saved(UUID)
}

struct TennisTournamentPicker: View {
    let tournaments: [TournamentRecord]
    @Binding var tournamentID: UUID?
    @Binding var customName: String?

    private var value: String {
        if customName != nil { return "Other" }
        guard let tournamentID else { return "No tournament" }
        return tournaments.first { $0.id == tournamentID }?.name.fallback("Unnamed tournament") ?? "Linked tournament"
    }
    private var selection: Binding<TournamentSelection> {
        Binding {
            if customName != nil { return .other }
            return tournamentID.map { .saved($0) } ?? .none
        } set: { option in
            switch option {
            case .none: tournamentID = nil; customName = nil
            case .other: tournamentID = nil; customName = customName ?? ""
            case .saved(let id): customName = nil; tournamentID = id
            }
        }
    }

    var body: some View {
        Picker("Tournament", selection: selection) {
            Text("No tournament").tag(TournamentSelection.none)
            ForEach(tournaments) { Text($0.name.fallback("Unnamed tournament")).tag(TournamentSelection.saved($0.id)) }
            if let tournamentID, !tournaments.contains(where: { $0.id == tournamentID }) {
                Text("Linked tournament").tag(TournamentSelection.saved(tournamentID))
            }
            Text("Other").tag(TournamentSelection.other)
        }
        #if os(watchOS)
        .pickerStyle(.navigationLink)
        #else
        .pickerStyle(.menu)
        #endif
        .accessibilityLabel("Tournament")
        .accessibilityValue(value)
        .accessibilityIdentifier("activityTournamentPicker")
        if customName != nil {
            TextField("Other tournament name", text: Binding(get: { customName ?? "" }, set: { customName = $0 }))
                .accessibilityIdentifier("otherTournamentName")
        }
    }
}
