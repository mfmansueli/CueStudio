//
//  AIPlanFailure+Error.swift
//  Cue Studio
//

import Foundation

nonisolated extension AIPlanFailure {
    /// The failure in Cue's words. `translation` names both languages of a translation, so the message
    /// says which pair Apple Intelligence can't do instead of a single language.
    func error(translation: (source: String, target: String)? = nil) -> ScriptAIError {
        switch self {
        case .deviceNotSupported: .modelUnavailable(AIModelStatus.deviceNotEligible.reason)
        case .turnedOff: .modelUnavailable(AIModelStatus.turnedOff.reason)
        case .modelPreparing: .modelPreparing
        case .unsupportedLanguage:
            if let translation { .unsupportedTranslation(source: translation.source, target: translation.target) } else { .unsupportedLanguage }
        }
    }
}
