//
//  UltraStageRequest.swift
//  Cue Studio
//

import Foundation

/// Exactly what one of Ultra's calls sends to Gemini: the system instructions and the prompt. "What Cue sends" shows these same values.
nonisolated struct UltraStageRequest: Hashable, Sendable {
    enum Stage: String, Hashable, Sendable {
        /// The developed draft, as plain speech.
        case draft
        /// The draft's claims checked on their own, as JSON (`UltraCheckReply`).
        case check
        /// The polish of that draft, as JSON (`UltraReviewReply`).
        case review
        /// "Fit to time" on a script Ultra wrote, as JSON (`UltraFitReply`, `UltraFitRequest`).
        case fit
        /// Ideas for the library the app holds for a creator without Apple Intelligence (`IdeaLibrary`), written once per language by a developer
        /// tool (`IdeaLibraryDeviceTests`), never by the app for a creator; as JSON (the tool reads it).
        case ideas
    }

    let stage: Stage
    let instructions: String
    let prompt: String
    /// How much the model thinks before answering; set by the service for the whole script (`UltraScriptService.thinking`).
    var thinking = UltraThinking.model

    /// The most the model may answer, thinking included. Generous on purpose: a developed script runs 400–700 words, and a cap the model meets
    /// ends the call without a usable script (`finishedNormally`).
    static let responseTokens = 8_192
    /// A library call answers eighty ideas.
    static let ideaResponseTokens = 32_768
}
