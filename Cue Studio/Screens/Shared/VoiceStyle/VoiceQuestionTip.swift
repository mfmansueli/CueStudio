//
//  VoiceQuestionTip.swift
//  Cue Studio
//

import SwiftUI
import TipKit

/// The My Cue Voice tip (08 §6, 09 §3): "Make scripts sound more like you · One quick question · voice nn%". TipKit keeps the logic —
/// whether it shows, and that a closed one is invalidated — and `VoiceQuestionScheduler` decides which question and when. Each
/// question, each time it comes back after a dismissal, is a tip of its own (`round`), because TipKit never shows an invalidated tip again.
struct VoiceQuestionTip: Tip {
    let question: VoiceQuestion
    /// How many times this question was dismissed before: a dismissed question that comes back is a new tip.
    let round: Int
    let strength: Int

    var id: String { "vq.tip.\(question.rawValue).\(round)" }

    var title: Text { Text("Make scripts sound more like you") }

    var message: Text? { Text("One quick question · voice \(strength)%") }

    var options: [any TipOption] {
        // The scheduler's caps (one a day, three a week) are the frequency.
        [Tips.IgnoresDisplayFrequency(true)]
    }
}
