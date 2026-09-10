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
    private var generation = UUID()
    @Published private(set) var latestHeartRate: Double?
    @Published private(set) var activeEnergy: Double?
    @Published private(set) var distanceMeters: Double?
    @Published private(set) var stepCount: Double?
    @Published private(set) var statusMessage = ""

    var activeTrainingID: UUID? {
        UserDefaults.standard.string(forKey: "activeHealthTrainingID").flatMap(UUID.init(uuidString:))
    }

    var pendingWorkoutIDs: [UUID] {
        (UserDefaults.standard.stringArray(forKey: "pendingHealthTrainingIDs") ?? []).compactMap(UUID.init(uuidString:))
    }

    func acknowledgeSavedWorkout(_ id: UUID) {
        UserDefaults.standard.set(pendingWorkoutIDs.filter { $0 != id }.map(\.uuidString), forKey: "pendingHealthTrainingIDs")
        if activeTrainingID == id { UserDefaults.standard.removeObject(forKey: "activeHealthTrainingID") }
    }

    var accessDescription: String {
        guard available else { return "Unavailable in this build" }
        switch healthStore.authorizationStatus(for: .workoutType()) {
        case .sharingAuthorized: return "Workout saving allowed"
        case .sharingDenied: return "Workout saving not allowed"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }

    var available: Bool {
        Bundle.main.object(forInfoDictionaryKey: "TennisHealthEnabled") as? Bool == true && HKHealthStore.isHealthDataAvailable()
    }

    func clearMetrics() {
        latestHeartRate = nil
        activeEnergy = nil
        distanceMeters = nil
        stepCount = nil
        statusMessage = ""
    }

    func discardForLibraryChange() {
        generation = UUID()
        failWorkout(WorkoutError.notRunning)
        clearMetrics()
    }

    func requestPermission() async throws -> Bool {
        guard available else { return false }
        let workout = HKObjectType.workoutType()
        let heart = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let distance = HKQuantityType(.distanceWalkingRunning)
        let steps = HKQuantityType(.stepCount)
        let read: Set<HKObjectType> = [workout, heart, energy, distance, steps]
        try await healthStore.requestAuthorization(toShare: [workout, heart, energy, distance, steps], read: read)
        return healthStore.authorizationStatus(for: workout) == .sharingAuthorized
    }

    func begin(activityID: UUID, at date: Date) async throws {
        guard session == nil else { throw WorkoutError.alreadyRunning }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .tennis
        configuration.locationType = .unknown
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        session.delegate = self
        builder.delegate = self
        builder.dataSource = dataSource(configuration: configuration)
        self.session = session
        self.builder = builder
        finishing = false
        latestHeartRate = nil
        activeEnergy = nil
        distanceMeters = nil
        stepCount = nil
        statusMessage = "Starting tennis workout."
        UserDefaults.standard.set(activityID.uuidString, forKey: "activeHealthTrainingID")
        UserDefaults.standard.set(Array(Set(pendingWorkoutIDs + [activityID])).map(\.uuidString), forKey: "pendingHealthTrainingIDs")
        session.startActivity(with: date)
        do {
            try await builder.addMetadata([HKMetadataKeyExternalUUID: activityID.uuidString])
            guard self.session === session else { throw WorkoutError.notRunning }
            try await builder.beginCollection(at: date)
            guard self.session === session else { throw WorkoutError.notRunning }
            statusMessage = "Tennis workout active."
        }
        catch {
            session.end()
            builder.discardWorkout()
            guard self.session === session else { throw error }
            self.session = nil; self.builder = nil
            UserDefaults.standard.removeObject(forKey: "activeHealthTrainingID")
            acknowledgeSavedWorkout(activityID)
            statusMessage = "Health workout could not start. Tennis tracking continues."
            throw error
        }
    }

    func recover(activityID: UUID) async throws -> Bool {
        guard available, activeTrainingID == activityID else { return false }
        let token = generation
        if session != nil { return true }
        guard let recovered = try await healthStore.recoverActiveWorkoutSession(),
              recovered.state == .running || recovered.state == .paused else { return false }
        guard generation == token, activeTrainingID == activityID else {
            recovered.associatedWorkoutBuilder().discardWorkout()
            recovered.end()
            return false
        }
        session = recovered
        builder = recovered.associatedWorkoutBuilder()
        recovered.delegate = self
        builder?.delegate = self
        builder?.dataSource = dataSource(configuration: recovered.workoutConfiguration)
        finishing = false
        statusMessage = "Tennis workout recovered."
        return true
    }

    func savedWorkout(activityID: UUID) async throws -> TennisWorkoutResult? {
        guard available else { return nil }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID, allowedValues: [activityID.uuidString]),
            HKQuery.predicateForObjects(from: HKSource.default())
        ])
        let workout: HKWorkout? = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples?.first as? HKWorkout) }
            }
            healthStore.execute(query)
        }
        guard let workout else { return nil }
        return TennisWorkoutResult(workoutID: workout.uuid, durationSeconds: workout.duration,
            averageHeartRate: workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
            activeEnergyKcal: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
            peakHeartRate: workout.statistics(for: HKQuantityType(.heartRate))?.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
            distanceMeters: workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter()),
            stepCount: workout.statistics(for: HKQuantityType(.stepCount))?.sumQuantity()?.doubleValue(for: .count()))
    }

    func finish(at date: Date) async throws -> TennisWorkoutResult {
        guard let session, builder != nil, ending == nil else { throw WorkoutError.notRunning }
        return try await withCheckedThrowingContinuation { continuation in
            ending = continuation
            statusMessage = "Saving tennis workout."
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
            self.distanceMeters = workoutBuilder.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter())
            self.stepCount = workoutBuilder.statistics(for: HKQuantityType(.stepCount))?.sumQuantity()?.doubleValue(for: .count())
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
            let peak = builder.statistics(for: heartType)?.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let distance = builder.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter())
            let steps = builder.statistics(for: HKQuantityType(.stepCount))?.sumQuantity()?.doubleValue(for: .count())
            let workout = try await builder.finishWorkout()
            guard self.builder === builder else { return }
            // A successful save may return no sample while the Watch is locked.
            ending?.resume(returning: TennisWorkoutResult(workoutID: workout?.uuid, durationSeconds: workout?.duration ?? builder.elapsedTime,
                averageHeartRate: average, activeEnergyKcal: energy, peakHeartRate: peak, distanceMeters: distance, stepCount: steps))
            statusMessage = workout == nil ? "Health save completed. Workout link pending." : "Tennis workout saved."
        } catch {
            guard self.builder === builder else { return }
            ending?.resume(throwing: error)
        }
        finishTimeout?.cancel()
        finishTimeout = nil
        ending = nil
        UserDefaults.standard.removeObject(forKey: "activeHealthTrainingID")
        session?.end()
        self.session = nil; self.builder = nil
    }

    private func failWorkout(_ error: Error) {
        statusMessage = "Health workout interrupted. Tennis tracking continues."
        finishTimeout?.cancel()
        finishTimeout = nil
        ending?.resume(throwing: error)
        ending = nil
        let previousSession = session
        builder?.discardWorkout()
        builder = nil
        session = nil
        UserDefaults.standard.removeObject(forKey: "activeHealthTrainingID")
        previousSession?.end()
    }

    private enum WorkoutError: Error { case alreadyRunning, notRunning, saveTimedOut }

    private func dataSource(configuration: HKWorkoutConfiguration) -> HKLiveWorkoutDataSource {
        let source = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        // Use actual Watch samples in this workout, never daily totals or estimated steps.
        let watchSamples = HKQuery.predicateForObjects(from: Set([HKDevice.local()]))
        source.enableCollection(for: HKQuantityType(.distanceWalkingRunning), predicate: watchSamples)
        source.enableCollection(for: HKQuantityType(.stepCount), predicate: watchSamples)
        return source
    }
}
