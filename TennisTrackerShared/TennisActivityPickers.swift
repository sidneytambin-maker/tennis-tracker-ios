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
    @State private var otherSelected = false

    private var saved: TennisVenueChoice? {
        choices.first { ($0.venueID != nil && $0.venueID == venueID) || $0.id == TennisVenueChoice.key(venue, location) }
    }
    private var isOther: Bool { otherSelected || (saved == nil && (!venue.isBlank || !location.isBlank)) }

    var body: some View {
        NavigationLink {
            TennisVenueChoices(choices: choices, venueID: $venueID, venue: $venue, location: $location, otherSelected: $otherSelected)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Venue")
                Text(isOther ? "Other" : saved?.summary ?? "No venue").font(.callout).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityLabel("Venue")
        .accessibilityValue(isOther ? "Other" : saved?.summary ?? "No venue")
        .accessibilityIdentifier("activityVenuePicker")
        .onChange(of: venueID) { _, id in if id != nil { otherSelected = false } }
        if isOther {
            TextField("Other venue name", text: $venue).accessibilityIdentifier("otherVenueName")
            TextField("Town or city", text: $location)
        }
    }
}

private struct TennisVenueChoices: View {
    @Environment(\.dismiss) private var dismiss
    let choices: [TennisVenueChoice]
    @Binding var venueID: UUID?
    @Binding var venue: String
    @Binding var location: String
    @Binding var otherSelected: Bool

    private var saved: TennisVenueChoice? {
        choices.first { ($0.venueID != nil && $0.venueID == venueID) || $0.id == TennisVenueChoice.key(venue, location) }
    }
    private var isOther: Bool { otherSelected || (saved == nil && (!venue.isBlank || !location.isBlank)) }

    var body: some View {
        TennisChoiceList {
            TennisChoiceRow(title: "No venue", selected: !isOther && saved == nil) {
                venueID = nil; venue = ""; location = ""; otherSelected = false
                dismiss()
            }
            ForEach(choices) { choice in
                TennisChoiceRow(title: choice.summary, selected: !otherSelected && saved?.id == choice.id) {
                    venueID = choice.venueID; venue = choice.name; location = choice.location
                    otherSelected = false
                    dismiss()
                }
            }
            TennisChoiceRow(title: "Other", selected: isOther) {
                venueID = nil; otherSelected = true
                dismiss()
            }
        }.navigationTitle("Venue")
    }
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

    var body: some View {
        NavigationLink {
            TennisTournamentChoices(tournaments: tournaments, tournamentID: $tournamentID, customName: $customName)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tournament")
                Text(value).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityLabel("Tournament")
        .accessibilityValue(value)
        .accessibilityIdentifier("activityTournamentPicker")
        if customName != nil {
            TextField("Other tournament name", text: Binding(get: { customName ?? "" }, set: { customName = $0 }))
                .accessibilityIdentifier("otherTournamentName")
        }
    }
}

private struct TennisTournamentChoices: View {
    @Environment(\.dismiss) private var dismiss
    let tournaments: [TournamentRecord]
    @Binding var tournamentID: UUID?
    @Binding var customName: String?

    var body: some View {
        TennisChoiceList {
            TennisChoiceRow(title: "No tournament", selected: tournamentID == nil && customName == nil) {
                tournamentID = nil; customName = nil
                dismiss()
            }
            ForEach(tournaments) { tournament in
                TennisChoiceRow(title: tournament.name.fallback("Unnamed tournament"), selected: tournamentID == tournament.id) {
                    customName = nil; tournamentID = tournament.id
                    dismiss()
                }
            }
            TennisChoiceRow(title: "Other", selected: customName != nil) {
                tournamentID = nil; customName = customName ?? ""
                dismiss()
            }
        }.navigationTitle("Tournament")
    }
}
