import AppIntents

struct StartLiveScoringIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Live Scoring"
    static var description = IntentDescription("Open Tennis Tracker ready to start live scoring.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening Tennis Tracker for live scoring.")
    }
}

struct AddMatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Match"
    static var description = IntentDescription("Open Tennis Tracker to add a match.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening Tennis Tracker to add a match.")
    }
}

struct AddTrainingSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Training Session"
    static var description = IntentDescription("Open Tennis Tracker to add a training session.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening Tennis Tracker to add training.")
    }
}

struct AddTournamentIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Tournament"
    static var description = IntentDescription("Open Tennis Tracker to add a tournament.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening Tennis Tracker to add a tournament.")
    }
}

struct ShowNextTournamentIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Next Tournament"
    static var description = IntentDescription("Open Tennis Tracker to the tournament area.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening Tennis Tracker tournaments.")
    }
}

struct ShowRecentRecordIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Recent Record"
    static var description = IntentDescription("Open Tennis Tracker to recent tennis activity.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening Tennis Tracker recent activity.")
    }
}

struct TennisTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartLiveScoringIntent(), phrases: ["Start live scoring in \(.applicationName)"], shortTitle: "Start Live Score", systemImageName: "figure.tennis")
        AppShortcut(intent: AddMatchIntent(), phrases: ["Add a match in \(.applicationName)"], shortTitle: "Add Match", systemImageName: "plus.circle")
        AppShortcut(intent: AddTrainingSessionIntent(), phrases: ["Add training in \(.applicationName)"], shortTitle: "Add Training", systemImageName: "figure.run")
        AppShortcut(intent: AddTournamentIntent(), phrases: ["Add a tournament in \(.applicationName)"], shortTitle: "Add Tournament", systemImageName: "trophy")
        AppShortcut(intent: ShowNextTournamentIntent(), phrases: ["Show my next tournament in \(.applicationName)"], shortTitle: "Next Tournament", systemImageName: "calendar")
        AppShortcut(intent: ShowRecentRecordIntent(), phrases: ["Show my recent record in \(.applicationName)"], shortTitle: "Recent Record", systemImageName: "chart.bar")
    }
}
