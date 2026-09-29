//
//  VoiceFollowingAvailability.swift
//  Cue Studio
//

import Foundation

/// Whether Voice Following can follow the words in a language on this device, as the Speech
/// framework answers it. Shown next to each language in Language & Region.
nonisolated enum VoiceFollowingAvailability: Equatable, Sendable {
    /// Its speech model is on the device.
    case ready
    /// Supported; the model downloads the first time it's used.
    case downloadsOnFirstUse
    /// No speech recognition for it here.
    case unavailable

    var label: String {
        switch self {
        case .ready: String(localized: "Ready on this iPhone")
        case .downloadsOnFirstUse: String(localized: "Downloads the first time you use it")
        case .unavailable: String(localized: "Not available on this iPhone")
        }
    }
}
