//
//  BestTakeProposal.swift
//  Cue Studio
//

import Foundation

/// What the "Pick your best take" screen shows: the script's takes, the one Cue picks and why.
nonisolated struct BestTakeProposal: Equatable, Identifiable, Sendable {
    var id: UUID { best.id }
    let takes: [Take]
    let best: Take
    let reasons: [BestTakeReason]
    let platformLabel: String
    let ideal: ClosedRange<TimeInterval>
}
