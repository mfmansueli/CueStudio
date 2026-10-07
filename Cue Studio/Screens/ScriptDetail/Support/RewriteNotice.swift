//
//  RewriteNotice.swift
//  Cue Studio
//

import Foundation

/// What the creator is told a tool did, from what it did: "Made it shorter" over a script that is no shorter is a button that lies. Measured on an
/// iPhone 15 Pro, the tools had cut a script to a third while saying "Grammar fixed", and left the same words with "Made it more human".
nonisolated struct RewriteNotice: Equatable, Sendable {
    /// What the toast says.
    let message: String
    /// Whether the script now says something else. When it doesn't, nothing is saved and there is nothing to undo.
    let changesScript: Bool

    /// The notice for a tool that ran on `before` and gave `result`. `done` is what the tool says when it did its job, and `idealRange` the length
    /// the platform asks, in seconds.
    static func after(
        _ tool: ScriptTool, before: String, result: RewriteResult, done: String, idealRange: ClosedRange<TimeInterval>
    ) -> RewriteNotice {
        let words = ReadTime.wordCount(in: before)
        let now = ReadTime.wordCount(in: result.text)
        let same = ScriptTextNormalizer.normalize(result.text) == ScriptTextNormalizer.normalize(before)
        if same || result.isUntouched {
            return RewriteNotice(message: nothingChanged(tool, words: words, result: result, idealRange: idealRange), changesScript: false)
        }
        var message = done
        switch tool {
        case .fitToTime:
            if let length = lengthNote(words: now, idealRange: idealRange) { message = length }
        case .shorterAndDirect:
            message += " · " + String(localized: "\(words) → \(now) words")
        default:
            break
        }
        if result.leftAsWritten > 0 {
            message += " · " + String(localized: "\(result.leftAsWritten) of \(result.parts) parts left as written")
        }
        return RewriteNotice(message: message, changesScript: true)
    }

    /// How far a script is from the length asked, when it isn't there ("Closer to 1:00–1:30 · now 0:48"); nil when it fits.
    static func lengthNote(words: Int, idealRange: ClosedRange<TimeInterval>) -> String? {
        guard !fits(words: words, idealRange: idealRange) else { return nil }
        let range = DurationText.clock(idealRange.lowerBound) + "–" + DurationText.clock(idealRange.upperBound)
        let length = DurationText.clock(Double(words) / (ReadTime.wordsPerMinute(speed: ReadTime.naturalSpeed) / 60))
        return String(localized: "Closer to \(range) · now \(length)")
    }

    /// Whether `words` is the length asked, within what counting words can tell.
    static func fits(words: Int, idealRange: ClosedRange<TimeInterval>) -> Bool {
        let low = Double(ReadTime.words(for: idealRange.lowerBound)) * (1 - RewriteOutcome.slack)
        let high = Double(ReadTime.words(for: idealRange.upperBound)) * (1 + RewriteOutcome.slack)
        return (low...high).contains(Double(words))
    }

    private static func nothingChanged(_ tool: ScriptTool, words: Int, result: RewriteResult, idealRange: ClosedRange<TimeInterval>) -> String {
        switch tool {
        case .fixGrammar where !result.isUntouched:
            return String(localized: "No mistakes to fix")
        case .fitToTime where fits(words: words, idealRange: idealRange):
            let range = DurationText.clock(idealRange.lowerBound) + "–" + DurationText.clock(idealRange.upperBound)
            return String(localized: "Already fits \(range)")
        default:
            return String(localized: "Couldn’t write it · Try again")
        }
    }
}
