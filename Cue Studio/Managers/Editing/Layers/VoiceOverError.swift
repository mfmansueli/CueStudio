//
//  VoiceOverError.swift
//  Cue Studio
//

import Foundation

nonisolated enum VoiceOverError: LocalizedError {
    case couldNotRecord
    /// The recording stopped because its file couldn't be written.
    case couldNotWrite

    var errorDescription: String? {
        switch self {
        case .couldNotRecord: String(localized: "Couldn't start recording")
        case .couldNotWrite: String(localized: "Couldn't record the voice-over · Try again")
        }
    }
}
