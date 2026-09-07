import Foundation

enum TennisScheduling {
    static func fiveMinuteDate(_ date: Date, calendar: Calendar = .current) -> Date {
        let minute = calendar.component(.minute, from: date)
        let start = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        return start.addingTimeInterval(Double(((minute + 2) / 5) * 5 - minute) * 60)
    }
}
