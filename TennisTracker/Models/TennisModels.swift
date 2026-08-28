import Foundation

enum TrackingMode: String, Codable, CaseIterable, Identifiable {
    case basic = "Basic"
    case standard = "Standard"
    case power = "Power"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .basic:
            return "Quick recording for core player, match, training, tournament, dashboard, report, and settings records."
        case .standard:
            return "Guided recording with goals, training focus, venues, conditions, and richer summaries."
        case .power:
            return "Detailed tracking with wellness, equipment, deeper trends, comparisons, and advanced notes."
        }
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case tennis = "Tennis"
    case classic = "Classic"
    case highContrast = "High Contrast"
    case system = "System"

    var id: String { rawValue }
}

enum ScoreAnnouncementMode: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case reduced = "Reduced"
    case off = "Off"

    var id: String { rawValue }
}

enum PlayerMode: String, Codable, CaseIterable, Identifiable {
    case blindTennis = "Blind or visually impaired tennis"
    case standardTennis = "Standard tennis"

    var id: String { rawValue }
}

enum SightLevel: String, Codable, CaseIterable, Identifiable {
    case b1 = "B1 - 3 bounces of the ball allowed"
    case b2 = "B2 - 3 bounces of the ball allowed"
    case b3 = "B3 - 2 bounces of the ball allowed"
    case b4 = "B4 - 1 bounce of the ball allowed"
    case b5 = "B5 - 1 bounce of the ball allowed"
    case fullySighted = "Fully Sighted - 1 bounce of the ball allowed"

    var id: String { rawValue }
    var allowedBounces: Int {
        switch self {
        case .b1, .b2: return 3
        case .b3: return 2
        case .b4, .b5, .fullySighted: return 1
        }
    }
}

enum CourtSurface: String, Codable, CaseIterable, Identifiable {
    case notSpecified = "Not specified"
    case hard = "Hard court"
    case clay = "Clay"
    case grass = "Grass"
    case carpet = "Carpet"
    case indoor = "Indoor"

    var id: String { rawValue }
}

enum MatchResult: String, Codable, CaseIterable, Identifiable {
    case win = "Win"
    case loss = "Loss"
    case draw = "Draw"
    case retired = "Retired"

    var id: String { rawValue }
}

enum MatchPosition: String, Codable, CaseIterable, Identifiable {
    case notSpecified = "Not specified"
    case roundRobin = "Round robin"
    case last16 = "Last 16"
    case quarterFinal = "Quarter-final"
    case semiFinal = "Semi-final"
    case final = "Final"

    var id: String { rawValue }
}

enum MatchKind: String, Codable, CaseIterable, Identifiable {
    case singles = "Singles"
    case doubles = "Doubles"

    var id: String { rawValue }
}

enum MatchStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled = "Scheduled"
    case inProgress = "In progress"
    case completed = "Completed"

    var id: String { rawValue }
}

enum TieBreakRule: String, Codable, CaseIterable, Identifiable {
    case standardAtSixAll = "Automatic at 6-6"
    case manual = "Manual start and finish"
    case tenPoint = "10 point match tie-break"

    var id: String { rawValue }
}

enum TrainingType: String, Codable, CaseIterable, Identifiable {
    case general = "General practice"
    case technical = "Technical session"
    case tactical = "Tactical session"
    case fitness = "Fitness"
    case matchPractice = "Match practice"
    case coaching = "Coaching"

    var id: String { rawValue }
}

enum RatingLevel: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

enum PainLevel: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case mild = "Mild"
    case moderate = "Moderate"
    case high = "High"

    var id: String { rawValue }
}

enum TournamentFormat: String, Codable, CaseIterable, Identifiable {
    case singleElimination = "Single elimination"
    case roundRobin = "Round robin"
    case league = "League"
    case friendly = "Friendly event"
    case other = "Other"

    var id: String { rawValue }
}

enum TournamentStage: String, Codable, CaseIterable, Identifiable {
    case notStarted = "Not started"
    case groupStage = "Group stage"
    case last16 = "Last 16"
    case quarterFinal = "Quarter-final"
    case semiFinal = "Semi-final"
    case final = "Final"
    case winner = "Winner"

    var id: String { rawValue }
}

enum TournamentResult: String, Codable, CaseIterable, Identifiable {
    case entered = "Entered"
    case inProgress = "In progress"
    case completed = "Completed"
    case withdrawn = "Withdrawn"

    var id: String { rawValue }
}

struct PlayerProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var preferredName = ""
    var surname = ""
    var nationality = ""
    var ltaNumber = ""
    var itfNumber = ""
    var bCategory = "B1"
    var age = 0
    var sightLevel: SightLevel = .b1
    var gender = "Prefer not to say"
    var playerMode: PlayerMode = .blindTennis
    var trackingMode: TrackingMode = .basic
    var playingHand = ""
    var club = ""
    var primaryGoal = ""
    var preferredMatchType = "Singles"
    var preferredSurface = ""
    var playingStyle = ""
    var coachingFocus = ""
    var profileNotes = ""

    var displayName: String {
        if !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return preferredName
        }
        return name.isEmpty ? "Unnamed player" : name
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        preferredName = try container.decodeIfPresent(String.self, forKey: .preferredName) ?? ""
        surname = try container.decodeIfPresent(String.self, forKey: .surname) ?? ""
        nationality = try container.decodeIfPresent(String.self, forKey: .nationality) ?? ""
        ltaNumber = try container.decodeIfPresent(String.self, forKey: .ltaNumber) ?? ""
        itfNumber = try container.decodeIfPresent(String.self, forKey: .itfNumber) ?? ""
        bCategory = try container.decodeIfPresent(String.self, forKey: .bCategory) ?? "B1"
        age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 0
        sightLevel = try container.decodeIfPresent(SightLevel.self, forKey: .sightLevel) ?? .b1
        gender = try container.decodeIfPresent(String.self, forKey: .gender) ?? "Prefer not to say"
        playerMode = try container.decodeIfPresent(PlayerMode.self, forKey: .playerMode) ?? .blindTennis
        trackingMode = try container.decodeIfPresent(TrackingMode.self, forKey: .trackingMode) ?? .basic
        playingHand = try container.decodeIfPresent(String.self, forKey: .playingHand) ?? ""
        club = try container.decodeIfPresent(String.self, forKey: .club) ?? ""
        primaryGoal = try container.decodeIfPresent(String.self, forKey: .primaryGoal) ?? ""
        preferredMatchType = try container.decodeIfPresent(String.self, forKey: .preferredMatchType) ?? "Singles"
        preferredSurface = try container.decodeIfPresent(String.self, forKey: .preferredSurface) ?? ""
        playingStyle = try container.decodeIfPresent(String.self, forKey: .playingStyle) ?? ""
        coachingFocus = try container.decodeIfPresent(String.self, forKey: .coachingFocus) ?? ""
        profileNotes = try container.decodeIfPresent(String.self, forKey: .profileNotes) ?? ""
    }
}

struct TrainingSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var playerID: UUID
    var hasSessionDetails = true
    var date = Date()
    var durationMinutes = 60
    var trainingType: TrainingType = .general
    var location = ""
    var venue = ""
    var surface: CourtSurface = .notSpecified
    var focus = "General practice"
    var effortLevel: RatingLevel = .medium
    var confidenceLevel: RatingLevel = .medium
    var sessionOutcome = ""
    var energyLevel: RatingLevel = .medium
    var painLevel: PainLevel = .none
    var notes = ""

    var placeText: String {
        [venue, location, surface == .notSpecified ? "" : surface.rawValue].filter { !$0.isBlank }.joined(separator: ", ").fallback("location not recorded")
    }
}

struct MatchRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var playerID: UUID
    var date = Date()
    var expectedDurationMinutes = 90
    var venue = ""
    var location = ""
    var status: MatchStatus = .completed
    var matchType: MatchKind = .singles
    var playerName = ""
    var opponentName = ""
    var partnerName = ""
    var opponent2Name = ""
    var result: MatchResult = .win
    var matchPosition: MatchPosition = .notSpecified
    var opponentStyle = ""
    var pressureMoment = ""
    var matchStory = ""
    var nextPracticeFocus = ""
    var courtSurface: CourtSurface = .notSpecified
    var matchConditions = ""
    var matchStrengths = ""
    var matchNeedsWork = ""
    var notes = ""
    var sightLevel: SightLevel = .b1
    var allowedBounces = 3
    var suddenDeathDeuce = true
    var tieBreakRule: TieBreakRule = .standardAtSixAll
    var tieBreakTarget = 7
    var tieBreakWinByTwo = true
    var aces = 0
    var doubleFaults = 0
    var winners = 0
    var unforcedErrors = 0
    var yourSetsWon = 0
    var opponentSetsWon = 0
    var setScores = ""
    var hadTiebreak = false
    var tiebreakScore = ""
    var tournamentID: UUID?
    var trainingSessionID: UUID?
    var liveScore: TennisScoreSnapshot?
    var stableShareID = UUID()
    var sharingEnabled = false

    var opponentSummary: String {
        matchType == .doubles ? [opponentName, opponent2Name].filter { !$0.isBlank }.joined(separator: " and ") : opponentName
    }

    var setsPlayed: Int {
        let recorded = setScores.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let useful = recorded.filter { !$0.isEmpty && $0 != "0-0" }
        return useful.isEmpty ? yourSetsWon + opponentSetsWon : useful.count
    }

    var tiebreakSetCount: Int {
        tiebreakScore.split(separator: ";").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    init(playerID: UUID) {
        self.playerID = playerID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        playerID = try container.decode(UUID.self, forKey: .playerID)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        expectedDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .expectedDurationMinutes) ?? 90
        venue = try container.decodeIfPresent(String.self, forKey: .venue) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        status = try container.decodeIfPresent(MatchStatus.self, forKey: .status) ?? .completed
        matchType = try container.decodeIfPresent(MatchKind.self, forKey: .matchType) ?? .singles
        playerName = try container.decodeIfPresent(String.self, forKey: .playerName) ?? ""
        opponentName = try container.decodeIfPresent(String.self, forKey: .opponentName) ?? ""
        partnerName = try container.decodeIfPresent(String.self, forKey: .partnerName) ?? ""
        opponent2Name = try container.decodeIfPresent(String.self, forKey: .opponent2Name) ?? ""
        result = try container.decodeIfPresent(MatchResult.self, forKey: .result) ?? .win
        matchPosition = try container.decodeIfPresent(MatchPosition.self, forKey: .matchPosition) ?? .notSpecified
        opponentStyle = try container.decodeIfPresent(String.self, forKey: .opponentStyle) ?? ""
        pressureMoment = try container.decodeIfPresent(String.self, forKey: .pressureMoment) ?? ""
        matchStory = try container.decodeIfPresent(String.self, forKey: .matchStory) ?? ""
        nextPracticeFocus = try container.decodeIfPresent(String.self, forKey: .nextPracticeFocus) ?? ""
        courtSurface = try container.decodeIfPresent(CourtSurface.self, forKey: .courtSurface) ?? .notSpecified
        matchConditions = try container.decodeIfPresent(String.self, forKey: .matchConditions) ?? ""
        matchStrengths = try container.decodeIfPresent(String.self, forKey: .matchStrengths) ?? ""
        matchNeedsWork = try container.decodeIfPresent(String.self, forKey: .matchNeedsWork) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        sightLevel = try container.decodeIfPresent(SightLevel.self, forKey: .sightLevel) ?? .b1
        allowedBounces = try container.decodeIfPresent(Int.self, forKey: .allowedBounces) ?? sightLevel.allowedBounces
        suddenDeathDeuce = try container.decodeIfPresent(Bool.self, forKey: .suddenDeathDeuce) ?? true
        tieBreakRule = try container.decodeIfPresent(TieBreakRule.self, forKey: .tieBreakRule) ?? .standardAtSixAll
        tieBreakTarget = try container.decodeIfPresent(Int.self, forKey: .tieBreakTarget) ?? 7
        tieBreakWinByTwo = try container.decodeIfPresent(Bool.self, forKey: .tieBreakWinByTwo) ?? true
        aces = try container.decodeIfPresent(Int.self, forKey: .aces) ?? 0
        doubleFaults = try container.decodeIfPresent(Int.self, forKey: .doubleFaults) ?? 0
        winners = try container.decodeIfPresent(Int.self, forKey: .winners) ?? 0
        unforcedErrors = try container.decodeIfPresent(Int.self, forKey: .unforcedErrors) ?? 0
        yourSetsWon = try container.decodeIfPresent(Int.self, forKey: .yourSetsWon) ?? 0
        opponentSetsWon = try container.decodeIfPresent(Int.self, forKey: .opponentSetsWon) ?? 0
        setScores = try container.decodeIfPresent(String.self, forKey: .setScores) ?? ""
        hadTiebreak = try container.decodeIfPresent(Bool.self, forKey: .hadTiebreak) ?? false
        tiebreakScore = try container.decodeIfPresent(String.self, forKey: .tiebreakScore) ?? ""
        tournamentID = try container.decodeIfPresent(UUID.self, forKey: .tournamentID)
        trainingSessionID = try container.decodeIfPresent(UUID.self, forKey: .trainingSessionID)
        liveScore = try container.decodeIfPresent(TennisScoreSnapshot.self, forKey: .liveScore)
        stableShareID = try container.decodeIfPresent(UUID.self, forKey: .stableShareID) ?? UUID()
        sharingEnabled = try container.decodeIfPresent(Bool.self, forKey: .sharingEnabled) ?? false
    }
}

struct TournamentRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var playerID: UUID
    var name = ""
    var location = ""
    var date = Date()
    var endDate = Date()
    var category = "B1"
    var finalResult: TournamentResult = .entered
    var matchesPlayed = 0
    var format: TournamentFormat = .singleElimination
    var stageReached: TournamentStage = .notStarted
    var goal = ""
    var notes = ""

    var isCompleted: Bool {
        finalResult == .completed || finalResult == .withdrawn || endDate < Calendar.current.startOfDay(for: Date())
    }

    func outstandingMatches(linkedMatchCount: Int) -> Int {
        max(0, matchesPlayed - linkedMatchCount)
    }
}

struct AppSettings: Codable, Equatable {
    var theme: AppTheme = .tennis
    var trackingMode: TrackingMode = .basic
    var formDetail = "Simple"
    var defaultMatchType: MatchKind = .singles
    var defaultSeason = Calendar.current.component(.year, from: Date())
    var scoreAnnouncementMode: ScoreAnnouncementMode = .automatic
    var announceScores = true
    var hapticsEnabled = true
    var showNeedsAttention = true
    var showRecentActivity = true
    var showUpcomingTournaments = true
    var trainingRemindersEnabled = false
    var matchRemindersEnabled = false
    var tournamentRemindersEnabled = false
    var postSessionRemindersEnabled = false
    var weeklySummaryEnabled = false
    var reminderLeadMinutes = 60
    var postSessionDelayMinutes = 120
    var calendarIntegrationEnabled = false

    mutating func applyModeDefaults() {
        switch trackingMode {
        case .basic:
            formDetail = "Simple"
        case .standard:
            formDetail = "Guided"
        case .power:
            formDetail = "Detailed"
        }
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .tennis
        trackingMode = try container.decodeIfPresent(TrackingMode.self, forKey: .trackingMode) ?? .basic
        formDetail = try container.decodeIfPresent(String.self, forKey: .formDetail) ?? "Simple"
        defaultMatchType = try container.decodeIfPresent(MatchKind.self, forKey: .defaultMatchType) ?? .singles
        defaultSeason = try container.decodeIfPresent(Int.self, forKey: .defaultSeason) ?? Calendar.current.component(.year, from: Date())
        scoreAnnouncementMode = try container.decodeIfPresent(ScoreAnnouncementMode.self, forKey: .scoreAnnouncementMode) ?? ((try container.decodeIfPresent(Bool.self, forKey: .announceScores) ?? true) ? .automatic : .off)
        announceScores = try container.decodeIfPresent(Bool.self, forKey: .announceScores) ?? true
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        showNeedsAttention = try container.decodeIfPresent(Bool.self, forKey: .showNeedsAttention) ?? true
        showRecentActivity = try container.decodeIfPresent(Bool.self, forKey: .showRecentActivity) ?? true
        showUpcomingTournaments = try container.decodeIfPresent(Bool.self, forKey: .showUpcomingTournaments) ?? true
        trainingRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .trainingRemindersEnabled) ?? false
        matchRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .matchRemindersEnabled) ?? false
        tournamentRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .tournamentRemindersEnabled) ?? false
        postSessionRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .postSessionRemindersEnabled) ?? false
        weeklySummaryEnabled = try container.decodeIfPresent(Bool.self, forKey: .weeklySummaryEnabled) ?? false
        reminderLeadMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderLeadMinutes) ?? 60
        postSessionDelayMinutes = try container.decodeIfPresent(Int.self, forKey: .postSessionDelayMinutes) ?? 120
        calendarIntegrationEnabled = try container.decodeIfPresent(Bool.self, forKey: .calendarIntegrationEnabled) ?? false
    }
}

struct AppData: Codable, Equatable {
    var dataVersion = 5
    var selectedPlayerID: UUID?
    var players: [PlayerProfile] = []
    var matches: [MatchRecord] = []
    var trainingSessions: [TrainingSession] = []
    var tournaments: [TournamentRecord] = []
    var settings = AppSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataVersion = try container.decodeIfPresent(Int.self, forKey: .dataVersion) ?? 1
        selectedPlayerID = try container.decodeIfPresent(UUID.self, forKey: .selectedPlayerID)
        players = try container.decodeIfPresent([PlayerProfile].self, forKey: .players) ?? []
        matches = try container.decodeIfPresent([MatchRecord].self, forKey: .matches) ?? []
        trainingSessions = try container.decodeIfPresent([TrainingSession].self, forKey: .trainingSessions) ?? []
        tournaments = try container.decodeIfPresent([TournamentRecord].self, forKey: .tournaments) ?? []
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }
}

extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func fallback(_ value: String) -> String {
        isBlank ? value : self
    }
}
