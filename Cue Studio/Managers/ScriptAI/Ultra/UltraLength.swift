//
//  UltraLength.swift
//  Cue Studio
//

import Foundation

/// How long an Ultra script is asked to run. On Auto the length is information for the creator, never a target: nothing useful is cut and nothing
/// is padded to reach the platform's range. A length the creator chose on the card, or asked for in the idea, is their intent and is said.
nonisolated enum UltraLength: Hashable, Sendable {
    /// No time or word target.
    case free
    /// About this many seconds, as a reference that is not binding (the lab's comparison only).
    case reference(TimeInterval)
    /// The creator's chosen range of speaking time.
    case required(ClosedRange<TimeInterval>)

    /// The request's own policy: Auto is free, an explicit choice is required.
    init(_ request: ScriptRequest) {
        self = request.durationPolicy == .targeted ? .required(request.targetRange) : .free
    }

    /// The line the prompt carries, with the words a natural pace gives (150 a minute) so the model needn't convert.
    var promptLine: String {
        switch self {
        case .free:
            return "Length: free. There is no time or word target: the subject and the request decide. Do not pad, and do not cut useful development."
        case .reference(let seconds):
            return "Length: about \(Int(seconds)) seconds of speech (about \(Self.words(seconds)) words at a natural pace), as a reference, not a limit. "
                + "Do not pad to reach it, and do not cut useful development to stay under it."
        case .required(let range):
            let low = Int(range.lowerBound), high = Int(range.upperBound)
            return "Length: the creator chose \(low) to \(high) seconds of speech (about \(Self.words(range.lowerBound)) to "
                + "\(Self.words(range.upperBound)) words at a natural pace). Treat it as their intent: develop enough to fill it, without "
                + "padding, and stay within it."
        }
    }

    /// The words at 150 a minute, the pace the rest of Cue counts with.
    private static func words(_ seconds: TimeInterval) -> Int {
        Int((seconds * 150 / 60).rounded())
    }
}
