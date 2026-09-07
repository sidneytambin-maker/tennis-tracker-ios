import SwiftUI

struct TennisTrainingFocusPicker: View {
    @Binding var focus: String

    var body: some View {
        NavigationLink {
            TennisTrainingFocusChoices(focus: $focus)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Training focus")
                Text(focus.fallback("No focus selected")).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityLabel("Training focus")
        .accessibilityValue(focus.fallback("No focus selected"))
        .accessibilityIdentifier("trainingFocusPicker")
    }
}

private struct TennisTrainingFocusChoices: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var focus: String
    @State private var customFocus = ""

    var body: some View {
        List {
            choice("No focus selected", value: "")
            ForEach(TennisTrainingFocus.allCases) { option in
                choice(option.rawValue, value: option.rawValue)
            }
            Section("Custom focus") {
                TextField("Custom training focus", text: $customFocus)
                Button("Use Custom Focus") {
                    focus = customFocus.trimmingCharacters(in: .whitespacesAndNewlines)
                    dismiss()
                }.disabled(customFocus.isBlank)
            }
        }
        .navigationTitle("Training Focus")
        .onAppear {
            if TennisTrainingFocus(rawValue: focus) == nil { customFocus = focus }
        }
    }

    private func choice(_ title: String, value: String) -> some View {
        Button {
            focus = value
            dismiss()
        } label: {
            HStack {
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer()
                if focus == value { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
        }
        .accessibilityAddTraits(focus == value ? .isSelected : [])
        .accessibilityIdentifier("trainingFocusOption." + (value.isEmpty ? "none" : value))
    }
}
