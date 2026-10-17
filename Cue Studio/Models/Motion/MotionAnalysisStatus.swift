//
//  MotionAnalysisStatus.swift
//  Cue Studio
//

import Foundation

/// Where a recording's motion analysis stands.
nonisolated enum MotionAnalysisStatus: Equatable, Sendable {
    /// In line, behind another recording.
    case waiting
    /// Being analyzed: how much is done, 0 to 1.
    case analyzing(Double)
    /// Stopped for now, with how much is done; it goes on by itself.
    case paused(MotionAnalysisPause, Double)
    case ready
    /// The recording couldn't be read.
    case failed

    var isReady: Bool { self == .ready }

    /// How much is done, 0 to 1.
    var progress: Double {
        switch self {
        case .waiting, .failed: 0
        case .analyzing(let done), .paused(_, let done): done
        case .ready: 1
        }
    }
}
