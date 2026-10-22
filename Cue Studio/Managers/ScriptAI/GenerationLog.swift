//
//  GenerationLog.swift
//  Cue Studio
//

import Foundation
import os

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
}
