//
//  CaptionsViewModel+TimingNotice.swift
//  Cue Studio
//

import Foundation

/// "Avisar quando uma correção mexe no tempo" (E4, owner 07/11/2026): a correction that had to guess times (new words with no
/// stretch of the voice under them, a line without word times split by length) says so where it happened, and the lines wear
/// "Check timing" until they're looked at. Dragging a line off its voice already says it (`noteMovedOffTheVoice`).
extension CaptionsViewModel {
    /// How many lines ask for a timing check now that didn't in `before`.
    func newTimingChecks(since before: [CaptionCue]) -> Int {
        let asked = Set(before.filter(\.needsTimingReview).map(\.id))
        return edit.captions.count { $0.needsTimingReview && !asked.contains($0.id) }
    }

    /// The toast for a correction that left `count` lines to check (nil: none).
    static func timingCheckNote(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return String(localized: "Timing guessed in \(count) lines · Check timing")
    }
}
