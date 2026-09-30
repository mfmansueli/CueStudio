//
//  ScriptAIError.swift
//  Cue Studio
//

import Foundation

nonisolated enum ScriptAIError: LocalizedError, Sendable {
    case modelUnavailable(String)
    case emptyResponse
    /// The script doesn't fit in the model's context, and no bigger model could take it.
    case tooLong
    /// Apple Intelligence doesn't write in the script's language, on the device or in the cloud.
    case unsupportedLanguage

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason): reason
        case .emptyResponse: String(localized: "The model didn't return any text. Try again.")
        case .tooLong: String(localized: "Too long for Apple Intelligence on this iPhone. Try a shorter script, or one part at a time.")
        case .unsupportedLanguage: String(localized: "Apple Intelligence can't write in this script's language yet.")
        }
    }
}
