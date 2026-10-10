//
//  VoyageProgress.swift
//  Cue Studio
//

import Foundation

/// Which steps of the first voyage are done, worked out from what the creator has (scripts, takes and their edits, shares) and the
/// voyage's own marks. Nothing is locked: a step done out of order counts, the card names the first one still ahead, and the first
/// video shared completes the voyage whatever was skipped on the way. Pure, so every rule is tested without the app.
nonisolated struct VoyageProgress: Equatable, Sendable {
    /// The steps done, whatever their order.
    let done: Set<VoyageStep>

    init(scripts: Int, takes: [Take], shares: Int, marks: VoyageMarks) {
        let shared = shares > 0
        let recorded = !takes.isEmpty
        var done: Set<VoyageStep> = []
        if scripts > 0 || recorded || shared { done.insert(.write) }
        // Recording reads the script on the teleprompter too: "Skip, record now" never leaves the step behind.
        if marks.practiced || recorded || shared { done.insert(.practice) }
        if recorded || shared { done.insert(.record) }
        if shared || takes.contains(where: { $0.isBest || $0.edit != nil }) { done.insert(.pick) }
        if shared || marks.skippedPolish || takes.contains(where: { Self.isPolished($0.edit) }) { done.insert(.polish) }
        if shared { done.insert(.share) }
        self.done = done
    }

    /// Captions made, or a pause or word cut by Clean Up.
    static func isPolished(_ edit: TakeEdit?) -> Bool {
        guard let edit else { return false }
        return !edit.captions.isEmpty || edit.suggestions.contains { $0.status == .removed }
    }

    /// The first video is shared.
    var isComplete: Bool { done.contains(.share) }

    /// The first step still ahead; nil once the voyage is complete.
    var current: VoyageStep? {
        isComplete ? nil : VoyageStep.allCases.first { !done.contains($0) }
    }

    var doneCount: Int { done.count }

    static var stepCount: Int { VoyageStep.allCases.count }
}
