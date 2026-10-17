//
//  MotionAnalysisPause.swift
//  Cue Studio
//

import Foundation

/// Why the motion analysis waits: it only runs while Cue is open and the iPhone is cool, so it never slows down what the creator
/// is doing nor heats the iPhone further. It goes on by itself when the reason is gone.
nonisolated enum MotionAnalysisPause: Equatable, Sendable {
    /// Cue is in the background.
    case background
    /// The iPhone is hot (`thermalState` serious or critical).
    case heat

    /// Why the analysis can't run now, if it can't.
    static func reason(isActive: Bool, thermal: ProcessInfo.ThermalState) -> MotionAnalysisPause? {
        if !isActive { return .background }
        switch thermal {
        case .serious, .critical: return .heat
        default: return nil
        }
    }
}
