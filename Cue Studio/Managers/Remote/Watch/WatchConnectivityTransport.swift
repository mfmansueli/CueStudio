//
//  WatchConnectivityTransport.swift
//  Cue Studio
//

import Foundation
import WatchConnectivity

/// The iPhone's side of WatchConnectivity. Commands arrive with a reply handler and are answered with the state they led
/// to; every new state goes as a message while the watch is in reach and as the application context, which the watch reads
/// when it opens. Nothing happens on an iPhone without a paired watch.
final class WatchConnectivityTransport: NSObject, WatchTransport {
    var onCommand: ((WatchCommand) -> WatchPhoneState)?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ state: WatchPhoneState) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let message = WatchMessage.encode(state)
        try? session.updateApplicationContext(message)
        if session.isReachable { session.sendMessage(message, replyHandler: nil) }
    }

    fileprivate func answer(_ command: WatchCommand) -> [String: Any] {
        WatchMessage.encode(onCommand?(command) ?? .noSession)
    }
}

extension WatchConnectivityTransport: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Another watch was paired: the session is activated again for it.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let command = WatchMessage.command(in: message) else {
            replyHandler([:])
            return
        }
        let reply = UncheckedReply(send: replyHandler)
        Task { @MainActor [weak self] in
            reply.send(self?.answer(command) ?? WatchMessage.encode(.noSession))
        }
    }
}

/// WatchConnectivity's reply handler, carried to the main actor: it may be called from any thread, once.
private nonisolated struct UncheckedReply: @unchecked Sendable {
    let send: ([String: Any]) -> Void
}
