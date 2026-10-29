//
//  UltraFailure.swift
//  Cue Studio
//

import Foundation

/// What went wrong with one Gemini call, by kind only.
nonisolated enum UltraFailure: String, Hashable, Sendable {
    /// No connection.
    case unreachable
    case timedOut
    /// The provider refused the request: App Check, the key, the project's quota or billing.
    case rejected
    /// A safety filter blocked the request or the answer.
    case blocked
    /// The answer stopped early (token cap, a dropped stream), was empty, or wasn't the polish's JSON.
    case incomplete
    /// Anything else the provider said (a 500, "high demand").
    case provider
}
