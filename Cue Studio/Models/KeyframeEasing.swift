//
//  KeyframeEasing.swift
//  Cue Studio
//

import Foundation

/// How motion arrives at a keyframe: at an even pace, or easing in and out.
nonisolated enum KeyframeEasing: String, Codable, CaseIterable, Identifiable, Sendable {
    case linear, smooth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .linear: String(localized: "Linear")
        case .smooth: String(localized: "Smooth")
        }
    }

    /// `progress` (0 to 1) through the way to the keyframe, eased.
    func apply(_ progress: Double) -> Double {
        let clamped = min(max(0, progress), 1)
        switch self {
        case .linear: return clamped
        case .smooth: return clamped * clamped * (3 - 2 * clamped)
        }
    }
}
