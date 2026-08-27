import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var settings = AppSettings()

    var body: some View {
        NavigationStack {
            Form {
                Section("Tracking Mode") {
                    Picker("Mode", selection: $settings.trackingMode) {
                        ForEach(TrackingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    Text(settings.trackingMode.description)
                    Text("Form detail: \(settings.formDetail)")
                }

                Section("Accessibility") {
                    Toggle("Announce live scores", isOn: $settings.announceScores)
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                    Text("The app uses native controls, Dynamic Type, headings, explicit labels, status announcements, and text summaries for statistics.")
                }

                Section("Dashboard") {
                    Toggle("Show needs attention", isOn: $settings.showNeedsAttention)
                    Toggle("Show recent activity", isOn: $settings.showRecentActivity)
                    Toggle("Show upcoming tournaments", isOn: $settings.showUpcomingTournaments)
                }

                Section("Build") {
                    SummaryRow(title: "Version", value: "0.2.0")
                    SummaryRow(title: "Build route", value: "GitHub Actions builds the unsigned app. Sideloadly signs and installs it with the free Apple account.")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                settings = store.data.settings
            }
            .onChange(of: settings.trackingMode) { _, _ in
                settings.applyModeDefaults()
            }
            .toolbar {
                Button("Save") {
                    store.updateSettings(settings)
                }
            }
        }
    }
}
