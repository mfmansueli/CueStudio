//
//  BestTakeProposal.swift
//  Cue Studio
//

import Foundation

/// Why Cue picked a take: only what can be told from the takes themselves (their length against the script and the
/// platform), never a claim about the delivery that nothing measured.
nonisolated enum BestTakeReason: Equatable, Sendable {
    /// Its length is inside the platform's ideal range.
    case fitsPlatform(duration: TimeInterval)
    /// It runs the whole script, not a stop half way.
    case readWholeScript
    /// Of all the takes, its length is the closest to the script's.
    case closestToScript

    static func reasons(
        for take: Take, among takes: [Take], expectedDuration: TimeInterval, idealRange: ClosedRange<TimeInterval>
    ) -> [BestTakeReason] {
        var result: [BestTakeReason] = []
        if idealRange.contains(take.duration) { result.append(.fitsPlatform(duration: take.duration)) }
        if expectedDuration > 0, take.duration >= expectedDuration * BestTakeSuggester.minimumCompletion { result.append(.readWholeScript) }
        let gap = abs(take.duration - expectedDuration)
        if takes.count > 1, takes.allSatisfy({ $0.id == take.id || abs($0.duration - expectedDuration) >= gap }) {
            result.append(.closestToScript)
        }
        return result
    }
}

/// What the "Pick your best take" screen shows: the script's takes, the one Cue picks and why.
nonisolated struct BestTakeProposal: Equatable, Identifiable, Sendable {
    var id: UUID { best.id }
    let takes: [Take]
    let best: Take
    let reasons: [BestTakeReason]
    let platformLabel: String
    let ideal: ClosedRange<TimeInterval>
}
