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
    /// The toast's kind: Cue's ★ when it wrote, a ✓ when there was nothing to do ("Already fits 1:00 to 1:30"), a ! when it
    /// couldn't.
    var kind: ToastKind = .cue

    /// The notice for a tool that ran on `before` and gave `result`. `done` is what the tool says when it did its job, `idealRange` the length
    /// the platform asks, in seconds, and `language` the script's, whose pace times it (`ReadTime.pace(for:)`).
    static func after(
        _ tool: ScriptTool, before: String, result: RewriteResult, done: String, idealRange: ClosedRange<TimeInterval>, language: CueLanguage? = nil
    ) -> RewriteNotice {
        let words = ReadTime.wordCount(in: before)
        let now = ReadTime.wordCount(in: result.text)
        let same = ScriptTextNormalizer.normalize(result.text) == ScriptTextNormalizer.normalize(before)
        if same || result.isUntouched {
            let said = nothingChanged(tool, words: words, result: result, idealRange: idealRange, language: language)
            return RewriteNotice(message: said.message, changesScript: false, kind: said.kind)
        }
        var message = done
        switch tool {
        case .fitToTime:
            if let length = lengthNote(words: now, idealRange: idealRange, language: language) { message = length }
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

    /// How far a script is from the length asked, when it isn't there ("Closer to the 1:00 to 1:30 goal · now 0:48"); nil when it fits.
    static func lengthNote(words: Int, idealRange: ClosedRange<TimeInterval>, language: CueLanguage? = nil) -> String? {
        guard !fits(words: words, idealRange: idealRange, language: language) else { return nil }
        let range = DurationText.range(idealRange)
        let length = DurationText.clock(Double(words) / (ReadTime.wordsPerMinute(speed: ReadTime.naturalSpeed, language: language) / 60))
        return String(localized: "Closer to the \(range) goal · now \(length)")
    }

    /// Whether `words` is the length asked, the way the length bar under the script tells it (`LengthZone`): a toast that says it fits never sits
    /// over a bar that says "CUT 9S".
    static func fits(words: Int, idealRange: ClosedRange<TimeInterval>, language: CueLanguage? = nil) -> Bool {
        idealRange.contains(Double(words) / (ReadTime.wordsPerMinute(speed: ReadTime.naturalSpeed, language: language) / 60))
    }

    private static func nothingChanged(
        _ tool: ScriptTool, words: Int, result: RewriteResult, idealRange: ClosedRange<TimeInterval>, language: CueLanguage?
    ) -> (message: String, kind: ToastKind) {
        switch tool {
        case .fixGrammar where !result.isUntouched:
            return (String(localized: "No mistakes to fix"), .done)
        case .fitToTime where fits(words: words, idealRange: idealRange, language: language):
            let range = DurationText.range(idealRange)
            return (String(localized: "Already within the target length · \(range)"), .done)
        default:
            return (String(localized: "Couldn’t draft it"), .problem)
        }
    }
}
