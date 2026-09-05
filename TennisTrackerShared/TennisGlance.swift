import Foundation

struct TennisGlance: Equatable {
    var title: String
    var detail: String
    var accessibilitySummary: String
    var destination: TennisWatchPage
    var isStale: Bool

    static func make(snapshot: TennisWatchSnapshot, now: Date = Date()) -> Self {
        let matches = snapshot.matches.filter { snapshot.selectedPlayerID == nil || $0.playerID == snapshot.selectedPlayerID }
        let training = snapshot.trainingSessions.filter { snapshot.selectedPlayerID == nil || $0.playerID == snapshot.selectedPlayerID }
        if let match = matches.first(where: { $0.status == .inProgress }), let score = match.liveScore {
            let stale = now.timeIntervalSince(match.modifiedAt) > 6 * 3600
            return Self(title: stale ? "Saved match" : "Match",
                        detail: "\(score.playerGames)-\(score.opponentGames)",
                        accessibilitySummary: (stale ? "Saved score. " : "") + TennisSummaryFormatter.match(match, tournaments: snapshot.tournaments, style: .short),
                        destination: .score, isStale: stale)
        }
        if let session = training.first(where: \.isActive) {
            let start = session.actualStart ?? session.date
            let stale = now.timeIntervalSince(start) > 12 * 3600
            return Self(title: stale ? "Check training" : "Training",
                        detail: stale ? session.trainingType.rawValue : "\(max(0, Int(now.timeIntervalSince(start) / 60))) min",
                        accessibilitySummary: stale ? "Training may still be running. Open Tennis Tracker to check." : "\(session.trainingType.rawValue), \(max(0, Int(now.timeIntervalSince(start) / 60)).durationText).",
                        destination: .live, isStale: stale)
        }
        if let session = training.filter({ $0.actualFinish == nil && $0.date >= now }).sorted(by: { $0.date < $1.date }).first {
            return Self(title: "Training", detail: session.date.shortTennisTime,
                        accessibilitySummary: TennisSummaryFormatter.training(session), destination: .today, isStale: false)
        }
        if let tournament = snapshot.tournaments.filter({ $0.endDate >= Calendar.current.startOfDay(for: now) && $0.finalResult != .completed && $0.finalResult != .withdrawn }).sorted(by: { $0.date < $1.date }).first {
            return Self(title: tournament.name.fallback("Tournament"), detail: tournament.date.shortTennisDate,
                        accessibilitySummary: TennisSummaryFormatter.tournament(tournament, style: .short), destination: .today, isStale: false)
        }
        return Self(title: "Tennis Tracker", detail: "Track tennis", accessibilitySummary: "Tennis Tracker. Track a tennis activity.", destination: .track, isStale: false)
    }
}

enum TennisSharedSnapshotFile {
    private static var url: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "TennisSharedAppGroup") as? String, !group.isBlank else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("tennis-snapshot.json")
    }
    static func write(_ snapshot: TennisWatchSnapshot) throws {
        guard let url else { return }
        try JSONEncoder.tennisTracker.encode(snapshot).write(to: url, options: .atomic)
    }
    static func read() -> TennisWatchSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.tennisTracker.decode(TennisWatchSnapshot.self, from: data)
    }
}
