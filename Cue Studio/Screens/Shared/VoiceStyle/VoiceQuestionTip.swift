//
//  VoiceQuestionTip.swift
//  Cue Studio
//

import SwiftUI
import TipKit

/// The My Cue Voice tip, compact (owner, 30/10/2026): the question itself as the title ("How do you like to open?") and one line, "One quick
/// question · voice nn%". TipKit keeps the logic — whether it shows, and that a closed one is invalidated — and `VoiceQuestionScheduler`
/// decides which question and when. Each time a question comes back it is a tip of its own (`VoiceQuestionScheduler.tipID`: the erase's
/// generation and the question's round), because TipKit never shows an invalidated tip again.
struct VoiceQuestionTip: Tip {
    let question: VoiceQuestion
    /// `VoiceQuestionScheduler.tipID(for:)`.
    let tipID: String
    let strength: Int

    var id: String { tipID }

    var title: Text { Text(question.title) }

    var message: Text? { Text("One quick question · voice \(strength)%") }

    var options: [any TipOption] {
        // The scheduler's caps (one a day, three a week) are the frequency.
        [Tips.IgnoresDisplayFrequency(true)]
    }
}
