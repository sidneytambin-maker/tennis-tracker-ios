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
    case notKnown = "Not known"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .fullySighted: return "Sighted"
        case .notKnown: return "Not known"
        default: return String(rawValue.prefix(2))
        }
    }
    var allowedBounces: Int {
        switch self {
        case .b1, .b2: return 3
        case .b3: return 2
        case .b4, .b5, .fullySighted, .notKnown: return 1
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

enum MatchFormat: String, Codable, CaseIterable, Identifiable {
    case oneSet = "1 set"
    case bestOfThree = "Best of 3"
    case bestOfFive = "Best of 5"
    case custom = "Custom"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .oneSet: return "One set"
        case .bestOfThree: return "Best of 3 sets"
        case .bestOfFive: return "Best of 5 sets"
        case .custom: return "Custom"
        }
    }

    var defaultSetsToEnter: Int {
        switch self {
        case .oneSet: return 1
        case .bestOfThree: return 2
        case .bestOfFive: return 3
        case .custom: return 1
        }
    }

    var maximumSetsToEnter: Int {
        switch self {
        case .oneSet: return 1
        case .bestOfThree: return 3
        case .bestOfFive: return 5
        case .custom: return 5
        }
    }

    var setsNeededToWin: Int {
        switch self {
        case .oneSet: return 1
        case .bestOfThree: return 2
        case .bestOfFive: return 3
        case .custom: return 2
        }
    }
}

enum TieBreakRule: String, Codable, CaseIterable, Identifiable {
    case standardAtSixAll = "Standard at 6-6"
    case tenPoint = "Match tie-break"
    case manual = "Manual or custom"
    case noAutomatic = "No automatic tie-break"

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "Automatic at 6-6", "Standard at 6-6":
            self = .standardAtSixAll
        case "10 point match tie-break", "Match tie-break":
            self = .tenPoint
        case "Manual start and finish", "Manual or custom":
            self = .manual
        case "No automatic tie-break":
            self = .noAutomatic
        default:
            self = .standardAtSixAll
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum TrainingType: String, Codable, CaseIterable, Identifiable {
    case oneToOneCoaching = "One-to-one coaching"
    case singlesPractice = "Singles practice"
    case doublesPractice = "Doubles practice"
    case groupCoaching = "Group coaching"
    case servingPractice = "Serving practice"
    case returnPractice = "Return practice"
    case drillsTechnique = "Drills and technique"
    case other = "Other"
    case serveAndReturn = "Serve and return"
    case rallyConsistency = "Rally consistency"
    case movementAndFootwork = "Movement and positioning"
    case matchPlay = "Match practice"
    case tacticalPatterns = "Tactical patterns"
    case fitnessConditioning = "Fitness and conditioning"
    case tournamentPreparation = "Tournament preparation"

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "General practice", "Technical session":
            self = .rallyConsistency
        case "Tactical session":
            self = .tacticalPatterns
        case "Fitness", "Tennis fitness":
            self = .fitnessConditioning
        case "Match practice", "Practice match":
            self = .matchPlay
        case "Movement and footwork":
            self = .movementAndFootwork
        case "Coaching":
            self = .oneToOneCoaching
        default:
            self = TrainingType(rawValue: value) ?? .singlesPractice
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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
    var isRegularPartner = false
    var bounceAllowance: Int?
    var defaultMatchFormat: MatchFormat = .oneSet

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
        isRegularPartner = try container.decodeIfPresent(Bool.self, forKey: .isRegularPartner) ?? false
        bounceAllowance = try container.decodeIfPresent(Int.self, forKey: .bounceAllowance)
        defaultMatchFormat = try container.decodeIfPresent(MatchFormat.self, forKey: .defaultMatchFormat) ?? .oneSet
    }
}

struct TrainingSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var playerID: UUID
    var modifiedAt = Date()
    var revision = 0
    var needsDetails = false
    var hasSessionDetails = true
    var date = Date()
    var hasStartTime = true
    var durationMinutes = 60
    var trainingType: TrainingType = .singlesPractice
    var location = ""
    var venue = ""
    var surface: CourtSurface = .notSpecified
    var focus = "Singles practice"
    var effortLevel: RatingLevel = .medium
    var confidenceLevel: RatingLevel = .medium
    var sessionOutcome = ""
    var energyLevel: RatingLevel = .medium
    var painLevel: PainLevel = .none
    var notes = ""

    var context: TennisActivityContext = TennisActivityContext()
    var actualStart: Date?
    var actualFinish: Date?
    var workout: TennisWorkoutResult?
    var practiceResult: TennisPracticeResult?

    var isActive: Bool { actualStart != nil && actualFinish == nil }

    var placeText: String {
        [venue, location, surface == .notSpecified ? "" : surface.rawValue].filter { !$0.isBlank }.joined(separator: ", ").fallback("location not recorded")
    }

    var expectedEndDate: Date {
        date.addingTimeInterval(TimeInterval(max(1, durationMinutes) * 60))
    }

    init(playerID: UUID) {
        self.playerID = playerID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        playerID = try container.decode(UUID.self, forKey: .playerID)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        needsDetails = try container.decodeIfPresent(Bool.self, forKey: .needsDetails) ?? false
        hasSessionDetails = try container.decodeIfPresent(Bool.self, forKey: .hasSessionDetails) ?? true
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        hasStartTime = try container.decodeIfPresent(Bool.self, forKey: .hasStartTime) ?? false
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 60
        trainingType = try container.decodeIfPresent(TrainingType.self, forKey: .trainingType) ?? .singlesPractice
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        venue = try container.decodeIfPresent(String.self, forKey: .venue) ?? ""
        surface = try container.decodeIfPresent(CourtSurface.self, forKey: .surface) ?? .notSpecified
        focus = try container.decodeIfPresent(String.self, forKey: .focus) ?? "Singles practice"
        effortLevel = try container.decodeIfPresent(RatingLevel.self, forKey: .effortLevel) ?? .medium
        confidenceLevel = try container.decodeIfPresent(RatingLevel.self, forKey: .confidenceLevel) ?? .medium
        sessionOutcome = try container.decodeIfPresent(String.self, forKey: .sessionOutcome) ?? ""
        energyLevel = try container.decodeIfPresent(RatingLevel.self, forKey: .energyLevel) ?? .medium
        painLevel = try container.decodeIfPresent(PainLevel.self, forKey: .painLevel) ?? .none
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        context = try container.decodeIfPresent(TennisActivityContext.self, forKey: .context) ?? TennisActivityContext()
        actualStart = try container.decodeIfPresent(Date.self, forKey: .actualStart)
        actualFinish = try container.decodeIfPresent(Date.self, forKey: .actualFinish)
        workout = try container.decodeIfPresent(TennisWorkoutResult.self, forKey: .workout)
        practiceResult = try container.decodeIfPresent(TennisPracticeResult.self, forKey: .practiceResult)
    }
}

struct MatchRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var playerID: UUID
    var modifiedAt = Date()
    var revision = 0
    var needsDetails = false
    var date = Date()
    var hasStartTime = false
    var expectedDurationMinutes = 90
    var hasExpectedDuration = false
    var venue = ""
    var location = ""
    var status: MatchStatus = .completed
    var matchType: MatchKind = .singles
    var matchFormat: MatchFormat = .bestOfThree
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
    var opponentID: UUID?
    var partnerID: UUID?
    var opponent2ID: UUID?
    var venueID: UUID?

    var playerTeam: String {
        (matchType == .doubles ? [playerName, partnerName] : [playerName])
            .filter { !$0.isBlank }.joined(separator: " and ").fallback("Player")
    }

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
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        needsDetails = try container.decodeIfPresent(Bool.self, forKey: .needsDetails) ?? false
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        hasStartTime = try container.decodeIfPresent(Bool.self, forKey: .hasStartTime) ?? false
        expectedDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .expectedDurationMinutes) ?? 90
        hasExpectedDuration = try container.decodeIfPresent(Bool.self, forKey: .hasExpectedDuration) ?? false
        venue = try container.decodeIfPresent(String.self, forKey: .venue) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        status = try container.decodeIfPresent(MatchStatus.self, forKey: .status) ?? .completed
        matchType = try container.decodeIfPresent(MatchKind.self, forKey: .matchType) ?? .singles
        matchFormat = try container.decodeIfPresent(MatchFormat.self, forKey: .matchFormat) ?? .bestOfThree
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
        opponentID = try container.decodeIfPresent(UUID.self, forKey: .opponentID)
        partnerID = try container.decodeIfPresent(UUID.self, forKey: .partnerID)
        opponent2ID = try container.decodeIfPresent(UUID.self, forKey: .opponent2ID)
        venueID = try container.decodeIfPresent(UUID.self, forKey: .venueID)
    }
}

struct TournamentRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var playerID: UUID
    var modifiedAt = Date()
    var revision = 0
    var needsDetails = false
    var name = ""
    var location = ""
    var date = Date()
    var endDate = Date()
    var isAllDay = true
    var hasStartTime = false
    var category = "B1"
    var finalResult: TournamentResult = .entered
    var matchesPlayed = 0
    var format: TournamentFormat = .singleElimination
    var stageReached: TournamentStage = .notStarted
    var goal = ""
    var notes = ""
    var templateID: UUID?
    var venueID: UUID?
    var venue = ""

    var isCompleted: Bool {
        finalResult == .completed || finalResult == .withdrawn || endDate < Calendar.current.startOfDay(for: Date())
    }

    func outstandingMatches(linkedMatchCount: Int) -> Int {
        max(0, matchesPlayed - linkedMatchCount)
    }

    init(playerID: UUID) {
        self.playerID = playerID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        playerID = try container.decode(UUID.self, forKey: .playerID)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        needsDetails = try container.decodeIfPresent(Bool.self, forKey: .needsDetails) ?? false
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? date
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? true
        hasStartTime = try container.decodeIfPresent(Bool.self, forKey: .hasStartTime) ?? false
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "B1"
        finalResult = try container.decodeIfPresent(TournamentResult.self, forKey: .finalResult) ?? .entered
        matchesPlayed = try container.decodeIfPresent(Int.self, forKey: .matchesPlayed) ?? 0
        format = try container.decodeIfPresent(TournamentFormat.self, forKey: .format) ?? .singleElimination
        stageReached = try container.decodeIfPresent(TournamentStage.self, forKey: .stageReached) ?? .notStarted
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        templateID = try container.decodeIfPresent(UUID.self, forKey: .templateID)
        venueID = try container.decodeIfPresent(UUID.self, forKey: .venueID)
        venue = try container.decodeIfPresent(String.self, forKey: .venue) ?? ""
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
    var matchResultRemindersEnabled = false
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
        matchResultRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .matchResultRemindersEnabled) ?? false
        weeklySummaryEnabled = try container.decodeIfPresent(Bool.self, forKey: .weeklySummaryEnabled) ?? false
        reminderLeadMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderLeadMinutes) ?? 60
        postSessionDelayMinutes = try container.decodeIfPresent(Int.self, forKey: .postSessionDelayMinutes) ?? 120
        calendarIntegrationEnabled = try container.decodeIfPresent(Bool.self, forKey: .calendarIntegrationEnabled) ?? false
    }
}

struct AppData: Codable, Equatable {
    var dataVersion = 9
    var setup = TennisSetup()
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
        setup = try container.decodeIfPresent(TennisSetup.self, forKey: .setup) ?? TennisSetup()
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
