import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var editingPlayer: PlayerProfile?
    @State private var showingNewPlayer = false

    var body: some View {
        NavigationStack {
            List {
                ScreenIntro(title: "Player", summary: "Manage the current player profile, classification, tracking mode, and tennis preferences.")
                Section("Current player") {
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

                Section("All players") {
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

                Section("Add") {
                    Button("Add Player") {
                        showingNewPlayer = true
                    }
                    .accessibilityLabel("Add Player")
                    .accessibilityIdentifier("addPlayerButton")
                }
            }
            .tennisThemedList()
            .navigationTitle("Player")
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
                Section("Player category") {
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
                    .onChange(of: player.sightLevel) { _, level in
                        player.bCategory = String(level.rawValue.prefix(2))
                    }
                    .accessibilityIdentifier("editSightLevelPicker")
                    Text("Allowed bounces: \(player.sightLevel.allowedBounces)")
                    TextField("LTA number", text: $player.ltaNumber)
                    TextField("ITF number", text: $player.itfNumber)
                }
                Section("Tennis profile") {
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
                    Picker("Preferred match type", selection: preferredMatchTypeBinding) {
                        ForEach(MatchKind.allCases) { kind in Text(kind.rawValue).tag(kind.rawValue) }
                    }
                    Picker("Preferred surface", selection: preferredSurfaceBinding) {
                        ForEach(CourtSurface.allCases) { surface in Text(surface.rawValue).tag(surface.rawValue) }
                    }
                    if player.trackingMode != .basic {
                        TextField("Playing style", text: $player.playingStyle, axis: .vertical)
                        TextField("Coaching focus", text: $player.coachingFocus, axis: .vertical)
                    }
                    TextField("Notes", text: $player.profileNotes, axis: .vertical)
                }
                Section {
                    Button("Delete player", role: .destructive) {
                        confirmDelete = true
                    }
                    .accessibilityIdentifier("deletePlayerButton")
                }
            }
            .tennisThemedList()
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
                Button("Delete Player", role: .destructive) {
                    store.deletePlayer(player)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var preferredMatchTypeBinding: Binding<String> {
        Binding(
            get: { player.preferredMatchType },
            set: { player.preferredMatchType = $0 }
        )
    }

    private var preferredSurfaceBinding: Binding<String> {
        Binding(
            get: { player.preferredSurface.isBlank ? CourtSurface.notSpecified.rawValue : player.preferredSurface },
            set: { player.preferredSurface = $0 == CourtSurface.notSpecified.rawValue ? "" : $0 }
        )
    }
}
