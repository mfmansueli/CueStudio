//
//  UltraClientError.swift
//  Cue Studio
//

import Foundation

/// A failed Gemini call as a client reports it (`UltraModelClient`): only its kind, never the provider's message, which can quote the request.
nonisolated struct UltraClientError: Error, Equatable, Sendable {
    let failure: UltraFailure
}
