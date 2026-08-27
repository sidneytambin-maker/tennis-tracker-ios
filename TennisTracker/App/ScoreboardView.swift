import SwiftUI
import UIKit

struct ScoreboardView: View {
    @State private var score = TestScore()
    @State private var statusMessage = "Ready. Current test score, Player One Love, Player Two Love."
    @AccessibilityFocusState private var focusedElement: FocusedElement?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Development build")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($focusedElement, equals: .heading)

                Text(score.spokenScore)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(3)
                    .accessibilityLabel("Current test score")
                    .accessibilityValue(score.accessibilityValue)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityFocused($focusedElement, equals: .score)

                VStack(spacing: 16) {
                    Button("Player One wins point") {
                        recordPoint(for: .playerOne)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel("Player One wins point")
                    .accessibilityHint("Adds one test point for Player One and announces the updated score.")

                    Button("Player Two wins point") {
                        recordPoint(for: .playerTwo)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel("Player Two wins point")
                    .accessibilityHint("Adds one test point for Player Two and announces the updated score.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(statusMessage)
                    .font(.body)
                    .accessibilityLabel("Status")
                    .accessibilityValue(statusMessage)

                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Tennis Tracker")
            .dynamicTypeSize(...DynamicTypeSize.accessibility5)
            .onAppear {
                focusedElement = .heading
            }
        }
    }

    private func recordPoint(for player: Player) {
        let announcement: String
        switch player {
        case .playerOne:
            announcement = score.playerOneWinsPoint()
        case .playerTwo:
            announcement = score.playerTwoWinsPoint()
        }

        statusMessage = announcement
        focusedElement = .score
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

private enum Player {
    case playerOne
    case playerTwo
}

private enum FocusedElement: Hashable {
    case heading
    case score
}
