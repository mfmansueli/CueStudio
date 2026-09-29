//
//  RemoteTransportEvent.swift
//  Cue Studio
//

import Foundation

/// What the link between the teleprompter and its remote reports.
nonisolated enum RemoteTransportEvent: Sendable {
    case connected(deviceName: String)
    /// The other device left; the link keeps looking so it can come back.
    case disconnected
    case received(RemoteMessage)
    case failed(String)
}
