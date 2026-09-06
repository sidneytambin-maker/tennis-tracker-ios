import SwiftUI
import WatchKit

@main
struct TennisTrackerWatchApp: App {
    @WKApplicationDelegateAdaptor(TennisWatchDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

final class TennisWatchDelegate: NSObject, WKApplicationDelegate {
    func handleActiveWorkoutRecovery() {
        NotificationCenter.default.post(name: .tennisWorkoutRecovery, object: nil)
    }
}

extension Notification.Name {
    static let tennisWorkoutRecovery = Notification.Name("tennisWorkoutRecovery")
}
