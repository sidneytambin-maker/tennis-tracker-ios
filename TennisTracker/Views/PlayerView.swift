import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var editingPlayer: PlayerProfile?
    @State private var showingNewPlayer = false

    var body: some View {
        NavigationStack {
            List {
                Section("Current Player") {
                    if let player = store.selectedPlayer {
                        SummaryRow(title: player.displayName, value: "\(player.sightLevel.rawValue). \(player.trackingMode.rawValue) mode.")
                        Button("Edit current player") {
                            editingPlayer = player
                        }
                        .accessibilityIdentifier("editCurrentPlayerButton")
                    } else {
                        EmptyStateView(title: "No player", message: "Add a player profile to start tracking.")
                    }
                }

                Section("All Players") {
                    ForEach(store.data.players) { player in
                        Button {
                            store.selectPlayer(player)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(player.displayName)
                                Text("\(player.bCategory), \(player.club.fallback("club not recorded"))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel(player.displayName)
                        .accessibilityValue("\(player.sightLevel.rawValue). \(player.trackingMode.rawValue) mode.")
                    }
                }
            }
            .navigationTitle("Player")
            .toolbar {
                Button("Add") {
                    showingNewPlayer = true
                }
                .accessibilityLabel("Add player")
                .accessibilityIdentifier("addPlayerButton")
            }
            .sheet(item: $editingPlayer) { player in
                PlayerEditorView(player: player)
            }
            .sheet(isPresented: $showingNewPlayer) {
                PlayerEditorView(player: PlayerProfile())
            }
        }
    }
}

struct PlayerEditorView: View {
    @EnvironmentObject private var store: TennisStore
    @Environment(\.dismiss) private var dismiss
    @State var player: PlayerProfile
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Full name", text: $player.name)
                    TextField("Preferred name", text: $player.preferredName)
                    TextField("Surname", text: $player.surname)
                    Stepper("Age \(player.age)", value: $player.age, in: 0...120)
                    TextField("Nationality", text: $player.nationality)
                }
                Section("Blind Tennis") {
                    Picker("Player type", selection: $player.playerMode) {
                        ForEach(PlayerMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .accessibilityIdentifier("editPlayerModePicker")
                    Picker("Sight level", selection: $player.sightLevel) {
                        ForEach(SightLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .accessibilityIdentifier("editSightLevelPicker")
                    Text("Allowed bounces: \(player.sightLevel.allowedBounces)")
                    TextField("B category", text: $player.bCategory)
                    TextField("LTA number", text: $player.ltaNumber)
                    TextField("ITF number", text: $player.itfNumber)
                }
                Section("Tennis Profile") {
                    Picker("Tracking mode", selection: $player.trackingMode) {
                        ForEach(TrackingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .accessibilityIdentifier("editTrackingModePicker")
                    Text(player.trackingMode.description)
                    TextField("Playing hand", text: $player.playingHand)
                    TextField("Club", text: $player.club)
                    TextField("Primary goal", text: $player.primaryGoal, axis: .vertical)
                    TextField("Preferred match type", text: $player.preferredMatchType)
                    TextField("Preferred surface", text: $player.preferredSurface)
                    TextField("Playing style", text: $player.playingStyle, axis: .vertical)
                    TextField("Coaching focus", text: $player.coachingFocus, axis: .vertical)
                    TextField("Profile notes", text: $player.profileNotes, axis: .vertical)
                }
                Section {
                    Button("Delete player", role: .destructive) {
                        confirmDelete = true
                    }
                    .accessibilityIdentifier("deletePlayerButton")
                }
            }
            .navigationTitle("Player Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelPlayerButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.upsertPlayer(player)
                        dismiss()
                    }
                    .accessibilityIdentifier("savePlayerButton")
                }
            }
            .confirmationDialog("Delete this player and their activity?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete player", role: .destructive) {
                    store.deletePlayer(player)
                    dismiss()
                }
            }
        }
    }
}
