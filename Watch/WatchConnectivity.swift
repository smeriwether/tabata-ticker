import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivity: NSObject, WCSessionDelegate {
    var onState: ((TabataState) -> Void)?
    var onCatalog: ((TabataPresetCatalog) -> Void)?

    func activate() {
        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        deliver(session.receivedApplicationContext)
    }

    func send(_ command: WatchCommandPayload) {
        guard WCSession.isSupported() else {
            return
        }

        let payload = command.payloadDictionary()
        let session = WCSession.default

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
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

    // Decoded before hopping to the main actor, because the payload dictionary itself is not Sendable.
    private nonisolated func receive(_ dictionary: [String: Any]) {
        guard let state = TabataState.fromPayloadDictionary(dictionary) else {
            return
        }

        let catalog = TabataState.catalogFromPayloadDictionary(dictionary)

        Task { @MainActor in
            apply(state: state, catalog: catalog)
        }
    }

    private func deliver(_ dictionary: [String: Any]) {
        guard let state = TabataState.fromPayloadDictionary(dictionary) else {
            return
        }

        apply(state: state, catalog: TabataState.catalogFromPayloadDictionary(dictionary))
    }

    // A phone that predates preset syncing sends the state on its own, so the catalog is optional.
    private func apply(state: TabataState, catalog: TabataPresetCatalog?) {
        onState?(state)

        if let catalog {
            onCatalog?(catalog)
        }
    }
}
