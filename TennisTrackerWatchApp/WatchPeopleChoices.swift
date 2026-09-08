import SwiftUI

struct WatchCoachChoices: View {
    let coaches: [TennisCoach]
    @Binding var selectedIDs: [UUID]
    @Binding var otherSelected: Bool
    var allowsOther = true

    var body: some View {
        TennisChoiceList {
            ForEach(coaches) { coach in
                TennisSelectionRow(name: coach.name, id: coach.id, selectedIDs: $selectedIDs)
            }
            if allowsOther { Toggle("Other: complete on iPhone", isOn: $otherSelected) }
        }.navigationTitle("Coaches")
    }
}

struct WatchPlayerChoices: View {
    let players: [PlayerProfile]
    @Binding var selectedIDs: [UUID]
    @Binding var otherSelected: Bool
    var allowsOther = true

    var body: some View {
        TennisChoiceList {
            ForEach(players) { player in
                TennisSelectionRow(name: player.displayName, id: player.id, selectedIDs: $selectedIDs)
            }
            if allowsOther { Toggle("Other", isOn: $otherSelected) }
        }.navigationTitle("Players Present")
    }
}
