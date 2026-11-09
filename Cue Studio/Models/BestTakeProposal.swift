//
//  BestTakeProposal.swift
//  Cue Studio
//

import Foundation

/// What the "Pick your best take" screen shows: the video's takes, the one Cue picks and why, and where the video really is.
nonisolated struct BestTakeProposal: Equatable, Identifiable, Sendable {
    var id: UUID { best.id }
    let takes: [Take]
    let best: Take
    let reasons: [BestTakeReason]
    let platformLabel: String
    let ideal: ClosedRange<TimeInterval>
    /// The video's stage (`TakeStage`): a video already shared still compares its takes, and the screen says SHARED, never TO PICK.
    var stage: TakeStage = .pick

    /// The line under the title: "TO PICK · 3 TAKES", or the stage the video is really at ("SHARED · 3 TAKES").
    var subtitle: String {
        String(localized: "\(stage.pipelineLabel.uppercased()) · \(takes.count) TAKES")
    }
}
