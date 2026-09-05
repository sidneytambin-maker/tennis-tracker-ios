import Foundation
import Combine

@MainActor
protocol TennisWorkoutClient: AnyObject {
    var available: Bool { get }
    func requestPermission() async throws -> Bool
    func begin(at date: Date) async throws
    func finish(at date: Date) async throws -> TennisWorkoutResult
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

    init(client: TennisWorkoutClient) { self.client = client }

    func start(useHealth: Bool, at date: Date = Date()) async {
        guard state == .idle || state == .finished else { return }
        startedAt = date
        guard useHealth && client.available else {
            state = .recordingWithoutHealth
            message = useHealth ? "Health is unavailable. Tennis tracking continues." : "Training started."
            return
        }
        state = .authorizing
        do {
            guard try await client.requestPermission() else {
                state = .recordingWithoutHealth
                message = "Health permission was not granted. Tennis tracking continues."
                return
            }
            try await client.begin(at: date)
            state = .recording
            message = "Tennis workout started."
        } catch {
            state = .recordingWithoutHealth
            message = "Health workout could not start. Tennis tracking continues."
        }
    }

    func finish(at date: Date = Date()) async -> TennisWorkoutResult? {
        guard state == .recording || state == .recordingWithoutHealth else { return nil }
        let hasHealth = state == .recording
        state = .finishing
        defer { state = .finished }
        if hasHealth {
            do {
                let result = try await client.finish(at: date)
                message = result.workoutID == nil
                    ? "Tennis workout saved. Its Health identifier is not yet available."
                    : "Tennis workout saved."
                return result
            } catch {
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
