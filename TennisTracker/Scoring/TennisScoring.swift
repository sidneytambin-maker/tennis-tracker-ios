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
        if isMatchComplete { return "Match complete" }
        if isTiebreak {
            return "Tiebreak \(playerPoints)-\(opponentPoints)"
        }
        if playerPoints >= 3 && opponentPoints >= 3 {
            if playerPoints == opponentPoints { return "Deuce" }
            return playerPoints > opponentPoints ? "Advantage Player" : "Advantage Opponent"
        }
        return "\(pointName(playerPoints))-\(pointName(opponentPoints))"
    }

    var spokenScore: String {
        let sets = "sets \(playerSets)-\(opponentSets)"
        let games = "games \(playerGames)-\(opponentGames)"
        return "\(pointScore), \(games), \(sets)"
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

    mutating func awardPoint(to winner: PointWinner) -> String {
        guard !state.isMatchComplete else { return "Match is already complete. \(state.spokenScore)." }
        history.append(state)
        state.lastWinner = winner
        switch winner {
        case .player:
            state.playerPoints += 1
        case .opponent:
            state.opponentPoints += 1
        }
        resolvePoint()
        let name = winner == .player ? "Player" : "Opponent"
        return "\(name) wins point. \(state.spokenScore)."
    }

    mutating func undo() -> String {
        guard let previous = history.popLast() else {
            return "Nothing to undo. \(state.spokenScore)."
        }
        state = previous
        return "Undone. \(state.spokenScore)."
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
}
