//
//  VoyageProgress.swift
//  Cue Studio
//

import Foundation

/// Which steps of the first voyage are done, worked out from what the creator has (scripts, takes and their edits, shares) and the
/// voyage's own marks. Nothing is locked: a step done out of order counts, the card names the first one still ahead, and the first
/// video shared completes the voyage whatever was skipped on the way. Only what the creator did counts (owner, 30/10/2026):
///
/// - "Prepare your first script": any script, the first flight's included.
/// - Practice: the teleprompter really read a script (`VoyageMarks.practiced`), or a take was recorded (that reads it too).
/// - Record: a take recorded with Cue. A video imported from Photos is never a recording, a practice or a script.
/// - Pick: a best take marked, or a video with a single take (nothing to choose between).
/// - Polish: captions turned on, or a pause or word cut by Clean Up. The captions an export makes for itself aren't the creator's.
///
/// A step once done stays done (`VoyageMarks.announced`): a second take of the first video doesn't take Pick back.
///
/// Pure, so every rule is tested without the app.
nonisolated struct VoyageProgress: Equatable, Sendable {
    /// The steps done, whatever their order.
    let done: Set<VoyageStep>

    init(scripts: Int, takes: [Take], shares: Int, marks: VoyageMarks) {
        let shared = shares > 0
        let recordings = takes.filter { $0.origin != .imported }
        let recorded = !recordings.isEmpty
        var done: Set<VoyageStep> = []
        if scripts > 0 || recorded || shared { done.insert(.write) }
        // Recording reads the script on the teleprompter too: "Skip, record now" never leaves the step behind.
        if marks.practiced || recorded || shared { done.insert(.practice) }
        if recorded || shared { done.insert(.record) }
        if shared || takes.contains(where: \.isBest) || Self.hasSingleTake(takes) { done.insert(.pick) }
        if shared || marks.skippedPolish || takes.contains(where: { Self.isPolished($0.edit) }) { done.insert(.polish) }
        if shared { done.insert(.share) }
        done.formUnion(marks.announced)
        self.done = done
    }

    /// A video recorded once (a script's takes for one network, `TakeVideoKey`), a freestyle take or a video imported from Photos: that take
    /// is the one, nothing to pick.
    static func hasSingleTake(_ takes: [Take]) -> Bool {
        Dictionary(grouping: takes, by: \.videoKey).values.contains { $0.count == 1 }
    }

    /// Captions turned on, or a pause or word cut by Clean Up. Captions only cached by an export (shown off) don't count.
    static func isPolished(_ edit: TakeEdit?) -> Bool {
        guard let edit else { return false }
        return (edit.showsCaptions && !edit.captions.isEmpty) || edit.suggestions.contains { $0.status == .removed }
    }

    /// The first video is shared.
    var isComplete: Bool { done.contains(.share) }

    /// The first step still ahead; nil once the voyage is complete.
    var current: VoyageStep? {
        isComplete ? nil : VoyageStep.allCases.first { !done.contains($0) }
    }

    static var stepCount: Int { VoyageStep.allCases.count }
}
