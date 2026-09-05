import Foundation

extension TennisWatchSyncCommand {
    var recordID: UUID? {
        switch self {
        case .upsertMatch(let value): return value.id
        case .upsertTraining(let value): return value.id
        case .upsertTournament(let value): return value.id
        default: return nil
        }
    }
}

enum TennisWatchReconciliation {
    static func reconcile(incoming: TennisWatchSnapshot, pending: [TennisWatchSyncCommand]) -> (snapshot: TennisWatchSnapshot, pending: [TennisWatchSyncCommand]) {
        var snapshot = incoming
        var unacknowledged: [TennisWatchSyncCommand] = []
        for command in pending {
            let acknowledged: Bool
            switch command {
            case .upsertMatch(let record):
                acknowledged = snapshot.matches.contains { $0.id == record.id && TennisRecordConflictResolver.shouldReplace(incomingRevision: $0.revision, incomingModifiedAt: $0.modifiedAt, existingRevision: record.revision, existingModifiedAt: record.modifiedAt) }
                if !acknowledged { snapshot.matches.removeAll { $0.id == record.id }; snapshot.matches.insert(record, at: 0) }
            case .upsertTraining(let record):
                acknowledged = snapshot.trainingSessions.contains { $0.id == record.id && TennisRecordConflictResolver.shouldReplace(incomingRevision: $0.revision, incomingModifiedAt: $0.modifiedAt, existingRevision: record.revision, existingModifiedAt: record.modifiedAt) }
                if !acknowledged { snapshot.trainingSessions.removeAll { $0.id == record.id }; snapshot.trainingSessions.insert(record, at: 0) }
            case .upsertTournament(let record):
                acknowledged = snapshot.tournaments.contains { $0.id == record.id && TennisRecordConflictResolver.shouldReplace(incomingRevision: $0.revision, incomingModifiedAt: $0.modifiedAt, existingRevision: record.revision, existingModifiedAt: record.modifiedAt) }
                if !acknowledged { snapshot.tournaments.removeAll { $0.id == record.id }; snapshot.tournaments.insert(record, at: 0) }
            default: acknowledged = false
            }
            if !acknowledged { unacknowledged.append(command) }
        }
        return (snapshot, unacknowledged)
    }
}
