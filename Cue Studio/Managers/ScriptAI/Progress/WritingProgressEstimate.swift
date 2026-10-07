//
//  WritingProgressEstimate.swift
//  Cue Studio
//

import Foundation

/// How much of a script is written, 0…1, from what the writer says it is doing (`ScriptWritingEvent`). Apple Intelligence never says how long
/// the script will be, so this is an estimate, built to never go backwards and to never say 100% before the script is there:
///
/// - Before the first words (the model reads the request: 1.4–1.7 s on an iPhone 15 Pro) it climbs to 5% in 2 s.
/// - The first draft takes it from 5% to at most 85%, by its words against the words expected: the shortest the creator asked for, because the
///   model writes less than it is asked, about that minimum (`DESIGN_PROJECT.md` §4.1). Up to three quarters of those it moves with the words;
///   past them it slows and never arrives, so a script that runs longer than expected doesn't stop on a number.
/// - Whatever comes after (the draft written again, blocks lengthened one by one) is a round of its own that fills 60% of what is left below
///   95%: each one moves less, and none reaches it.
/// - Only the finished script is 100%.
nonisolated struct WritingProgressEstimate: Equatable, Sendable {
    static let preparing = 0.05
    static let preparingTime: TimeInterval = 2
    static let draftEnd = 0.85
    static let ceiling = 0.95
    static let roundShare = 0.6
    /// The share of the expected words up to which the draft moves with them; past it, it slows.
    static let knee = 0.75

    let expectedWords: Int
    private(set) var isFinished = false
    /// When the first draft went out; nil before.
    private var startedAt: TimeInterval?
    /// How many rounds have begun: the first draft is 1.
    private var rounds = 0
    /// Where the current round began (rounds after the first).
    private var roundBase = 0.0
    /// How far the current round is, 0…1.
    private var roundDone = 0.0
    /// The most it has said: nothing it says later is below it.
    private var reached = 0.0

    init(expectedWords: Int) {
        self.expectedWords = max(1, expectedWords)
    }

    mutating func record(_ event: ScriptWritingEvent, at time: TimeInterval) {
        guard !isFinished else { return }
        let now = fraction(at: time)
        switch event {
        case .drafting:
            beginRound(at: time, from: now)
        case .wrote(let words):
            if rounds == 0 { beginRound(at: time, from: now) }
            roundDone = max(roundDone, Self.share(words: words, of: expectedWords))
        case .lengthening(let done, let total):
            // Lengthening starts a round of its own; each block that comes back moves it.
            if rounds == 0 || done == 0 { beginRound(at: time, from: now) }
            roundDone = max(roundDone, total > 0 ? min(1, Double(done) / Double(total)) : 1)
        }
        reached = max(reached, fraction(at: time))
    }

    mutating func finish() {
        isFinished = true
    }

    /// How much is written at `time` (the clock `record` was given).
    func fraction(at time: TimeInterval) -> Double {
        if isFinished { return 1 }
        return min(Self.ceiling, max(reached, current(at: time)))
    }

    private func current(at time: TimeInterval) -> Double {
        guard let startedAt else { return 0 }
        guard rounds > 1 else {
            guard roundDone > 0 else { return Self.preparing * min(1, max(0, time - startedAt) / Self.preparingTime) }
            return Self.preparing + (Self.draftEnd - Self.preparing) * roundDone
        }
        return roundBase + (Self.ceiling - roundBase) * Self.roundShare * roundDone
    }

    private mutating func beginRound(at time: TimeInterval, from now: Double) {
        if startedAt == nil { startedAt = time }
        rounds += 1
        roundBase = now
        roundDone = 0
    }

    /// How far a draft of `words` is when `expected` are expected, 0…1: with the words up to the knee, then slower and slower, never 1.
    static func share(words: Int, of expected: Int) -> Double {
        let ratio = Double(max(0, words)) / Double(max(1, expected))
        guard ratio > knee else { return ratio }
        // The same slope as before the knee, then an exponential approach: continuous, rising, and below 1 for any number of words.
        return 1 - (1 - knee) * exp(-(ratio - knee) / (1 - knee))
    }
}
