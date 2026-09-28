//
//  BestTakeSuggester.swift
//  Cue Studio
//

import Foundation

/// Pro's best-take pick: among a script's takes, the one that ran the whole script closest to its
/// expected length, inside the platform's ideal range when possible; newer wins a tie. Pure.
nonisolated enum BestTakeSuggester {
    /// Takes shorter than this share of the expected length probably stopped early.
    static let minimumCompletion = 0.8

    static func suggestion(among takes: [Take], expectedDuration: TimeInterval, idealRange: ClosedRange<TimeInterval>) -> Take? {
        guard takes.count > 1, expectedDuration > 0 else { return nil }
        let complete = takes.filter { $0.duration >= expectedDuration * minimumCompletion }
        let candidates = complete.isEmpty ? takes : complete
        return candidates.min { lhs, rhs in
            let lhsIdeal = idealRange.contains(lhs.duration), rhsIdeal = idealRange.contains(rhs.duration)
            if lhsIdeal != rhsIdeal { return lhsIdeal }
            let lhsGap = abs(lhs.duration - expectedDuration), rhsGap = abs(rhs.duration - expectedDuration)
            if abs(lhsGap - rhsGap) > 0.5 { return lhsGap < rhsGap }
            return lhs.recordedAt > rhs.recordedAt
        }
    }
}
