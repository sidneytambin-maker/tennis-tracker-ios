import SwiftUI

struct TennisTrackerRootView: View {
    @EnvironmentObject private var store: TennisStore

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }

            PlayerView()
                .tabItem {
                    Label("Player", systemImage: "person.crop.circle")
                }

            MatchesView()
                .tabItem {
                    Label("Matches", systemImage: "list.bullet.rectangle")
                }

            TournamentsView()
                .tabItem {
                    Label("Tournaments", systemImage: "trophy")
                }

            TrainingView()
                .tabItem {
                    Label("Training", systemImage: "figure.tennis")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility5)
        .accessibilityElement(children: .contain)
        .overlay(alignment: .bottom) {
            Text(store.lastAnnouncement)
                .font(.footnote)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
                .accessibilityLabel("Status")
                .accessibilityValue(store.lastAnnouncement)
        }
    }
}
