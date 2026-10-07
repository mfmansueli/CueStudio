//
//  GenerationDeadlines.swift
//  Cue Studio
//

import Foundation

/// When a request to the model is given up on. Measured on an iPhone 15 Pro, a request could sit for ever (the model busy with something else, a stream
/// that stopped): the star waited for a script that never came and only Cancel ended it. Now silence has a limit: the first words have to start within
/// `firstResponse`, no more than `betweenResponses` may pass without new words, and the whole request is over by `overall`. What had arrived by then
/// is used when it is a script; otherwise the request is tried once more and then the creator is told.
nonisolated struct GenerationDeadlines: Equatable, Sendable {
    /// From the request to the first words (the model may have to load: a cold start takes a while on an older iPhone).
    var firstResponse: Duration = .seconds(40)
    /// Between two arrivals of words.
    var betweenResponses: Duration = .seconds(20)
    /// From the request to the end, whatever keeps arriving.
    var overall: Duration = .seconds(110)

    static let standard = GenerationDeadlines()

    /// Whether a request that started `elapsed` ago, and last made progress `sinceProgress` ago, should be given up on.
    func isStalled(elapsed: Duration, sinceProgress: Duration, hasResponded: Bool) -> Bool {
        if elapsed >= overall { return true }
        return sinceProgress >= (hasResponded ? betweenResponses : firstResponse)
    }
}
