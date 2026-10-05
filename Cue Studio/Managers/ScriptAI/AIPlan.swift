//
//  AIPlan.swift
//  Cue Studio
//

import Foundation

/// Which model runs a request, decided before anything is sent: the one tried first, and the ones it
/// may fall back to. A model that doesn't write the request's languages is in neither, so no request
/// goes to a model already known to refuse it.
nonisolated struct AIPlan: Equatable, Sendable {
    let route: AIModelRoute
    /// Every model that is available and writes all the languages of the request.
    let usable: Set<AIModelRoute>

    /// Where a request that failed on `model` may try again: the model's own fallback, when the plan
    /// knows it is available and writes the languages (never one already known to refuse the request).
    func fallback(from model: AIModelRoute, after failure: AIFailure) -> AIModelRoute? {
        model.fallback(after: failure).flatMap { usable.contains($0) ? $0 : nil }
    }
}
