import Foundation
import HealthKit
import Combine

@MainActor
final class WatchHealthWorkout: NSObject, ObservableObject, TennisWorkoutClient, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var ending: CheckedContinuation<TennisWorkoutResult, Error>?
    private var finishTimeout: Task<Void, Never>?
    private var finishing = false
    @Published private(set) var latestHeartRate: Double?
    @Published private(set) var activeEnergy: Double?

    var available: Bool {
        Bundle.main.object(forInfoDictionaryKey: "TennisHealthEnabled") as? Bool == true && HKHealthStore.isHealthDataAvailable()
    }

    func clearMetrics() {
        latestHeartRate = nil
        activeEnergy = nil
    }

    func requestPermission() async throws -> Bool {
        guard available else { return false }
        let workout = HKObjectType.workoutType()
        let read: Set<HKObjectType> = [HKObjectType.quantityType(forIdentifier: .heartRate)!, HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!]
        try await healthStore.requestAuthorization(toShare: [workout], read: read)
        return healthStore.authorizationStatus(for: workout) == .sharingAuthorized
    }

    func begin(at date: Date) async throws {
        guard session == nil else { throw WorkoutError.alreadyRunning }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .tennis
        configuration.locationType = .unknown
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        self.session = session
        self.builder = builder
        finishing = false
        latestHeartRate = nil
        activeEnergy = nil
        session.startActivity(with: date)
        do { try await builder.beginCollection(at: date) }
        catch {
            session.end()
            builder.discardWorkout()
            self.session = nil; self.builder = nil
            throw error
        }
    }

    func finish(at date: Date) async throws -> TennisWorkoutResult {
        guard let session, builder != nil, ending == nil else { throw WorkoutError.notRunning }
        return try await withCheckedThrowingContinuation { continuation in
            ending = continuation
            session.stopActivity(with: date)
            finishTimeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: 30_000_000_000) }
                catch { return }
                guard let self, self.ending != nil else { return }
                self.failWorkout(WorkoutError.saveTimedOut)
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .stopped else { return }
        Task { @MainActor in
            guard self.session === workoutSession else { return }
            await self.saveEndedWorkout(at: date)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            guard self.session === workoutSession else { return }
            self.failWorkout(error)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            guard self.builder === workoutBuilder else { return }
            if let type = HKQuantityType.quantityType(forIdentifier: .heartRate),
               let quantity = workoutBuilder.statistics(for: type)?.mostRecentQuantity() {
                self.latestHeartRate = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }
            if let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               let quantity = workoutBuilder.statistics(for: type)?.sumQuantity() {
                self.activeEnergy = quantity.doubleValue(for: .kilocalorie())
            }
        }
    }

    private func saveEndedWorkout(at date: Date) async {
        guard let builder, !finishing else { return }
        finishing = true
        do {
            try await builder.endCollection(at: date)
            let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let average = builder.statistics(for: heartType)?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let energy = builder.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
            let workout = try await builder.finishWorkout()
            guard self.builder === builder else { return }
            // A successful save may return no sample while the Watch is locked.
            ending?.resume(returning: TennisWorkoutResult(workoutID: workout?.uuid, durationSeconds: workout?.duration ?? builder.elapsedTime, averageHeartRate: average, activeEnergyKcal: energy))
        } catch {
            guard self.builder === builder else { return }
            ending?.resume(throwing: error)
        }
        finishTimeout?.cancel()
        finishTimeout = nil
        ending = nil
        session?.end()
        self.session = nil; self.builder = nil
    }

    private func failWorkout(_ error: Error) {
        finishTimeout?.cancel()
        finishTimeout = nil
        ending?.resume(throwing: error)
        ending = nil
        let previousSession = session
        builder?.discardWorkout()
        builder = nil
        session = nil
        previousSession?.end()
    }

    private enum WorkoutError: Error { case alreadyRunning, notRunning, saveTimedOut }
}
