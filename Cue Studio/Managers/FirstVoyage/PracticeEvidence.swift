//
//  PracticeEvidence.swift
//  Cue Studio
//

import Foundation

/// When reading on the teleprompter is the first voyage's practice (owner, 30/10/2026): the script played for at least five seconds and its
/// text moved on by about a line. A tap on Play and Stop again, or a script that never scrolled (Voice Following without a word heard), is
/// not a practice.
nonisolated enum PracticeEvidence {
    static let minimumSeconds: TimeInterval = 5
    /// Points the text has to move: about one line at the smallest text size.
    static let minimumAdvance: Double = 24

    static func counts(playedFor seconds: TimeInterval, advanced points: Double) -> Bool {
        seconds >= minimumSeconds && points >= minimumAdvance
    }
}
