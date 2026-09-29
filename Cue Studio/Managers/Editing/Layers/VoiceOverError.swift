//
//  VoiceOverError.swift
//  Cue Studio
//

import Foundation

nonisolated enum VoiceOverError: LocalizedError {
    case couldNotRecord

    var errorDescription: String? {
        switch self {
        case .couldNotRecord: String(localized: "Couldn't start recording")
        }
    }
}
