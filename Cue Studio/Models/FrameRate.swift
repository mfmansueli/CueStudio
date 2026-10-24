//
//  FrameRate.swift
//  Cue Studio
//

import Foundation

nonisolated enum FrameRate: Int, Codable, CaseIterable, Identifiable, Sendable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }

    var label: String { String(rawValue) }
}

nonisolated extension FrameRate {
    /// The frame rate closest to an imported video's.
    static func nearest(to fps: Double) -> FrameRate {
        allCases.min { abs(Double($0.rawValue) - fps) < abs(Double($1.rawValue) - fps) } ?? .fps30
    }
}
