import SwiftUI

struct TennisTrackerRootView: View {
    @EnvironmentObject private var store: TennisStore
    @StateObject private var router = AppRouter()

    var body: some View {
        Group {
            if store.needsOnboarding {
                OnboardingView()
            } else {
                TabView(selection: $router.selectedTab) {
                    DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "chart.bar")
                        }
                        .tag("dashboard")

                    PlayerView()
                        .tabItem {
                            Label("Player", systemImage: "person.crop.circle")
                        }
                        .tag("player")

                    MatchesView()
                        .tabItem {
                            Label("Matches", systemImage: "list.bullet.rectangle")
                        }
                        .tag("matches")

                    TournamentsView()
                        .tabItem {
                            Label("Tournaments", systemImage: "trophy")
                        }
                        .tag("tournaments")

                    TrainingView()
                        .tabItem {
                            Label("Training", systemImage: "figure.tennis")
                        }
                        .tag("training")

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .tag("settings")
                }
                .accessibilityIdentifier("mainTabView")
                .onOpenURL { url in
                    router.open(url)
                    store.announce("Opened \(router.selectedTab).")
                }
            }
        }
        .environmentObject(router)
        .tint(store.data.settings.theme.accentColor)
        .preferredColorScheme(store.data.settings.theme.preferredColorScheme)
    }
}

extension AppTheme {
    var accentColor: Color {
        palette.accent
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .tennis, .classic: return .light
        case .highContrast: return .dark
        default: return nil
        }
    }
}
