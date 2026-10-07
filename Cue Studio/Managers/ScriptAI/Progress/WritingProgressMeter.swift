//
//  WritingProgressMeter.swift
//  Cue Studio
//

import Foundation

/// The percentage of one script being written: the writer tells it what it is doing (`ScriptWritingEvent`), the star and the page's pill read
/// it (`WritingProgressLabel`). One per request; the math is `WritingProgressEstimate`.
@MainActor
@Observable
final class WritingProgressMeter {
    private(set) var estimate: WritingProgressEstimate
    private let clock: () -> TimeInterval

    /// - Parameter now: the time in seconds; the real one by default, tests move their own.
    init(expectedWords: Int, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        estimate = WritingProgressEstimate(expectedWords: expectedWords)
        clock = now
    }

    /// A meter for `request`, expecting the fewest words the creator asked for (what the model writes, about).
    convenience init(for request: ScriptRequest) {
        self.init(expectedWords: ReadTime.words(for: request.targetRange.lowerBound))
    }

    var isFinished: Bool { estimate.isFinished }

    /// How much is written now, 0…1.
    var fraction: Double { estimate.fraction(at: clock()) }

    func record(_ event: ScriptWritingEvent) {
        estimate.record(event, at: clock())
    }

    /// The script is there: 100%.
    func finish() {
        estimate.finish()
    }
}
