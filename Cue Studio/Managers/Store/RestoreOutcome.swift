//
//  RestoreOutcome.swift
//  Cue Studio
//

import Foundation

/// What Restore purchases came to: said once, as a toast, wherever it was tapped.
nonisolated enum RestoreOutcome: Equatable, Sendable {
    /// Pro is active again.
    case restored
    /// The App Store answered, and this Apple Account has no Cue Pro.
    case nothing
    /// The App Store couldn't be asked (offline, or it failed): its message, never "No purchases".
    case failed(String)

    var message: String {
        switch self {
        case .restored: String(localized: "Purchases restored")
        case .nothing: String(localized: "No purchases to restore")
        case .failed(let message): message
        }
    }

    var isRestored: Bool { self == .restored }
}
