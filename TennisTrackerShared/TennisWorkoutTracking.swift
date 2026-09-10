import Foundation
import Combine

@MainActor
protocol TennisWorkoutClient: AnyObject {
    var available: Bool { get }
    func requestPermission() async throws -> Bool
    func begin(activityID: UUID, at date: Date) async throws
    func finish(at date: Date) async throws -> TennisWorkoutResult
    func recover(activityID: UUID) async throws -> Bool
    func discardForLibraryChange()
}

extension TennisWorkoutClient {
    func recover(activityID: UUID) async throws -> Bool { false }
    func discardForLibraryChange() {}
}

enum TennisWorkoutState: Equatable {
    case idle, authorizing, recording, recordingWithoutHealth, finishing, finished
}

@MainActor
final class TennisWorkoutCoordinator: ObservableObject {
    @Published private(set) var state: TennisWorkoutState = .idle
    @Published private(set) var message = ""
    private let client: TennisWorkoutClient
    private var startedAt: Date?
    private var generation = UUID()
    private(set) var activityID: UUID?

    init(client: TennisWorkoutClient) { self.client = client }

    func discardForLibraryChange() {
        generation = UUID()
        client.discardForLibraryChange()
        startedAt = nil; activityID = nil; state = .idle; message = ""
    }

    func start(useHealth: Bool, activityID: UUID = UUID(), at date: Date = Date()) async {
        guard state == .idle || state == .finished else { return }
        let token = generation
        startedAt = date
        self.activityID = activityID
        guard useHealth && client.available else {
            state = .recordingWithoutHealth
            message = useHealth ? "Health is unavailable. Tennis tracking continues." : "Training started."
            return
        }
        state = .authorizing
        do {
            let allowed = try await client.requestPermission()
            guard token == generation else { return }
            guard allowed else {
                state = .recordingWithoutHealth
                message = "Health permission was not granted. Tennis tracking continues."
                return
            }
            try await client.begin(activityID: activityID, at: date)
            guard token == generation else { return }
            state = .recording
            message = "Tennis workout started."
        } catch {
            guard token == generation else { return }
            state = .recordingWithoutHealth
            message = "Health workout could not start. Tennis tracking continues."
        }
    }

    func restore(activityID: UUID, startedAt: Date) async {
        guard state == .idle || state == .finished else { return }
        let token = generation
        self.activityID = activityID
        self.startedAt = startedAt
        state = .authorizing
        do {
            let recovered = client.available ? try await client.recover(activityID: activityID) : false
            guard token == generation else { return }
            state = recovered ? .recording : .recordingWithoutHealth
            message = recovered ? "Tennis workout recovered." : "Training restored without an active Health workout."
        } catch {
            guard token == generation else { return }
            state = .recordingWithoutHealth
            message = "Health workout recovery failed. Tennis tracking continues."
        }
    }

    func finish(at date: Date = Date()) async -> TennisWorkoutResult? {
        guard state == .recording || state == .recordingWithoutHealth else { return nil }
        let token = generation
        let hasHealth = state == .recording
        state = .finishing
        defer { if token == generation { state = .finished } }
        if hasHealth {
            do {
                let result = try await client.finish(at: date)
                guard token == generation else { return nil }
                message = result.workoutID == nil
                    ? "Tennis workout saved. Its Health identifier is not yet available."
                    : "Tennis workout saved."
                return result
            } catch {
                guard token == generation else { return nil }
                message = "Training saved. The Health workout could not be saved."
            }
        } else { message = "Training saved without Health data." }
        return TennisWorkoutResult(durationSeconds: max(0, date.timeIntervalSince(startedAt ?? date)))
    }
}

struct TennisMotionSample: Codable, Equatable {
    var timestamp: TimeInterval
    var accelerationX: Double
    var accelerationY: Double
    var accelerationZ: Double
    var rotationX: Double
    var rotationY: Double
    var rotationZ: Double
}

struct TennisLabeledMotionSession: Codable, Equatable {
    var activityID: UUID
    var trainingType: TrainingType
    var startedAt: Date
    var samples: [TennisMotionSample]
    // A training label is supplied by the player, never an inferred stroke classification.
    var labelSource = "Player-selected training type"
}
