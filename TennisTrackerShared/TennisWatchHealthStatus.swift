import Foundation

struct TennisWatchHealthStatus: Codable, Equatable {
    var access: String
    var enabledByDefault: Bool
    var reportedAt: Date
}
