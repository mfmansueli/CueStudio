//
//  ScriptFailureNotice.swift
//  Cue Studio
//

import Foundation

/// What a failed AI write says in its toast, and whether the toast carries "Try again": only for a failure asking again may fix (the model
/// came back empty, an Ultra AI call that stopped early), never for one that explains itself (another language, wait, shorten) or that the
/// same request would meet again. The button replaces the "· Try again" the words used to end with.
nonisolated enum ScriptFailureNotice {
    /// The toast's words for `error`.
    static func message(for error: any Error) -> String {
        if let error = error as? UltraError { return error.localizedDescription }
        if let error = error as? ScriptAIError, error.explainsItself { return error.localizedDescription }
        return String(localized: "Couldn’t draft it")
    }

    /// Whether "Try again" goes with it.
    static func isWorthRetrying(_ error: any Error) -> Bool {
        if error is CancellationError { return false }
        if let error = error as? UltraError { return error.isWorthRetrying }
        if let error = error as? ScriptAIError { return !error.explainsItself }
        return true
    }
}
