import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var settings = AppSettings()
    @State private var savedMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                if !savedMessage.isBlank {
                    Section("Status") {
                        Text(savedMessage)
                    }
                }

                Section("Tracking") {
                    Picker("Mode", selection: $settings.trackingMode) {
                        ForEach(TrackingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .accessibilityIdentifier("settingsTrackingModePicker")
                    Text(settings.trackingMode.description)
                }

                Section("Theme") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.inline)
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

                Section("Live scoring") {
                    Picker("Score announcements", selection: $settings.scoreAnnouncementMode) {
                        ForEach(ScoreAnnouncementMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .accessibilityIdentifier("settingsScoreAnnouncementPicker")
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                        .accessibilityIdentifier("settingsHapticsToggle")
                    Text("Automatic speaks the new score after each point. Reduced speaks the point winner and current game score. Off keeps the Hear full score button available.")
                }

                Section("Dashboard") {
                    Toggle("Show needs attention", isOn: $settings.showNeedsAttention)
                        .accessibilityIdentifier("settingsNeedsAttentionToggle")
                    Toggle("Show recent activity", isOn: $settings.showRecentActivity)
                        .accessibilityIdentifier("settingsRecentActivityToggle")
                    Toggle("Show upcoming tournaments", isOn: $settings.showUpcomingTournaments)
                        .accessibilityIdentifier("settingsUpcomingTournamentsToggle")
                }

                Section("Build") {
                    SummaryRow(title: "Version", value: "0.4.0")
                    SummaryRow(title: "Build route", value: "GitHub Actions builds the unsigned app. Sideloadly signs and installs it with the free Apple account.")
                }
            }
            .tennisThemedList()
            .navigationTitle("Settings")
            .onAppear {
                settings = store.data.settings
            }
            .onChange(of: settings.trackingMode) { _, _ in
                settings.applyModeDefaults()
                saveSettings(announce: false)
            }
            .onChange(of: settings.theme) { _, _ in
                saveSettings(announce: false)
            }
            .toolbar {
                Button("Save") {
                    saveSettings(announce: true)
                }
                .accessibilityLabel("Save settings")
                .accessibilityIdentifier("settingsToolbarSaveButton")
            }
        }
    }

    private var themeDescription: String {
        switch settings.theme {
        case .tennis:
            return "Tennis uses light court surfaces with a restrained tennis-ball accent."
        case .classic:
            return "Classic uses a clean blue iOS style."
        case .highContrast:
            return "High Contrast uses dark surfaces and bright controls."
        case .system:
            return "System follows the iPhone appearance."
        }
    }

    private func saveSettings(announce: Bool) {
        store.updateSettings(settings)
        if announce {
            savedMessage = "Settings saved."
            UIAccessibility.post(notification: .announcement, argument: savedMessage)
        }
    }
}
