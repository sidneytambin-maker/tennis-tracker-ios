import SwiftUI

struct AppThemePalette {
    let background: Color
    let groupedBackground: Color
    let rowBackground: Color
    let accent: Color
    let strongSurface: Color
}

extension AppTheme {
    var palette: AppThemePalette {
        switch self {
        case .tennis:
            return AppThemePalette(
                background: Color(red: 0.90, green: 0.97, blue: 0.82),
                groupedBackground: Color(red: 0.10, green: 0.31, blue: 0.20),
                rowBackground: Color(red: 0.98, green: 1.0, blue: 0.92),
                accent: Color(red: 0.62, green: 0.83, blue: 0.08),
                strongSurface: Color(red: 0.04, green: 0.16, blue: 0.12)
            )
        case .classic:
            return AppThemePalette(
                background: Color(red: 0.95, green: 0.97, blue: 1.0),
                groupedBackground: Color(red: 0.90, green: 0.94, blue: 0.99),
                rowBackground: .white,
                accent: .blue,
                strongSurface: .blue
            )
        case .highContrast:
            return AppThemePalette(
                background: .black,
                groupedBackground: Color(red: 0.05, green: 0.05, blue: 0.05),
                rowBackground: Color(red: 0.10, green: 0.10, blue: 0.10),
                accent: .yellow,
                strongSurface: .black
            )
        case .system:
            return AppThemePalette(
                background: Color(.systemBackground),
                groupedBackground: Color(.systemGroupedBackground),
                rowBackground: Color(.secondarySystemGroupedBackground),
                accent: .accentColor,
                strongSurface: Color(.secondarySystemBackground)
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

struct ScreenIntro: View {
    let title: String
    let summary: String

    var body: some View {
        Section {
            SummaryRow(title: title, value: summary)
        }
    }
}

struct AccessibleDateTimeEditor: View {
    let dateTitle: String
    let timeTitle: String
    @Binding var date: Date
    @Binding var hasStartTime: Bool
    var allowsUnspecifiedTime = true

    var body: some View {
        DatePicker(dateTitle, selection: $date, displayedComponents: .date)
            .datePickerStyle(.compact)
            .accessibilityValue(date.fullTennisDate)
            .accessibilityHint("Opens the native date picker.")

        HStack {
            Button("Today") { date = Calendar.current.dateByKeepingTime(from: date, on: Date()) }
            Button("Tomorrow") {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                date = Calendar.current.dateByKeepingTime(from: date, on: tomorrow)
            }
        }
        .buttonStyle(.bordered)

        if allowsUnspecifiedTime {
            Toggle("Start time specified", isOn: $hasStartTime)
        }

        if hasStartTime {
            FiveMinuteTimePicker(title: timeTitle, date: $date)
                .accessibilityValue(date.shortTennisTime)
                .accessibilityHint("Adjust the hour and minutes. Minutes move in five minute steps.")
        } else {
            Text("Start time not specified.")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Start time")
                .accessibilityValue("Not specified")
        }
    }
}

struct AccessibleDateRangeEditor: View {
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {
        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
            .datePickerStyle(.compact)
            .accessibilityLabel("Tournament start date")
            .accessibilityValue(startDate.fullTennisDate)
            .accessibilityHint("Opens the native date picker.")
            .onChange(of: startDate) { _, newStart in
                if endDate < newStart {
                    endDate = newStart
                }
            }

        DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
            .datePickerStyle(.compact)
            .accessibilityLabel("Tournament end date")
            .accessibilityValue(endDate.fullTennisDate)
            .accessibilityHint("Opens the native date picker. The end date cannot be before the start date.")
    }
}

struct FiveMinuteTimePicker: View {
    let title: String
    @Binding var date: Date

    private let hours = Array(0...23)
    private let minutes = Array(stride(from: 0, through: 55, by: 5))

    var body: some View {
        LabeledContent(title) {
            HStack {
                Picker("Hour", selection: hourBinding) {
                    ForEach(hours, id: \.self) { hour in
                        Text(String(format: "%02d", hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: 100)
                .clipped()

                Picker("Minutes", selection: minuteBinding) {
                    ForEach(minutes, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: 100)
                .clipped()
            }
        }
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: date) },
            set: { update(hour: $0, minute: Calendar.current.component(.minute, from: date)) }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { closestFiveMinuteValue(Calendar.current.component(.minute, from: date)) },
            set: { update(hour: Calendar.current.component(.hour, from: date), minute: $0) }
        )
    }

    private func update(hour: Int, minute: Int) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = closestFiveMinuteValue(minute)
        components.second = 0
        date = Calendar.current.date(from: components) ?? date
    }

    private func closestFiveMinuteValue(_ value: Int) -> Int {
        minutes.min(by: { abs($0 - value) < abs($1 - value) }) ?? 0
    }
}

struct DurationPicker: View {
    let title: String
    @Binding var minutes: Int
    var minimumMinutes = 5

    var body: some View {
        Section(title) {
            DurationFields(minutes: $minutes, minimumMinutes: minimumMinutes)
        }
    }
}

struct DurationFields: View {
    @Binding var minutes: Int
    var minimumMinutes = 5

    private let minuteChoices = Array(stride(from: 0, through: 55, by: 5))

    var body: some View {
        Picker("Hours", selection: hoursBinding) {
            ForEach(0...8, id: \.self) { hour in
                Text(hour == 1 ? "1 hour" : "\(hour) hours").tag(hour)
            }
        }
        .accessibilityValue("\(hoursBinding.wrappedValue)")

        Picker("Minutes", selection: minutesBinding) {
            ForEach(minuteChoices, id: \.self) { value in
                Text(value == 1 ? "1 minute" : "\(value) minutes").tag(value)
            }
        }
        .accessibilityValue("\(minutesBinding.wrappedValue)")

        HStack {
            Button("1 hour") { minutes = 60 }
            Button("90 minutes") { minutes = 90 }
            Button("2 hours") { minutes = 120 }
        }
        .buttonStyle(.bordered)

        SummaryRow(title: "Duration", value: minutes.durationText)
    }

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { minutes / 60 },
            set: { minutes = max(minimumMinutes, ($0 * 60) + (minutes % 60)) }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { closestMinuteChoice(minutes % 60) },
            set: { minutes = max(minimumMinutes, ((minutes / 60) * 60) + $0) }
        )
    }

    private func closestMinuteChoice(_ value: Int) -> Int {
        minuteChoices.min(by: { abs($0 - value) < abs($1 - value) }) ?? 0
    }
}

struct NumberChoicePicker: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var suffix: String = ""

    var body: some View {
        Picker(title, selection: $value) {
            ForEach(Array(range), id: \.self) { number in
                Text(label(for: number)).tag(number)
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(label(for: value))
        .accessibilityHint("Double tap to choose a value.")
    }

    private func label(for number: Int) -> String {
        if suffix.isBlank { return "\(number)" }
        if number == 1, suffix.hasSuffix("s") {
            return "\(number) \(suffix.dropLast())"
        }
        return "\(number) \(suffix)"
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

extension Binding where Value == Int {
    func clamped(min: Int = 0, max: Int = 999) -> Binding<Double> {
        Binding<Double>(
            get: { Double(wrappedValue) },
            set: { wrappedValue = Swift.max(min, Swift.min(max, Int($0))) }
        )
    }
}
