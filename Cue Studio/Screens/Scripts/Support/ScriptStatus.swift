//
//  ScriptStatus.swift
//  Cue Studio
//

import Foundation

/// Where a script is on its way to a posted video, for its row on Scripts: "READY TO RECORD · 0:20"
/// before any take, then "3 TAKES · READY" at the stage its takes put the video in (the same
/// `TakeStage` the Takes tab shows). Derived, never set by hand.
nonisolated struct ScriptStatus: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// No take yet: the script is ready to record, and runs about this long.
        case toRecord(seconds: TimeInterval)
        case takes(count: Int, stage: TakeStage)
    }

    let kind: Kind

    init(takes: [Take], readSeconds: TimeInterval, hasDraft: (UUID) -> Bool) {
        if takes.isEmpty {
            kind = .toRecord(seconds: readSeconds)
        } else {
            kind = .takes(count: takes.count, stage: TakeStage(takes: takes, hasDraft: hasDraft))
        }
    }

    /// The HUD values: ["Ready to record", "0:20"] or ["3 takes", "Ready"].
    var values: [String] {
        switch kind {
        case .toRecord(let seconds):
            [String(localized: "Ready to record"), DurationText.clock(seconds)]
        case .takes(let count, let stage):
            [count == 1 ? String(localized: "1 take") : String(localized: "\(count) takes"), stage.pipelineLabel]
        }
    }

    var stage: TakeStage? {
        if case .takes(_, let stage) = kind { stage } else { nil }
    }
}
