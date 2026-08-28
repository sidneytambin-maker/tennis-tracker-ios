import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var settings = AppSettings()
    @State private var savedMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                ScreenIntro(title: "Settings", summary: "Choose tracking detail, theme, scoring announcements, reminders, Calendar, and dashboard preferences.")
                Section("Save") {
                    Button("Save Settings") {
                        saveSettings(announce: true)
                    }
                    .accessibilityLabel("Save Settings")
                    .accessibilityIdentifier("settingsToolbarSaveButton")
                }
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

                Section("Reminders") {
                    Toggle("Match reminders", isOn: $settings.matchRemindersEnabled)
                    Toggle("Match result follow-ups", isOn: $settings.matchResultRemindersEnabled)
                    Toggle("Training reminders", isOn: $settings.trainingRemindersEnabled)
                    Toggle("Tournament reminders", isOn: $settings.tournamentRemindersEnabled)
                    Toggle("Post-session reflection", isOn: $settings.postSessionRemindersEnabled)
                    Toggle("Weekly summary", isOn: $settings.weeklySummaryEnabled)
                    Picker("Reminder lead time", selection: $settings.reminderLeadMinutes) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                        Text("1 day").tag(1440)
                    }
                    Picker("Reflection delay", selection: $settings.postSessionDelayMinutes) {
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                        Text("4 hours").tag(240)
                    }
                    Button("Allow iPhone notifications") {
                        Task {
                            let granted = await TennisNotificationService.shared.requestAuthorization()
                            savedMessage = granted ? "Notifications are allowed." : "Notifications were not allowed."
                            saveSettings(announce: true)
                        }
                    }
                }

                Section("Calendar") {
                    Toggle("Calendar integration", isOn: $settings.calendarIntegrationEnabled)
                    Button("Allow Apple Calendar") {
                        Task {
                            let granted = await TennisCalendarService.shared.requestAccess()
                            settings.calendarIntegrationEnabled = granted
                            savedMessage = granted ? "Apple Calendar is connected." : "Apple Calendar was not allowed."
                            saveSettings(announce: true)
                        }
                    }
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
                    SummaryRow(title: "Version", value: "0.7.0")
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
        }
    }

    private var themeDescription: String {
        switch settings.theme {
        case .tennis:
            return "Tennis uses bright ball accents, deep court green, and high-contrast surfaces."
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
