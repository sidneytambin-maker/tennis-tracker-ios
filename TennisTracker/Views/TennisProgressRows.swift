import SwiftUI

struct TennisResultDashboardRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let totals: TennisResultTotals
    let symbol: String
    var trainingMatchCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: typeSize.isAccessibilitySize ? 2 : 4), alignment: .leading, spacing: 12) {
                metric("Matches", value: totals.count)
                metric("Wins", value: totals.wins)
                metric("Losses", value: totals.losses)
                metric("Draws", value: totals.draws)
            }
            if totals.retired > 0 { Text("\(totals.retired) retired").font(.callout) }
            if trainingMatchCount > 0 { Text(trainingContext).font(.callout) }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(title)
        .accessibilityValue(totals.summary + (trainingMatchCount > 0 ? " " + trainingContext : ""))
    }

    private var trainingContext: String { "Includes \(trainingMatchCount) \(trainingMatchCount == 1 ? "match" : "matches") played during training." }

    private func metric(_ name: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value.formatted()).font(.title2.weight(.semibold)).monospacedDigit()
            Text(name).font(.caption).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TennisFocusDashboardRow: View {
    let item: TennisFocusProgress
    let maximum: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.focus).font(.headline)
            Text(item.summary).font(.callout).fixedSize(horizontal: false, vertical: true)
            ProgressView(value: Double(item.sessions), total: Double(max(1, maximum)))
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(item.focus)
        .accessibilityValue(item.summary)
    }
}
