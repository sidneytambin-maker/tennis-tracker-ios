import SwiftUI
import UIKit
import WatchConnectivity

struct SettingsView: View {
    @EnvironmentObject private var store: TennisStore
    @EnvironmentObject private var router: AppRouter
    @State private var settings = AppSettings()
    @State private var savedMessage = ""
    @State private var editingDefaults: PlayerProfile?
    @State private var loaded = false
    @ObservedObject private var watchSync = IPhoneWatchSyncService.shared

    var body: some View {
        NavigationStack(path: $router.settingsPath) {
            Form {
                Section {
                    NavigationLink("Players", value: TennisSettingsDestination.players)
                    NavigationLink("Tennis Setup", value: TennisSettingsDestination.setup)
                        .accessibilityIdentifier("tennisSetupLink")
                    if let player = store.selectedPlayer {
                        Button("Player Defaults") { editingDefaults = player }
                    }
                }
                Section {
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

                Section("Tracking & Health") {
                    Picker("Mode", selection: $settings.trackingMode) {
                        ForEach(TrackingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .accessibilityIdentifier("settingsTrackingModePicker")
                    Text(settings.trackingMode.description)
                    if let health = watchSync.healthStatus {
                        SummaryRow(title: "Watch Health access", value: health.access)
                        SummaryRow(title: "Track Training as Workout on Watch", value: health.enabledByDefault ? "On" : "Off")
                        SummaryRow(title: "Health status reported", value: health.reportedAt.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        Text("Watch Health access has not been reported yet.")
                    }
                    Text("Health permissions and workout selection are managed on Apple Watch when starting training.")
                }

                Section("Appearance & Accessibility") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("settingsThemePicker")
                }

                Section("Defaults") {
                    Picker("Default match type", selection: $settings.defaultMatchType) {
                        ForEach(MatchKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .accessibilityIdentifier("settingsDefaultMatchTypePicker")
                    NumberChoicePicker(title: "Season", value: $settings.defaultSeason, range: 2000...2100)
                        .accessibilityIdentifier("settingsSeasonPicker")
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
                    OrderedChoicePicker(title: "Reminder lead time", selection: $settings.reminderLeadMinutes, values: [15, 30, 60, 120, 1440]) { $0.durationText }
                    OrderedChoicePicker(title: "Reflection delay", selection: $settings.postSessionDelayMinutes, values: [60, 120, 240]) { $0.durationText }
                    Button("Allow iPhone notifications") {
                        Task {
                            let granted = await TennisNotificationService.shared.requestAuthorization()
                            saveSettings(announce: false)
                            savedMessage = granted ? "Notifications are allowed." : "Notifications were not allowed."
                            UIAccessibility.post(notification: .announcement, argument: savedMessage)
                        }
                    }
                }

                Section("Calendar") {
                    Toggle("Calendar integration", isOn: $settings.calendarIntegrationEnabled)
                    Button("Allow Apple Calendar") {
                        Task {
                            let granted = await TennisCalendarService.shared.requestAccess()
                            settings.calendarIntegrationEnabled = granted
                            saveSettings(announce: false)
                            savedMessage = granted ? "Apple Calendar is connected." : "Apple Calendar was not allowed."
                            UIAccessibility.post(notification: .announcement, argument: savedMessage)
                        }
                    }
                }

                Section("Apple Watch") {
                    WatchStatusView()
                    SummaryRow(title: "Last successful sync", value: watchSync.lastSuccessfulSync?.formatted(date: .abbreviated, time: .shortened) ?? "Not yet confirmed")
                    Button("Refresh Apple Watch Sync") {
                        watchSync.sendSnapshot(store.data)
                        savedMessage = watchSync.syncMessage
                        UIAccessibility.post(notification: .announcement, argument: savedMessage)
                    }
                    .accessibilityHint("Sends the latest tennis data to the paired Apple Watch when the companion app is installed.")
                    Text("This free development build requires a separate developer installation on Apple Watch. An app icon alone does not confirm installation. Background syncing remains available when the Watch app is closed.")
                }

                Section("Dashboard") {
                    Toggle("Show needs attention", isOn: $settings.showNeedsAttention)
                        .accessibilityIdentifier("settingsNeedsAttentionToggle")
                    Toggle("Show recent activity", isOn: $settings.showRecentActivity)
                        .accessibilityIdentifier("settingsRecentActivityToggle")
                    Toggle("Show upcoming tournaments", isOn: $settings.showUpcomingTournaments)
                        .accessibilityIdentifier("settingsUpcomingTournamentsToggle")
                }

                Section("About") {
                    SummaryRow(title: "Version", value: "0.9.0")
                    SummaryRow(title: "Build", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
                }

            }
            .tennisThemedList()
            .navigationTitle("Settings")
            .navigationDestination(for: TennisSettingsDestination.self) { destination in
                switch destination {
                case .players: PlayerView()
                case .setup: TennisSetupView()
                }
            }
            .sheet(item: $editingDefaults) { PlayerEditorView(player: $0) }
            .onAppear {
                guard !loaded else { return }
                settings = store.data.settings
                loaded = true
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

    private func saveSettings(announce: Bool) {
        store.updateSettings(settings)
        if announce {
            savedMessage = "Settings saved."
            UIAccessibility.post(notification: .announcement, argument: savedMessage)
        }
    }
}

private struct WatchStatusView: View {
    @ObservedObject private var sync = IPhoneWatchSyncService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SummaryRow(title: "Apple Watch paired", value: sync.pairedDescription)
            SummaryRow(title: "Tennis Tracker installed", value: sync.installedDescription)
            SummaryRow(title: "Live connection", value: sync.liveDescription)
            SummaryRow(title: "Background sync", value: sync.backgroundDescription)
            Text(sync.syncMessage)
        }
    }
}
