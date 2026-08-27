import SwiftUI

struct AppThemePalette {
    let background: Color
    let groupedBackground: Color
    let rowBackground: Color
    let accent: Color
}

extension AppTheme {
    var palette: AppThemePalette {
        switch self {
        case .tennis:
            return AppThemePalette(
                background: Color(red: 0.94, green: 0.98, blue: 0.91),
                groupedBackground: Color(red: 0.88, green: 0.95, blue: 0.85),
                rowBackground: .white,
                accent: Color(red: 0.30, green: 0.49, blue: 0.02)
            )
        case .classic:
            return AppThemePalette(
                background: Color(red: 0.95, green: 0.97, blue: 1.0),
                groupedBackground: Color(red: 0.90, green: 0.94, blue: 0.99),
                rowBackground: .white,
                accent: .blue
            )
        case .highContrast:
            return AppThemePalette(
                background: .black,
                groupedBackground: Color(red: 0.05, green: 0.05, blue: 0.05),
                rowBackground: Color(red: 0.10, green: 0.10, blue: 0.10),
                accent: .yellow
            )
        case .system:
            return AppThemePalette(
                background: Color(.systemBackground),
                groupedBackground: Color(.systemGroupedBackground),
                rowBackground: Color(.secondarySystemGroupedBackground),
                accent: .accentColor
            )
        }
    }
}

struct ThemedListBackground: ViewModifier {
    @EnvironmentObject private var store: TennisStore

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(store.data.settings.theme.palette.background)
    }
}

extension View {
    func tennisThemedList() -> some View {
        modifier(ThemedListBackground())
    }
}

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

struct DateShortcutPicker: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        DatePicker(title, selection: $date, displayedComponents: .date)
            .datePickerStyle(.compact)
            .accessibilityHint("Double tap to edit the date. Use the quick date buttons for common changes.")
        HStack {
            Button("Yesterday") { date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date() }
            Button("Today") { date = Date() }
            Button("Tomorrow") { date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date() }
        }
        .buttonStyle(.bordered)
        .accessibilityElement(children: .contain)
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
