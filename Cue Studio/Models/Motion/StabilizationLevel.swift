//
//  StabilizationLevel.swift
//  Cue Studio
//

import Foundation

/// How strongly Stabilize smooths the camera's shake out of a clip: more smoothing takes out slower sways too, and needs a
/// tighter crop to hide the moving edges.
nonisolated enum StabilizationLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Only the quick jitters; the least cropped.
    case gentle
    case standard
    /// Also the slow sways of walking; the most cropped.
    case strong

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gentle: String(localized: "Gentle")
        case .standard: String(localized: "Standard")
        case .strong: String(localized: "Strong")
        }
    }

    /// Seconds the camera's path is smoothed over (the standard deviation of the smoothing).
    var smoothing: TimeInterval {
        switch self {
        case .gentle: 0.25
        case .standard: 0.6
        case .strong: 1.2
        }
    }

    /// Most the picture can be zoomed in to hide the edges, as a share of its size (1.06 is 6%).
    var maximumZoom: Double {
        switch self {
        case .gentle: 1.05
        case .standard: 1.09
        case .strong: 1.14
        }
    }
}
