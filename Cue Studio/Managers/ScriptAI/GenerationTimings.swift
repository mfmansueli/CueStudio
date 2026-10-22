//
//  GenerationTimings.swift
//  Cue Studio
//

import Foundation
import os

/// Where the time of one script request went, on the model's side: choosing the model and building
/// the request, then sending it, the first words coming back, and the last. Measured by
/// `ScriptAIService`; the view model adds what happens after (creating the script) and logs the
/// whole with `report`. Only durations and word counts are kept, never what the creator wrote or
/// what came back.
nonisolated struct GenerationTimings: Hashable, Sendable {
    /// Choosing the model (availability), building the instructions and the prompt, opening the session.
    var prepare: Duration
    /// From sending the request to the first words coming back; nil when none came.
    var firstResponse: Duration?
    /// From sending the request to the last word.
    var generation: Duration
}

nonisolated extension Duration {
    /// The duration in seconds, for logs.
    var inSeconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
