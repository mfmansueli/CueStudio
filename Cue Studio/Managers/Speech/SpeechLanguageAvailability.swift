//
//  SpeechLanguageAvailability.swift
//  Cue Studio
//

import Foundation

/// Whether this device can listen in a language, as Apple's speech framework reports it. Checked on
/// the device every time, never assumed from a list.
nonisolated enum SpeechLanguageAvailability: Equatable, Sendable {
    /// The on-device model is installed.
    case ready
    /// Supported; the model downloads the first time Voice Following uses it.
    case downloadable
    /// No on-device recognition for this language here.
    case unavailable

    var isSupported: Bool { self != .unavailable }

    var label: String {
        switch self {
        case .ready: String(localized: "Ready on this iPhone")
        case .downloadable: String(localized: "Downloads the first time you use it")
        case .unavailable: String(localized: "Not available on this iPhone")
        }
    }
}
