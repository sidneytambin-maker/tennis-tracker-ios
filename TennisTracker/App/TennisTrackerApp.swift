import SwiftUI
import UserNotifications
import UIKit

extension Notification.Name {
    static let tennisTrackerOpenURL = Notification.Name("tennisTrackerOpenURL")
}

final class TennisTrackerAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let urlText = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: urlText) else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .tennisTrackerOpenURL, object: url)
        }
    }
}

@main
struct TennisTrackerApp: App {
    @UIApplicationDelegateAdaptor(TennisTrackerAppDelegate.self) private var appDelegate
    @StateObject private var store = TennisStore()

    var body: some Scene {
        WindowGroup {
            TennisTrackerRootView()
                .environmentObject(store)
                .onAppear {
                    IPhoneWatchSyncService.shared.configure(store: store)
                }
        }
    }
}
