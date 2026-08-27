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

enum MatchResult: String, Codable, CaseIterable, Identifiable {
    case win = "Win"
    case loss = "Loss"
    case draw = "Draw"
    case retired = "Retired"

    var id: String { rawValue }
}

enum MatchKind: String, Codable, CaseIterable, Identifiable {
    case singles = "Singles"
    case doubles = "Doubles"

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
    var location = ""
    var venue = ""
    var venueType = ""
    var focus = ""
    var effortLevel = "Medium"
    var confidenceLevel = "Medium"
    var sessionOutcome = ""
    var energyLevel = "Medium"
    var painLevel = "None"
    var trainingConditions = ""
    var weatherConditions = ""
    var equipmentNotes = ""
    var notes = ""

    var placeText: String {
        [venue, location, venueType].filter { !$0.isBlank }.joined(separator: ", ").fallback("location not recorded")
    }
}

struct MatchRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var playerID: UUID
    var date = Date()
    var matchType: MatchKind = .singles
    var opponentName = ""
    var partnerName = ""
    var opponent2Name = ""
    var result: MatchResult = .win
    var matchPosition = "Not specified"
    var opponentStyle = ""
    var pressureMoment = ""
    var matchStory = ""
    var nextPracticeFocus = ""
    var courtSurface = ""
    var matchConditions = ""
    var matchStrengths = ""
    var matchNeedsWork = ""
    var notes = ""
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
}

struct TournamentRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var playerID: UUID
    var name = ""
    var location = ""
    var date = Date()
    var finalResult = "Entered"
    var matchesPlayed = 0
    var format = "Single elimination"
    var stageReached = "Not started"
    var goal = ""
    var preparationNotes = ""
    var reviewNotes = ""
    var notes = ""

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
    var announceScores = true
    var hapticsEnabled = true
    var showNeedsAttention = true
    var showRecentActivity = true
    var showUpcomingTournaments = true

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
        announceScores = try container.decodeIfPresent(Bool.self, forKey: .announceScores) ?? true
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        showNeedsAttention = try container.decodeIfPresent(Bool.self, forKey: .showNeedsAttention) ?? true
        showRecentActivity = try container.decodeIfPresent(Bool.self, forKey: .showRecentActivity) ?? true
        showUpcomingTournaments = try container.decodeIfPresent(Bool.self, forKey: .showUpcomingTournaments) ?? true
    }
}

struct AppData: Codable, Equatable {
    var dataVersion = 3
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
