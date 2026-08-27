import SwiftUI

@main
struct TennisTrackerApp: App {
    @StateObject private var store = TennisStore()

    var body: some Scene {
        WindowGroup {
            TennisTrackerRootView()
                .environmentObject(store)
        }
    }
}
