//
//  VoiceLimits.swift
//  Cue Studio
//

import Foundation

/// How many of each My Cue Voice answer fit (04 · F9): over the limit nothing is added and a toast says "Max {n}".
nonisolated enum VoiceLimits {
    static let topics = 3
    static let tones = 2
    static let openings = 2
    static let endings = 2
    static let phrases = 5
    /// Characters of one catchphrase.
    static let phraseLength = 40
    static let formats = 3
    static let avoid = 3
    /// Subtopics kept under each topic.
    static let details = 3
    static let watchReasons = WatchReason.limit
    static let contentGoals = ContentGoal.limit
    /// Scripts the creator approved ("Sounds like me") that Cue keeps to learn from; the oldest goes when a fourth comes.
    static let approvedSamples = 3

    /// "Max 3 topics" and friends: the toast when one more would go over.
    static func message(max: Int, noun: String) -> String {
        String(localized: "Max \(max) \(noun)")
    }
}
