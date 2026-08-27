import Foundation

struct TestScore: Equatable {
    private(set) var playerOnePoints = 0
    private(set) var playerTwoPoints = 0

    var spokenScore: String {
        if playerOnePoints >= 3 && playerTwoPoints >= 3 {
            if playerOnePoints == playerTwoPoints {
                return "Deuce"
            }

            return playerOnePoints > playerTwoPoints ? "Advantage Player One" : "Advantage Player Two"
        }

        return "Player One \(pointName(for: playerOnePoints)), Player Two \(pointName(for: playerTwoPoints))"
    }

    var accessibilityValue: String {
        spokenScore
    }

    mutating func playerOneWinsPoint() -> String {
        playerOnePoints += 1
        return announcement(winner: "Player One")
    }

    mutating func playerTwoWinsPoint() -> String {
        playerTwoPoints += 1
        return announcement(winner: "Player Two")
    }

    private func announcement(winner: String) -> String {
        if hasGameWinner {
            return "\(winner) wins the game. Reset the proof-of-concept score to start another game."
        }

        return "\(winner) wins point. Current test score, \(spokenScore)."
    }

    private var hasGameWinner: Bool {
        abs(playerOnePoints - playerTwoPoints) >= 2 && max(playerOnePoints, playerTwoPoints) >= 4
    }

    private func pointName(for points: Int) -> String {
        switch points {
        case 0:
            return "Love"
        case 1:
            return "15"
        case 2:
            return "30"
        default:
            return "40"
        }
    }
}

