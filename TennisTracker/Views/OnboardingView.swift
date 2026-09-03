import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var store: TennisStore
    @State private var step = 0
    @State private var player = PlayerProfile()
    @State private var settings = AppSettings()
    @State private var validationMessage = ""
    @AccessibilityFocusState private var focusedHeading: Bool
    @AccessibilityFocusState private var focusedValidation: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focusedHeading)
                    Text(subtitle)
                }

                switch step {
                case 0:
                    welcomeStep
                case 1:
                    identityStep
                case 2:
                    tennisStep
                default:
                    preferencesStep
                }

                if !validationMessage.isBlank {
                    Section {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Validation message")
                            .accessibilityValue(validationMessage)
                            .accessibilityFocused($focusedValidation)
                    }
                }

                Section {
                    HStack {
                        if step > 0 {
                            Button("Back") {
                                validationMessage = ""
                                step -= 1
                                focusHeading()
                            }
                            .accessibilityIdentifier("onboardingBackButton")
                        }
                        Spacer()
                        Button(step == 3 ? "Finish setup" : "Continue") {
                            continueTapped()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(step == 3 ? "onboardingFinishButton" : "onboardingContinueButton")
                    }
                }
            }
            .navigationTitle("Setup")
            .onAppear {
                player.playerMode = .blindTennis
                player.sightLevel = .b1
                player.trackingMode = .basic
                settings.theme = .tennis
                settings.trackingMode = .basic
                settings.defaultMatchType = .singles
                focusHeading()
            }
        }
        .tint(settings.theme.accentColor)
    }

    private var welcomeStep: some View {
        Section("Welcome") {
            Text("Tennis Tracker records matches, tournaments, training, and progress. Setup creates your first real player profile. No demo records will be added.")
            Button("Set up my player profile") {
                step = 1
                focusHeading()
            }
            .accessibilityIdentifier("setupProfileButton")
        }
    }

    private var identityStep: some View {
        Section("Player") {
            TextField("Player name", text: $player.name)
                .textContentType(.name)
                .accessibilityIdentifier("playerNameField")
            TextField("Preferred name", text: $player.preferredName)
                .textContentType(.nickname)
                .accessibilityIdentifier("preferredNameField")
            TextField("Club", text: $player.club)
                .accessibilityIdentifier("clubField")
        }
    }

    private var tennisStep: some View {
        Section("Tennis Type") {
            Picker("Player type", selection: $player.playerMode) {
                ForEach(PlayerMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .accessibilityIdentifier("playerModePicker")

            if player.playerMode == .blindTennis {
                Picker("Sight level", selection: $player.sightLevel) {
                    ForEach(SightLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .accessibilityIdentifier("sightLevelPicker")
                Text("Allowed bounces: \(player.sightLevel.allowedBounces)")
                    .accessibilityLabel("Allowed bounces")
                    .accessibilityValue("\(player.sightLevel.allowedBounces)")
            }

            Picker("Preferred match type", selection: $settings.defaultMatchType) {
                ForEach(MatchKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .accessibilityIdentifier("defaultMatchTypePicker")
        }
    }

    private var preferencesStep: some View {
        Section("Preferences") {
            Picker("Tracking mode", selection: $settings.trackingMode) {
                ForEach(TrackingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .accessibilityIdentifier("trackingModePicker")
            Text(settings.trackingMode.description)

            NumberChoicePicker(title: "Season", value: $settings.defaultSeason, range: 2000...2100)
                .accessibilityIdentifier("seasonPicker")

            Picker("Theme", selection: $settings.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .accessibilityIdentifier("themePicker")

            Picker("Score announcements", selection: $settings.scoreAnnouncementMode) {
                ForEach(ScoreAnnouncementMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .accessibilityIdentifier("announceScoresPicker")
            Toggle("Haptics", isOn: $settings.hapticsEnabled)
                .accessibilityIdentifier("hapticsToggle")
        }
    }

    private var title: String {
        switch step {
        case 0: return "Welcome to Tennis Tracker"
        case 1: return "Set Up Your Player"
        case 2: return "Choose Tennis Details"
        default: return "Choose Preferences"
        }
    }

    private var subtitle: String {
        switch step {
        case 0: return "A fresh, private tracker for your iPhone."
        case 1: return "Only the player name is required."
        case 2: return "These choices set sensible defaults for matches and scoring."
        default: return "You can change these later in Settings."
        }
    }

    private func continueTapped() {
        validationMessage = ""
        if step == 0 {
            step = 1
            focusHeading()
            return
        }
        if step == 1 && player.name.isBlank && player.preferredName.isBlank {
            validationMessage = "Enter a player name or preferred name before continuing."
            focusedValidation = true
            UIAccessibility.post(notification: .announcement, argument: validationMessage)
            return
        }
        if step < 3 {
            step += 1
            focusHeading()
            return
        }
        finish()
    }

    private func finish() {
        if player.name.isBlank {
            player.name = player.preferredName
        }
        if player.preferredName.isBlank {
            player.preferredName = player.name
        }
        player.trackingMode = settings.trackingMode
        player.preferredMatchType = settings.defaultMatchType.rawValue
        if player.playerMode == .standardTennis {
            player.sightLevel = .fullySighted
            player.bCategory = "Fully Sighted"
        } else {
            player.bCategory = String(player.sightLevel.rawValue.prefix(2))
        }
        settings.applyModeDefaults()
        settings.announceScores = settings.scoreAnnouncementMode != .off
        store.completeOnboarding(player: player, settings: settings)
        UIAccessibility.post(notification: .announcement, argument: "Setup complete. Welcome, \(player.displayName).")
    }

    private func focusHeading() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            focusedHeading = true
        }
    }
}
