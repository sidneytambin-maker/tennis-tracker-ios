import SwiftUI

struct SummaryRow: View {
    let title: String
    let value: String
    var hint: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint(hint)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "plus.circle", description: Text(message))
            .accessibilityElement(children: .combine)
    }
}

extension Date {
    var shortTennisDate: String {
        formatted(date: .abbreviated, time: .omitted)
    }
}

extension Binding where Value == Int {
    func clamped(min: Int = 0, max: Int = 999) -> Binding<Double> {
        Binding<Double>(
            get: { Double(wrappedValue) },
            set: { wrappedValue = Swift.max(min, Swift.min(max, Int($0))) }
        )
    }
}
