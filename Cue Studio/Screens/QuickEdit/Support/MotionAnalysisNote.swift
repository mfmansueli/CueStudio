//
//  MotionAnalysisNote.swift
//  Cue Studio
//

import Foundation

/// The line a tool that reads the motion analysis (Follow face, Stabilize) shows while the recording isn't analyzed yet, or
/// why it can't be. Pure.
nonisolated enum MotionAnalysisNote {
    enum Purpose {
        /// Follow face: looking for the face.
        case face
        /// Stabilize: measuring the shake.
        case shake
    }

    /// The line for `status`; nil once it's ready (or never asked for).
    static func text(for status: MotionAnalysisStatus?, purpose: Purpose) -> String? {
        guard let status else { return nil }
        let percent = Int((status.progress * 100).rounded())
        switch status {
        case .ready:
            return nil
        case .waiting, .analyzing:
            switch purpose {
            case .face: return String(localized: "Finding your face · \(percent)%")
            case .shake: return String(localized: "Measuring the shake · \(percent)%")
            }
        case .paused(.heat, _):
            return String(localized: "Waiting for the iPhone to cool down · \(percent)%")
        case .paused(.background, _):
            return String(localized: "Goes on when Cue is open · \(percent)%")
        case .failed:
            return String(localized: "This video couldn’t be read")
        }
    }
}
