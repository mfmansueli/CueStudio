//
//  UltraLength.swift
//  Cue Studio
//

import Foundation

/// How long an Ultra script is asked to run. On Auto a vertical video (every network but YouTube) is written to its platform's range, never past
/// two minutes: most TikTok, Reels and Shorts videos run 1:15 to 1:45 (the owner's call, 29/10/2026, after free scripts came out at 2 to 3
/// minutes). YouTube's long form is written freely: nothing useful is cut and nothing is padded. A length the creator chose on the card, or asked
/// for in the idea, is their intent and is said.
nonisolated enum UltraLength: Hashable, Sendable {
    /// No time or word target.
    case free
    /// About this many seconds, as a reference that is not binding (the lab's comparison only).
    case reference(TimeInterval)
    /// The creator's chosen range of speaking time.
    case required(ClosedRange<TimeInterval>)
    /// The platform's range of speaking time on Auto.
    case ideal(ClosedRange<TimeInterval>)

    /// The request's own policy: an explicit choice is required, Auto is the platform's range, or free on YouTube.
    init(_ request: ScriptRequest) {
        if request.durationPolicy == .targeted {
            self = .required(request.targetRange)
        } else if request.platform == .youtube {
            self = .free
        } else {
            self = .ideal(request.targetRange)
        }
    }

    /// The longest a script on its platform's range may come back before it is fitted into it (`UltraScriptService`): a little over the range,
    /// never past two minutes. Nil for the other policies, which are never fitted by themselves.
    var overflowWords: Int? { overflowWords(in: nil) }

    /// `overflowWords` at the pace of `language` (`ReadTime.pace(for:)`: fewer words a minute in Korean, more in French).
    func overflowWords(in language: CueLanguage?) -> Int? {
        guard case .ideal(let range) = self else { return nil }
        return ReadTime.words(for: min(range.upperBound * 1.15, ScriptRequestFactory.autoCeiling), language: language)
    }

    /// The line the prompt carries, with the words a natural pace gives (150 a minute in English, `ReadTime.pace(for:)` in other languages) so
    /// the model needn't convert.
    var promptLine: String { promptLine(in: nil) }

    /// `promptLine` with the words at the pace of `language`.
    func promptLine(in language: CueLanguage?) -> String {
        func words(_ seconds: TimeInterval) -> Int { ReadTime.words(for: seconds, language: language) }
        switch self {
        case .free:
            return "Length: free. There is no time or word target: the subject and the request decide. Do not pad, and do not cut useful development."
        case .reference(let seconds):
            return "Length: about \(Int(seconds)) seconds of speech (about \(words(seconds)) words at a natural pace), as a reference, not a limit. "
                + "Do not pad to reach it, and do not cut useful development to stay under it."
        case .required(let range):
            let low = Int(range.lowerBound), high = Int(range.upperBound)
            return "Length: the creator chose \(low) to \(high) seconds of speech (about \(words(range.lowerBound)) to "
                + "\(words(range.upperBound)) words at a natural pace). Treat it as their intent: develop enough to fill it, without "
                + "padding, and stay within it."
        case .ideal(let range):
            let low = Int(range.lowerBound), high = Int(range.upperBound)
            return "Length: \(low) to \(high) seconds of speech (about \(words(range.lowerBound)) to \(words(range.upperBound)) words "
                + "at a natural pace), the length that works on this platform. Develop the idea fully within it, without padding, and never go "
                + "past \(words(range.upperBound)) words: choose the strongest points instead of covering everything."
        }
    }
}
