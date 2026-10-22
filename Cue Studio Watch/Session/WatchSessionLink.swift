//
//  WatchSessionLink.swift
//  Cue Studio Watch
//

import Foundation
import WatchConnectivity

/// The watch's side of WatchConnectivity: sends a command and hands back the iPhone's answer, and passes on every state the
/// iPhone sends (as a message while in reach, as the application context otherwise).
final class WatchSessionLink: NSObject {
    /// A state from the iPhone, and whether the iPhone can be reached now.
    var onState: ((WatchPhoneState) -> Void)?
    var onReachability: ((Bool) -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var isReachable: Bool { WCSession.isSupported() && WCSession.default.isReachable }

    /// The iPhone's last state, kept by the system for when the app opens.
    var lastContext: WatchPhoneState? {
        WatchMessage.state(in: WCSession.default.receivedApplicationContext)
    }

    /// Sends a command; the answer's state comes through `onState`. False when the iPhone can't be reached.
    @discardableResult
    func send(_ command: WatchCommand) -> Bool {
        guard isReachable else { return false }
        WCSession.default.sendMessage(
            WatchMessage.encode(command),
            replyHandler: { [weak self] reply in
                guard let state = WatchMessage.state(in: reply) else { return }
                Task { @MainActor in self?.onState?(state) }
            },
            errorHandler: { [weak self] _ in
                Task { @MainActor in self?.onReachability?(WCSession.default.isReachable) }
            }
        )
        return true
    }
}

extension WatchSessionLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let reachable = session.isReachable
        let context = WatchMessage.state(in: session.receivedApplicationContext)
        Task { @MainActor [weak self] in
            if let context { self?.onState?(context) }
            self?.onReachability?(reachable)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in self?.onReachability?(reachable) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let state = WatchMessage.state(in: message) else { return }
        Task { @MainActor [weak self] in self?.onState?(state) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let state = WatchMessage.state(in: applicationContext) else { return }
        Task { @MainActor [weak self] in self?.onState?(state) }
    }
}
