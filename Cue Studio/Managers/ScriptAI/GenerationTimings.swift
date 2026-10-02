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

/// The one log line of a request, in Console under subsystem `studio.cue`, category `Generation`:
/// `prepare`, `first`, `generate` (the model), `ui` (creating the script and showing it) and
/// `total` (from the tap), plus the words asked for and written. Durations in seconds.
nonisolated enum GenerationLog {
    private static let logger = Logger(subsystem: "studio.cue", category: "Generation")

    static func report(
        timings: GenerationTimings?, ui: Duration, total: Duration, requestedWords: ClosedRange<Int>, writtenWords: Int
    ) {
        let prepare = timings?.prepare.inSeconds ?? 0
        let first = timings?.firstResponse?.inSeconds ?? -1
        let generate = timings?.generation.inSeconds ?? 0
        logger.notice("""
            prepare=\(prepare, format: .fixed(precision: 2))s first=\(first, format: .fixed(precision: 2))s \
            generate=\(generate, format: .fixed(precision: 2))s ui=\(ui.inSeconds, format: .fixed(precision: 2))s \
            total=\(total.inSeconds, format: .fixed(precision: 2))s \
            wordsAsked=\(requestedWords.lowerBound)-\(requestedWords.upperBound) wordsWritten=\(writtenWords)
            """)
    }

    /// A request that was asked for again while one was running, or one that was cancelled or failed.
    static func note(_ event: String) {
        logger.notice("\(event, privacy: .public)")
    }
}
