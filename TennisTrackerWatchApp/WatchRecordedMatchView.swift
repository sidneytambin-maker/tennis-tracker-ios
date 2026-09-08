import SwiftUI

struct WatchRecordedMatchView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @Environment(\.dismiss) private var dismiss
    @State private var match = MatchRecord(playerID: UUID())
    @State private var configured = false
    @State private var validationMessage = ""

    var body: some View {
        Form {
            if !validationMessage.isBlank { Text(validationMessage).accessibilityIdentifier("recordMatchValidation") }
            Picker("Singles or doubles", selection: $match.matchType) {
                ForEach(MatchKind.allCases) { Text($0.rawValue).tag($0) }
            }
            TennisPersonPicker(title: "Opponent", players: store.snapshot.players.filter { $0.id != match.playerID && $0.id != match.partnerID && $0.id != match.opponent2ID }, selection: $match.opponentID, name: $match.opponentName)
            if match.matchType == .doubles {
                TennisPersonPicker(title: "Partner", players: store.snapshot.players.filter { $0.id != match.playerID && $0.id != match.opponentID && $0.id != match.opponent2ID }, selection: $match.partnerID, name: $match.partnerName, regularPartnersFirst: true)
                TennisPersonPicker(title: "Second opponent", players: store.snapshot.players.filter { $0.id != match.playerID && $0.id != match.opponentID && $0.id != match.partnerID }, selection: $match.opponent2ID, name: $match.opponent2Name)
            }
            WatchDateField(title: "Match date", date: $match.date)
            WatchVenueFields(venueID: $match.venueID, venue: $match.venue, location: $match.location)
            TennisTournamentPicker(tournaments: store.snapshot.tournaments, tournamentID: $match.tournamentID, customName: $match.customTournamentName)
            OrderedChoicePicker(title: "Match format", selection: $match.matchFormat, values: MatchFormat.allCases) { $0.label }
            Picker("Result", selection: $match.result) {
                ForEach(MatchResult.allCases) { Text($0.rawValue).tag($0) }
            }.accessibilityIdentifier("recordedMatchResult")
            OrderedChoicePicker(title: "Your sets won", selection: $match.yourSetsWon, values: Array(0...TennisManualMatchEntry.maximumTeamSets(for: match.matchFormat))) { String($0) }
            OrderedChoicePicker(title: "Opponent sets won", selection: $match.opponentSetsWon, values: Array(0...TennisManualMatchEntry.maximumTeamSets(for: match.matchFormat))) { String($0) }
            TextField("Set scores, optional", text: $match.setScores)
            Section("Conditions") { TennisMatchConditionsFields(match: $match) }
            TextField("Notes", text: $match.notes)
            Button("Save Match Result") {
                if let error = TennisManualMatchEntry.validationMessage(for: match) {
                    validationMessage = error
                    store.announce(error)
                } else {
                    store.saveRecordedMatch(match)
                    dismiss()
                }
            }.disabled(!configured).accessibilityIdentifier("saveRecordedMatch")
        }
        .pickerStyle(.navigationLink)
        .navigationTitle("Record Match Result")
        .onAppear {
            guard !configured, let player = store.selectedPlayer else { return }
            match.playerID = player.id
            match.playerName = player.displayName
            match.matchFormat = player.defaultMatchFormat
            match.sightLevel = player.sightLevel
            match.allowedBounces = player.bounceAllowance ?? player.sightLevel.allowedBounces
            match.suddenDeathDeuce = player.playerMode == .blindTennis
            match.date = Calendar.current.startOfDay(for: Date())
            configured = true
        }
        .onChange(of: match.matchFormat) { _, format in
            match.yourSetsWon = min(match.yourSetsWon, TennisManualMatchEntry.maximumTeamSets(for: format))
            match.opponentSetsWon = min(match.opponentSetsWon, TennisManualMatchEntry.maximumTeamSets(for: format))
        }
    }
}

struct WatchTournamentManagementView: View {
    @EnvironmentObject private var store: WatchTennisStore
    @State private var newTournament: TournamentRecord?

    var body: some View {
        List {
            Button("Add Tournament") {
                if let player = store.selectedPlayer {
                    var tournament = TournamentRecord(playerID: player.id)
                    tournament.category = player.bCategory
                    newTournament = tournament
                }
            }.disabled(store.selectedPlayer == nil)
            ForEach(store.snapshot.tournaments.sorted { $0.date > $1.date }) { WatchTournamentRow(tournament: $0) }
            NavigationLink("Start Tournament Timing") { WatchTournamentSetupView() }
        }
        .navigationTitle("Tournaments")
        .sheet(item: $newTournament) { draft in
            NavigationStack { WatchTournamentEditor(draft: draft, isNew: true) }
        }
    }
}
