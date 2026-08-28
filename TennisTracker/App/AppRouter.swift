import Foundation

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab = "dashboard"
    @Published var targetID: UUID?

    func open(_ url: URL) {
        guard url.scheme == "tennistracker" else { return }
        let host = url.host?.lowercased()
        let idText = url.pathComponents.dropFirst().first
        targetID = idText.flatMap(UUID.init(uuidString:))

        switch host {
        case "match", "live":
            selectedTab = "matches"
        case "training":
            selectedTab = "training"
        case "tournament":
            selectedTab = "tournaments"
        case "player":
            selectedTab = "player"
        case "settings":
            selectedTab = "settings"
        default:
            selectedTab = "dashboard"
        }
    }
}
