import SwiftUI

struct TennisCoachPicker: View {
    let coaches: [TennisCoach]
    @Binding var context: TennisActivityContext

    var body: some View {
        NavigationLink("Coaches") {
            TennisCoachChoices(coaches: coaches, context: $context)
        }
        .accessibilityIdentifier("trainingCoachPicker")
        .accessibilityValue(context.coachSummary(in: coaches).fallback(context.otherCoachName == nil ? "None" : "Other"))
        .accessibilityHint("Choose saved coaches or a one-off coach.")
    }
}

private struct TennisCoachChoices: View {
    let coaches: [TennisCoach]
    @Binding var context: TennisActivityContext

    private var selectedIDs: Binding<[UUID]> {
        Binding(get: { context.coachIDs }, set: {
            context.coachIDs = $0
            context.coachName = ""
            context.coachesNeedDetails = context.needsOtherCoachName
        })
    }

    private var otherSelected: Binding<Bool> {
        Binding(get: { context.otherCoachName != nil }, set: { selected in
            context.otherCoachName = selected ? "" : nil
            context.coachesNeedDetails = selected
            if context.coachIDs.isEmpty { context.coachName = "" }
        })
    }

    var body: some View {
        TennisChoiceList {
            Button("None") { context.clearCoaches() }
                .accessibilityIdentifier("noCoaches")
                .accessibilityAddTraits(context.coachIDs.isEmpty && context.otherCoachName == nil && context.coachName.isBlank ? .isSelected : [])
            ForEach(coaches) { coach in
                TennisSelectionRow(name: coach.name, id: coach.id, selectedIDs: selectedIDs)
            }
            if coaches.isEmpty { Text("No saved coaches").foregroundStyle(.primary) }
            Toggle("Other", isOn: otherSelected)
                .accessibilityIdentifier("otherCoachToggle")
            if context.otherCoachName != nil {
                TextField("Other coach name", text: Binding(
                    get: { context.otherCoachName ?? "" },
                    set: { context.otherCoachName = $0; context.coachesNeedDetails = $0.isBlank }
                ))
                .accessibilityIdentifier("otherCoachName")
            } else if context.coachIDs.isEmpty && !context.coachName.isBlank {
                Button("Use recorded coach: \(context.coachName)") {
                    context.otherCoachName = context.coachName
                    context.coachesNeedDetails = false
                }
            }
        }
        .navigationTitle("Coaches")
    }
}
