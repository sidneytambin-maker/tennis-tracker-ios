import Foundation
import WatchConnectivity

final class IPhoneWatchSyncService: NSObject, WCSessionDelegate {
    static let shared = IPhoneWatchSyncService()

    private weak var store: TennisStore?
    private let snapshotKey = "snapshotData"
    private let commandKey = "commandData"

    private override init() {}

    @MainActor
    func configure(store: TennisStore) {
        self.store = store
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        sendSnapshot(store.data)
    }

    @MainActor
    func sendSnapshot(_ data: AppData) {
        guard WCSession.isSupported() else { return }
        guard let encoded = try? JSONEncoder.tennisTracker.encode(TennisWatchSnapshot(data: data)) else { return }
        let session = WCSession.default
        try? session.updateApplicationContext([snapshotKey: encoded])
        if session.isReachable {
            session.sendMessageData(encoded, replyHandler: nil)
        } else if session.isPaired && session.isWatchAppInstalled {
            session.transferUserInfo([snapshotKey: encoded])
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        handleCommandData(messageData)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[commandKey] as? Data else { return }
        handleCommandData(data)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[commandKey] as? Data else { return }
        handleCommandData(data)
    }

    private func handleCommandData(_ data: Data) {
        guard let command = try? JSONDecoder.tennisTracker.decode(TennisWatchSyncCommand.self, from: data) else { return }
        Task { @MainActor [weak self] in
            self?.store?.applyWatchCommand(command)
        }
    }
}
