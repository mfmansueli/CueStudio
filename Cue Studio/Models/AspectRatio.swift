//
//  AspectRatio.swift
//  Cue Studio
//

import Foundation

/// Output frame of a take. Recording always uses the full portrait sensor; the frame is applied as a
/// guide while filming and as a crop on export.
nonisolated enum AspectRatio: String, Codable, CaseIterable, Identifiable, Sendable {
    case portrait = "9:16"
    case vertical = "4:5"
    case square = "1:1"
    case landscape = "16:9"

    var id: String { rawValue }

    var label: String { rawValue }

    /// Width divided by height.
    var widthOverHeight: Double {
        switch self {
        case .portrait: 9.0 / 16.0
        case .vertical: 4.0 / 5.0
        case .square: 1
        case .landscape: 16.0 / 9.0
        }
    }

    /// Next ratio, used by the one-tap frame button in the camera.
    var next: AspectRatio {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }
}
