//
//  ExportProgress.swift
//  Cue Studio
//

import Foundation

/// Where an export is: the stage it is in and, when that stage can measure itself, how far it is (0 to 1). A stage that can't
/// (the fonts arriving, Studio Voice, building the video) has no number: the review names it instead of inventing one.
nonisolated struct ExportProgress: Equatable, Sendable {
    enum Stage: Int, Comparable, Sendable {
        /// Reading the take and building what is drawn.
        case preparing
        /// The script families the words need, still downloading (`VideoExportService.fontWait`).
        case fonts
        /// Follow face or Stabilize's analysis of a recording, made now (it is kept: a retry goes on from there).
        case motion
        /// Studio Voice, and the mix of more than the take's sound through the limiter (`Mixdown`).
        case sound
        /// The frames being written.
        case rendering

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var stage: Stage
    /// 0 to 1 within the stage; nil when the stage can't measure itself.
    var fraction: Double?

    init(_ stage: Stage, fraction: Double? = nil) {
        self.stage = stage
        self.fraction = fraction.map { min(max($0, 0), 1) }
    }

    static let preparing = ExportProgress(.preparing)
}
