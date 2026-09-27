//
//  ScriptAIError.swift
//  Cue Studio
//

import Foundation

nonisolated enum ScriptAIError: LocalizedError, Sendable {
    case modelUnavailable(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason): reason
        case .emptyResponse: String(localized: "The model didn't return any text. Try again.")
        }
    }
}
