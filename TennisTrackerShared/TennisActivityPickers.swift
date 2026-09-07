import SwiftUI

private struct TennisChoiceRow: View {
    let title: String
    var selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer()
                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
        }.accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct TennisVenuePicker: View {
    let choices: [TennisVenueChoice]
    @Binding var venueID: UUID?
    @Binding var venue: String
    @Binding var location: String
    @State private var showingChoices = false
    @State private var otherSelected = false

    private var saved: TennisVenueChoice? {
        choices.first { ($0.venueID != nil && $0.venueID == venueID) || $0.id == TennisVenueChoice.key(venue, location) }
    }
    private var isOther: Bool { otherSelected || (saved == nil && (!venue.isBlank || !location.isBlank)) }

    var body: some View {
        NavigationLink(isActive: $showingChoices) {
            TennisList {
                TennisChoiceRow(title: "No venue", selected: !isOther && saved == nil) {
                    venueID = nil; venue = ""; location = ""; otherSelected = false; showingChoices = false
                }
                ForEach(choices) { choice in
                    TennisChoiceRow(title: choice.summary, selected: !otherSelected && saved?.id == choice.id) {
                        venueID = choice.venueID; venue = choice.name; location = choice.location
                        otherSelected = false; showingChoices = false
                    }
                }
                TennisChoiceRow(title: "Other", selected: isOther) {
                    venueID = nil; otherSelected = true; showingChoices = false
                }
            }.navigationTitle("Venue")
        } label: {
            LabeledContent("Venue", value: isOther ? "Other" : saved?.summary ?? "No venue")
        }
        .accessibilityLabel("Venue")
        .accessibilityValue(isOther ? "Other" : saved?.summary ?? "No venue")
        .accessibilityIdentifier("activityVenuePicker")
        if isOther {
            TextField("Other venue name", text: $venue).accessibilityIdentifier("otherVenueName")
            TextField("Town or city", text: $location)
        }
    }
}

struct TennisTournamentPicker: View {
    let tournaments: [TournamentRecord]
    @Binding var tournamentID: UUID?
    @Binding var customName: String?
    @State private var showingChoices = false

    private var value: String {
        if customName != nil { return "Other" }
        guard let tournamentID else { return "No tournament" }
        return tournaments.first { $0.id == tournamentID }?.name.fallback("Unnamed tournament") ?? "Linked tournament"
    }

    var body: some View {
        NavigationLink(isActive: $showingChoices) {
            TennisList {
                TennisChoiceRow(title: "No tournament", selected: tournamentID == nil && customName == nil) {
                    tournamentID = nil; customName = nil; showingChoices = false
                }
                ForEach(tournaments) { tournament in
                    TennisChoiceRow(title: tournament.name.fallback("Unnamed tournament"), selected: tournamentID == tournament.id) {
                        customName = nil; tournamentID = tournament.id; showingChoices = false
                    }
                }
                TennisChoiceRow(title: "Other", selected: customName != nil) {
                    tournamentID = nil; customName = customName ?? ""; showingChoices = false
                }
            }.navigationTitle("Tournament")
        } label: { LabeledContent("Tournament", value: value) }
        .accessibilityLabel("Tournament")
        .accessibilityValue(value)
        .accessibilityIdentifier("activityTournamentPicker")
        if customName != nil {
            TextField("Other tournament name", text: Binding(get: { customName ?? "" }, set: { customName = $0 }))
                .accessibilityIdentifier("otherTournamentName")
        }
    }
}
