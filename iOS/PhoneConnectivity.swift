import Foundation
import WatchConnectivity

@MainActor
final class PhoneConnectivity: NSObject, WCSessionDelegate {
    var onCommand: ((WatchCommandPayload) -> Void)?

    func activate() {
        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ state: TabataState) {
        guard WCSession.isSupported() else {
            return
        }

        let payload = state.payloadDictionary()
        let session = WCSession.default
        try? session.updateApplicationContext(payload)

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        receive(userInfo)
    }

    private nonisolated func receive(_ dictionary: [String: Any]) {
        guard let command = WatchCommandPayload.fromPayloadDictionary(dictionary) else {
            return
        }

        Task { @MainActor in
            onCommand?(command)
        }
    }
}
