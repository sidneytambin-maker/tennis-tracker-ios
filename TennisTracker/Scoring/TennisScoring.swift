import Foundation

enum PointWinner: Codable, Equatable {
    case player
    case opponent
}

struct TennisScoreState: Equatable {
    var playerPoints = 0
    var opponentPoints = 0
    var playerGames = 0
    var opponentGames = 0
    var playerSets = 0
    var opponentSets = 0
    var completedSetScores: [String] = []
    var isMatchComplete = false
    var lastWinner: PointWinner?

    var isTiebreak: Bool {
        playerGames == 6 && opponentGames == 6
    }

    var pointScore: String {
        pointScore(suddenDeathDeuce: false)
    }

    func pointScore(suddenDeathDeuce: Bool) -> String {
        if isMatchComplete { return "Match complete" }
        if isTiebreak {
            return "Tiebreak \(playerPoints)-\(opponentPoints)"
        }
        if playerPoints >= 3 && opponentPoints >= 3 {
            if suddenDeathDeuce { return "Sudden-death deuce" }
            if playerPoints == opponentPoints { return "Deuce" }
            return playerPoints > opponentPoints ? "Advantage Player" : "Advantage Opponent"
        }
        return "\(pointName(playerPoints))-\(pointName(opponentPoints))"
    }

    func spokenScore(playerName: String = "Player", opponentName: String = "Opponent", suddenDeathDeuce: Bool = false) -> String {
        let sets = "sets \(playerSets)-\(opponentSets)"
        let games = "games \(playerGames)-\(opponentGames)"
        return "\(pointScore(suddenDeathDeuce: suddenDeathDeuce)), \(games), \(sets), \(playerName) against \(opponentName)"
    }

    var spokenScore: String {
        spokenScore()
    }

    private func pointName(_ points: Int) -> String {
        switch points {
        case 0: return "Love"
        case 1: return "15"
        case 2: return "30"
        default: return "40"
        }
    }
}

struct TennisScoringEngine {
    private(set) var state = TennisScoreState()
    private var history: [TennisScoreState] = []
    var playerName = "Player"
    var opponentName = "Opponent"
    var suddenDeathDeuce = false

    init(playerName: String = "Player", opponentName: String = "Opponent", suddenDeathDeuce: Bool = false) {
        self.playerName = playerName.fallback("Player")
        self.opponentName = opponentName.fallback("Opponent")
        self.suddenDeathDeuce = suddenDeathDeuce
    }

    mutating func awardPoint(to winner: PointWinner) -> String {
        guard !state.isMatchComplete else { return "Match is already complete. \(fullScore)" }
        history.append(state)
        state.lastWinner = winner
        switch winner {
        case .player:
            state.playerPoints += 1
        case .opponent:
            state.opponentPoints += 1
        }
        resolvePoint()
        let name = winner == .player ? playerName : opponentName
        return "\(scorePhrase). Point to \(name)."
    }

    mutating func undo() -> String {
        guard let previous = history.popLast() else {
            return "Nothing to undo. \(fullScore)."
        }
        state = previous
        return "Undone. \(fullScore)"
    }

    mutating func reset() {
        state = TennisScoreState()
        history.removeAll()
    }

    private mutating func resolvePoint() {
        if state.isTiebreak {
            if max(state.playerPoints, state.opponentPoints) >= 7 && abs(state.playerPoints - state.opponentPoints) >= 2 {
                finishGameAndMaybeSet()
            }
            return
        }

        if suddenDeathDeuce && state.playerPoints >= 4 && state.opponentPoints >= 3 && state.playerPoints > state.opponentPoints {
            finishGameAndMaybeSet()
            return
        }
        if suddenDeathDeuce && state.opponentPoints >= 4 && state.playerPoints >= 3 && state.opponentPoints > state.playerPoints {
            finishGameAndMaybeSet()
            return
        }
        if max(state.playerPoints, state.opponentPoints) >= 4 && abs(state.playerPoints - state.opponentPoints) >= 2 {
            finishGameAndMaybeSet()
        }
    }

    private mutating func finishGameAndMaybeSet() {
        if state.playerPoints > state.opponentPoints {
            state.playerGames += 1
        } else {
            state.opponentGames += 1
        }
        state.playerPoints = 0
        state.opponentPoints = 0
        if setIsComplete {
            finishSet()
        }
    }

    private var setIsComplete: Bool {
        if max(state.playerGames, state.opponentGames) >= 6 && abs(state.playerGames - state.opponentGames) >= 2 {
            return true
        }
        if max(state.playerGames, state.opponentGames) == 7 {
            return true
        }
        return false
    }

    private mutating func finishSet() {
        state.completedSetScores.append("\(state.playerGames)-\(state.opponentGames)")
        if state.playerGames > state.opponentGames {
            state.playerSets += 1
        } else {
            state.opponentSets += 1
        }
        state.playerGames = 0
        state.opponentGames = 0
        if state.playerSets == 2 || state.opponentSets == 2 {
            state.isMatchComplete = true
        }
    }

    var scorePhrase: String {
        state.spokenScore(playerName: playerName, opponentName: opponentName, suddenDeathDeuce: suddenDeathDeuce)
    }

    var fullScore: String {
        let leader: String
        if state.playerSets != state.opponentSets {
            leader = state.playerSets > state.opponentSets ? "\(playerName) leads \(opponentName)" : "\(opponentName) leads \(playerName)"
        } else if state.playerGames != state.opponentGames {
            leader = state.playerGames > state.opponentGames ? "\(playerName) leads \(opponentName)" : "\(opponentName) leads \(playerName)"
        } else {
            leader = "\(playerName) and \(opponentName) are level"
        }
        if state.isMatchComplete {
            let winner = state.playerSets > state.opponentSets ? playerName : opponentName
            return "Match complete. \(winner) wins. Final score, \(state.completedSetScores.joined(separator: ", ").fallback("sets \(state.playerSets)-\(state.opponentSets)"))."
        }
        return "\(leader). Current game, \(state.pointScore(suddenDeathDeuce: suddenDeathDeuce)). Games \(state.playerGames)-\(state.opponentGames). Sets \(state.playerSets)-\(state.opponentSets)."
    }
}
