import SwiftUI

enum TennisOrderedSelection {
    static func moved<Value: Equatable>(_ value: Value, in values: [Value], forward: Bool) -> Value {
        guard let index = values.firstIndex(of: value), !values.isEmpty else { return value }
        return values[min(values.count - 1, max(0, index + (forward ? 1 : -1)))]
    }
}

struct OrderedChoicePicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let values: [Value]
    let label: (Value) -> String

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(values, id: \.self) { value in Text(label(value)).tag(value) }
        }
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: selection = TennisOrderedSelection.moved(selection, in: values, forward: true)
            case .decrement: selection = TennisOrderedSelection.moved(selection, in: values, forward: false)
            @unknown default: break
            }
        }
    }
}

struct TennisSelectionRow: View {
    let name: String
    let id: UUID
    @Binding var selectedIDs: [UUID]

    var body: some View {
        Toggle(name, isOn: Binding(
            get: { selectedIDs.contains(id) },
            set: { selected in
                selectedIDs.removeAll { $0 == id }
                if selected { selectedIDs.append(id) }
            }
        ))
        .accessibilityValue(selectedIDs.contains(id) ? "Selected" : "Not selected")
    }
}
