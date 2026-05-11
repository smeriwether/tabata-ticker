import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivity: NSObject, WCSessionDelegate {
    var onState: ((TabataState) -> Void)?

    func activate() {
        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()

        if let state = TabataState.fromPayloadDictionary(session.receivedApplicationContext) {
            onState?(state)
        }
    }

    func send(_ command: WatchCommandPayload) {
        guard WCSession.isSupported() else {
            return
        }

        let payload = command.payloadDictionary()
        let session = WCSession.default

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message)
    }

    private nonisolated func receive(_ dictionary: [String: Any]) {
        guard let state = TabataState.fromPayloadDictionary(dictionary) else {
            return
        }

        Task { @MainActor in
            onState?(state)
        }
    }
}
