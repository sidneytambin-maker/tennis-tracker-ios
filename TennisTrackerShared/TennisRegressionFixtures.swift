#if targetEnvironment(simulator)
import Foundation

enum TennisRegressionFixtures {
    static func venueAndDashboard() -> AppData {
        var data = AppData()
        var player = PlayerProfile(); player.name = "Alex"
        data.players = [player]; data.selectedPlayerID = player.id
        data.setup.venues = [TennisVenue(name: "Training Court", town: "Town", usedForTraining: true, usedForMatches: false)]
        data.setup.coaches = [TennisCoach(name: "Chris")]
        var training = TrainingSession(playerID: player.id)
        training.date = Date().addingTimeInterval(-7200)
        training.trainingType = .oneToOneCoaching
        training.focus = TrainingType.oneToOneCoaching.rawValue
        training.context.coachIDs = [data.setup.coaches[0].id]
        training.practiceResult = TennisPracticeResult(kind: .doubles, result: .win)
        data.trainingSessions = [training]
        var historic = training; historic.id = UUID(); historic.practiceResult = nil
        historic.date = Date().addingTimeInterval(-100 * 86400)
        historic.venue = "History Court"; historic.location = "City"
        data.trainingSessions.append(historic)
        for result in [MatchResult.win, .loss, .loss] {
            var match = MatchRecord(playerID: player.id)
            match.matchType = .doubles; match.result = result; match.trainingSessionID = training.id
            match.playerName = "Alex"; match.partnerName = "Chris"; match.opponentName = "Sam"; match.opponent2Name = "Jo"
            data.matches.append(match)
        }
        var tournament = TournamentRecord(playerID: player.id); tournament.name = "Club Open"
        data.tournaments = [tournament]
        return data
    }
}
#endif
