//
//  MultipeerRemoteTransport.swift
//  Cue Studio
//

import UIKit

/// The remote link over Multipeer Connectivity (see `MultipeerLink`). Each pairing starts a new
/// link; events from one that was replaced are dropped.
final class MultipeerRemoteTransport: RemoteTransport {
    var onEvent: ((RemoteTransportEvent) -> Void)?

    private var link: MultipeerLink?
    private var linkID: UUID?

    func host(code: String) {
        start(hosting: true, code: code)
    }

    func join(code: String) {
        start(hosting: false, code: code)
    }

    func send(_ message: RemoteMessage) {
        link?.send(message)
    }

    func stop() {
        link?.stop()
        link = nil
        linkID = nil
    }

    private func start(hosting: Bool, code: String) {
        stop()
        let id = UUID()
        let link = MultipeerLink(hosting: hosting, code: code, deviceName: UIDevice.current.name) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.linkID == id else { return }
                self.onEvent?(event)
            }
        }
        self.link = link
        linkID = id
        link.start()
    }
}
