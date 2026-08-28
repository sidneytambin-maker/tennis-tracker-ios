import SwiftUI

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchTodayView()
            WatchTrackView()
        }
        .tabViewStyle(.page)
    }
}

struct WatchTodayView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Today")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Tennis Tracker is ready on Apple Watch.")
                    .font(.body)
                Text("Use Track to record quick tennis activity.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today. Tennis Tracker is ready on Apple Watch. Use Track to record quick tennis activity.")
    }
}

struct WatchTrackView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Track Tennis Activity")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Button("Track Training Session") {}
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Creates a quick training session on Apple Watch after synchronisation is enabled.")

                Button("Record Match") {}
                    .buttonStyle(.bordered)
                    .accessibilityHint("Creates a quick match on Apple Watch after synchronisation is enabled.")

                Button("Track Tournament") {}
                    .buttonStyle(.bordered)
                    .accessibilityHint("Tracks tournament activity on Apple Watch after synchronisation is enabled.")
            }
            .padding()
        }
    }
}
