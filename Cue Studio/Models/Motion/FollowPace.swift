//
//  FollowPace.swift
//  Cue Studio
//

import Foundation

/// How quickly the frame catches up with the face it follows: a calm operator lets the face wander further and glides slowly;
/// a quick one stays on it.
nonisolated enum FollowPace: String, Codable, CaseIterable, Identifiable, Sendable {
    case calm, natural, quick

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calm: String(localized: "Calm")
        case .natural: String(localized: "Natural")
        case .quick: String(localized: "Quick")
        }
    }

    /// How far (as a share of the crop's size) the face can move before the frame goes after it.
    var deadZone: Double {
        switch self {
        case .calm: 0.12
        case .natural: 0.08
        case .quick: 0.04
        }
    }

    /// Seconds the path is smoothed over (the standard deviation of the smoothing): how softly the frame starts and stops.
    var smoothing: TimeInterval {
        switch self {
        case .calm: 0.9
        case .natural: 0.55
        case .quick: 0.3
        }
    }

    /// Fastest the frame moves, in crop widths (or heights) a second.
    var topSpeed: Double {
        switch self {
        case .calm: 0.35
        case .natural: 0.6
        case .quick: 1.2
        }
    }
}
