import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var settings = AppSettings()
    @State private var savedMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tracking Mode") {
                    Picker("Mode", selection: $settings.trackingMode) {
                        ForEach(TrackingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .accessibilityIdentifier("settingsTrackingModePicker")
                    Text(settings.trackingMode.description)
                    Text("Form detail: \(settings.formDetail)")
                }

                Section("Theme") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .accessibilityIdentifier("settingsThemePicker")
                    Text(themeDescription)
                }

                Section("Defaults") {
                    Picker("Default match type", selection: $settings.defaultMatchType) {
                        ForEach(MatchKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .accessibilityIdentifier("settingsDefaultMatchTypePicker")
                    Stepper("Season \(settings.defaultSeason)", value: $settings.defaultSeason, in: 2000...2100)
                        .accessibilityIdentifier("settingsSeasonStepper")
                }

                Section("Accessibility") {
                    Toggle("Announce live scores", isOn: $settings.announceScores)
                        .accessibilityIdentifier("settingsAnnounceScoresToggle")
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                        .accessibilityIdentifier("settingsHapticsToggle")
                    Text("The app uses native controls, Dynamic Type, headings, explicit labels, status announcements, and text summaries for statistics.")
                }

                Section("Dashboard") {
                    Toggle("Show needs attention", isOn: $settings.showNeedsAttention)
                        .accessibilityIdentifier("settingsNeedsAttentionToggle")
                    Toggle("Show recent activity", isOn: $settings.showRecentActivity)
                        .accessibilityIdentifier("settingsRecentActivityToggle")
                    Toggle("Show upcoming tournaments", isOn: $settings.showUpcomingTournaments)
                        .accessibilityIdentifier("settingsUpcomingTournamentsToggle")
                }

                Section {
                    Button("Save settings") {
                        saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("settingsSaveButton")
                    if !savedMessage.isBlank {
                        Text(savedMessage)
                            .accessibilityLabel("Settings status")
                            .accessibilityValue(savedMessage)
                    }
                }

                Section("Build") {
                    SummaryRow(title: "Version", value: "0.3.0")
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
                    saveSettings()
                }
                .accessibilityIdentifier("settingsToolbarSaveButton")
            }
        }
    }

    private var themeDescription: String {
        switch settings.theme {
        case .tennis:
            return "Tennis uses a grass-court green accent with native contrast support."
        case .classic:
            return "Classic uses the standard iOS blue accent."
        case .highContrast:
            return "High Contrast uses a dark appearance and bright accent."
        case .system:
            return "System follows the iPhone appearance and accent."
        }
    }

    private func saveSettings() {
        store.updateSettings(settings)
        savedMessage = "Settings saved."
        UIAccessibility.post(notification: .announcement, argument: savedMessage)
    }
}
