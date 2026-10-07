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
    /// A translation needs both languages: Apple Intelligence doesn't cover the one named (`source`,
    /// `target`: the languages' names, the unsupported one among them).
    case unsupportedTranslation(source: String, target: String)
    /// The model is still downloading or getting ready.
    case modelPreparing
    /// What came back wasn't in the language it should have been; nothing was changed.
    case wrongLanguage
    /// The model asks for a rest: too many requests lately.
    case rateLimited
    /// The model went quiet: no words arrived in time (`GenerationDeadlines`), on two tries.
    case timedOut
    /// The model won't work on this text (its guardrails or a refusal).
    case declined

    /// Its message already tells the creator what is wrong and what to do (another language, wait,
    /// shorten); the others ("couldn't write it") are for Try again.
    var explainsItself: Bool {
        switch self {
        case .emptyResponse: false
        case .modelUnavailable, .tooLong, .unsupportedLanguage, .unsupportedTranslation, .modelPreparing, .wrongLanguage, .rateLimited, .timedOut,
             .declined: true
        }
    }

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason): reason
        case .emptyResponse: String(localized: "The model didn't return any text. Try again.")
        case .tooLong: String(localized: "Too long for Apple Intelligence on this iPhone. Try a shorter script, or one part at a time.")
        case .unsupportedLanguage: String(localized: "Apple Intelligence can't write in this script's language yet.")
        case .unsupportedTranslation(let source, let target):
            String(localized: "Apple Intelligence can’t translate between \(source) and \(target) yet.")
        case .modelPreparing: String(localized: "Apple Intelligence is still getting ready. Try again in a few minutes.")
        case .rateLimited: String(localized: "Apple Intelligence needs a short break. Try again in a few minutes.")
        case .timedOut: String(localized: "Apple Intelligence is taking too long. Try again in a moment.")
        case .wrongLanguage: String(localized: "The result wasn’t in the right language, so your script is unchanged. Try again.")
        case .declined: String(localized: "Apple Intelligence won’t work on this text. Try rewording it, or use another tool.")
        }
    }
}
