//
//  RemoteConnectionState.swift
//  Cue Studio
//

import Foundation

/// The remote link, as the creator sees it.
nonisolated enum RemoteConnectionState: Hashable, Sendable {
    case off
    /// The teleprompter shows its code and waits for the other device.
    case waiting
    /// The remote looks for the teleprompter with the code it was given.
    case searching
    case connected(deviceName: String)
    case failed(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    /// The other device's name while connected.
    var deviceName: String? {
        if case .connected(let name) = self { return name }
        return nil
    }

    /// "Remote Connected", "Waiting for your other device…"
    var label: String {
        switch self {
        case .off: String(localized: "Not connected")
        case .waiting: String(localized: "Waiting for your other device…")
        case .searching: String(localized: "Looking for the teleprompter…")
        case .connected: String(localized: "Remote Connected")
        case .failed(let message): message
        }
    }
}
