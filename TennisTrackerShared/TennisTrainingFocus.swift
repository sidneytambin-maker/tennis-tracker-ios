import Foundation

enum TennisTrainingFocus: String, CaseIterable, Identifiable {
    case serves = "Serves"
    case returns = "Returns"
    case serveAndReturn = "Serve and return"
    case forehand = "Forehand"
    case backhand = "Backhand"
    case volleys = "Volleys and net play"
    case overheads = "Overheads and smashes"
    case footwork = "Footwork and court movement"
    case rallying = "Rally consistency"
    case placement = "Shot placement and accuracy"
    case tactics = "Point construction and tactics"
    case doubles = "Doubles positioning and teamwork"
    case defence = "Defence and recovery"
    case touch = "Drop shots and lobs"
    case tracking = "Ball tracking and timing"
    case pressure = "Playing under pressure"

    var id: String { rawValue }
}

extension TrainingSession {
    var dashboardFocusSummary: String {
        let value = focus.trimmingCharacters(in: .whitespacesAndNewlines)
        if TrainingType.allCases.contains(where: { $0.rawValue.localizedCaseInsensitiveCompare(value) == .orderedSame }) {
            return "Specific focus not recorded"
        }
        return focusSummary
    }
    var focusSummary: String { focus.trimmingCharacters(in: .whitespacesAndNewlines).fallback("No focus selected") }

    func isRecordedTraining(at now: Date) -> Bool {
        guard !isActive else { return false }
        if let finish = actualFinish { return finish <= now }
        return expectedEndDate <= now
    }
}
