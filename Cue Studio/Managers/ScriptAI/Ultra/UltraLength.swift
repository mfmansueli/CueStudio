//
//  UltraLength.swift
//  Cue Studio
//

import Foundation

/// How long an Ultra script is asked to run. On Auto it is written to 1:15 to 2:30 on every network, Stories and YouTube's long form included
/// (`ScriptRequestFactory.writingRange`), or to the creator's usual length up to 2:30, never past the top: the owner's call of 04/11/2026 ("o
/// roteiro é sempre um rascunho inicial"; 1:15 to 1:45 since 29/10, after free scripts came out at 2 to 3 minutes; YouTube was written freely).
/// A length the creator chose on the card, or asked for in the idea, is their intent and is said.
nonisolated enum UltraLength: Hashable, Sendable {
    /// No time or word target.
    case free
    /// About this many seconds, as a reference that is not binding (the lab's comparison only).
    case reference(TimeInterval)
    /// The creator's chosen range of speaking time.
    case required(ClosedRange<TimeInterval>)
    /// The range of speaking time on Auto: 1:15 to 2:30, or the creator's usual length.
    case ideal(ClosedRange<TimeInterval>)

    /// The request's own policy: an explicit choice is required, Auto is the network's range.
    init(_ request: ScriptRequest) {
        self = request.durationPolicy == .targeted ? .required(request.targetRange) : .ideal(request.targetRange)
    }

    /// The longest a script on its network's range may come back before it is fitted into it (`UltraScriptService`): a little over a short range
    /// (15%), never past the top of one that reaches the networks' 2:30 (`ScriptRequestFactory.autoCeiling`; "sem ficar estourando limite de
    /// palavras", the owner, 04/11/2026). Nil for the other policies, which are never fitted by themselves.
    var overflowWords: Int? { overflowWords(in: nil) }

    /// `overflowWords` at the pace of `language` (`ReadTime.pace(for:)`: fewer words a minute in Korean, more in French).
    func overflowWords(in language: CueLanguage?) -> Int? {
        guard case .ideal(let range) = self else { return nil }
        let top = range.upperBound
        return ReadTime.words(for: min(top * 1.15, max(top, ScriptRequestFactory.autoCeiling)), language: language)
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
