import Foundation

enum TennisDurationFormatter {
    static func trainingSeconds(_ session: TrainingSession) -> TimeInterval {
        if let seconds = session.workout?.durationSeconds, seconds.isFinite, seconds >= 0 { return seconds }
        if let start = session.actualStart, let finish = session.actualFinish {
            return max(0, finish.timeIntervalSince(start))
        }
        return Double(max(0, session.durationMinutes)) * 60
    }

    static func compact(seconds: TimeInterval) -> String {
        let total = seconds.isFinite ? Int(max(0, min(seconds, 315_360_000)).rounded(.down)) : 0
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
            : String(format: "%d:%02d", total / 60, total % 60)
    }

    static func text(seconds: TimeInterval) -> String {
        let total = seconds.isFinite ? Int(max(0, min(seconds, 315_360_000)).rounded(.down)) : 0
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) \(hours == 1 ? "hour" : "hours")") }
        if minutes > 0 { parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")") }
        if remainder > 0 || parts.isEmpty { parts.append("\(remainder) \(remainder == 1 ? "second" : "seconds")") }
        return parts.joined(separator: " ")
    }

    static func training(_ session: TrainingSession, now: Date = Date()) -> String {
        if session.isActive, let start = session.actualStart { return text(seconds: now.timeIntervalSince(start)) }
        if let seconds = session.workout?.durationSeconds, seconds.isFinite, seconds >= 0 { return text(seconds: seconds) }
        if let start = session.actualStart, let finish = session.actualFinish { return text(seconds: finish.timeIntervalSince(start)) }
        return session.durationMinutes.durationText
    }
}

extension TennisWorkoutResult {
    var fitnessSummary: String {
        Self.fitnessSummary(heartRate: averageHeartRate, average: true, peakHeartRate: peakHeartRate,
            energy: activeEnergyKcal, distance: distanceMeters, steps: stepCount)
    }

    static func fitnessSummary(heartRate: Double?, average: Bool = false, peakHeartRate: Double? = nil,
                               energy: Double?, distance: Double?, steps: Double?) -> String {
        var parts: [String] = []
        if let heartRate, heartRate.isFinite, heartRate > 0 {
            parts.append("\(average ? "Average heart rate" : "Heart rate") \(Int(heartRate.rounded())) beats per minute")
        }
        if let peakHeartRate, peakHeartRate.isFinite, peakHeartRate > 0 {
            parts.append("Peak heart rate \(Int(peakHeartRate.rounded())) beats per minute")
        }
        if let energy, energy.isFinite, energy >= 0 {
            let value = Int(energy.rounded())
            parts.append("Active energy \(value) \(value == 1 ? "calorie" : "calories")")
        }
        if let distance, distance.isFinite, distance >= 0 {
            parts.append(distance < 1000 ? "Distance \(Int(distance.rounded())) metres" : String(format: "Distance %.2f kilometres", distance / 1000))
        }
        if let steps, steps.isFinite, steps >= 0 {
            let value = Int(steps.rounded())
            parts.append("\(value) \(value == 1 ? "step" : "steps")")
        }
        return parts.joined(separator: ". ") + (parts.isEmpty ? "" : ".")
    }
}
