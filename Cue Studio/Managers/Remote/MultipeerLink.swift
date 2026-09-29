//
//  MultipeerLink.swift
//  Cue Studio
//

import Foundation
import MultipeerConnectivity

/// One Multipeer Connectivity session between the teleprompter and a remote, over Wi-Fi or
/// Bluetooth, with no network or account needed. The teleprompter advertises its pairing code; the
/// remote looks for that code and asks to join with it, and only then is it let in. One remote at a
/// time. Encrypted.
///
/// Multipeer calls its delegates on its own queues, so this lives outside the main actor. It is
/// `@unchecked Sendable` because everything it holds is set in `init` and never replaced, and the
/// Multipeer objects may be used from any thread.
nonisolated final class MultipeerLink: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate,
    MCNearbyServiceBrowserDelegate, @unchecked Sendable {
    /// Also listed under NSBonjourServices in Info.plist (`_cue-remote._tcp`, `_cue-remote._udp`).
    static let serviceType = "cue-remote"
    private static let codeKey = "code"

    private let code: String
    private let codeData: Data
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser?
    private let browser: MCNearbyServiceBrowser?
    private let onEvent: @Sendable (RemoteTransportEvent) -> Void

    /// `hosting`: the teleprompter side. Otherwise the remote.
    init(hosting: Bool, code: String, deviceName: String, onEvent: @escaping @Sendable (RemoteTransportEvent) -> Void) {
        let peer = MCPeerID(displayName: deviceName)
        self.code = code
        codeData = Data(code.utf8)
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        if hosting {
            advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: [Self.codeKey: code], serviceType: Self.serviceType)
            browser = nil
        } else {
            advertiser = nil
            browser = MCNearbyServiceBrowser(peer: peer, serviceType: Self.serviceType)
        }
        self.onEvent = onEvent
        super.init()
        session.delegate = self
        advertiser?.delegate = self
        browser?.delegate = self
    }

    func start() {
        advertiser?.startAdvertisingPeer()
        browser?.startBrowsingForPeers()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
    }

    func send(_ message: RemoteMessage) {
        let peers = session.connectedPeers
        guard !peers.isEmpty, let data = try? message.encoded() else { return }
        try? session.send(data, toPeers: peers, with: .reliable)
    }

    // MARK: - MCSessionDelegate

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            browser?.stopBrowsingForPeers()
            onEvent(.connected(deviceName: peerID.displayName))
        case .notConnected:
            guard session.connectedPeers.isEmpty else { return }
            // Keep looking, so the remote reconnects on its own when it comes back in range.
            browser?.startBrowsingForPeers()
            onEvent(.disconnected)
        case .connecting:
            break
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? RemoteMessage.decoded(from: data) else { return }
        onEvent(.received(message))
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {}

    // MARK: - MCNearbyServiceAdvertiserDelegate

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Only the device that has this code, and only one at a time.
        let accepts = context == codeData && session.connectedPeers.isEmpty
        invitationHandler(accepts, accepts ? session : nil)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        onEvent(.failed(Self.localNetworkMessage))
    }

    // MARK: - MCNearbyServiceBrowserDelegate

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard info?[Self.codeKey] == code, session.connectedPeers.isEmpty else { return }
        browser.invitePeer(peerID, to: session, withContext: codeData, timeout: 20)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        onEvent(.failed(Self.localNetworkMessage))
    }

    /// Multipeer fails to start when the creator turned off Local Network for Cue.
    private static var localNetworkMessage: String {
        String(localized: "Cue can't reach nearby devices. Turn on Local Network for Cue in Settings.")
    }
}
