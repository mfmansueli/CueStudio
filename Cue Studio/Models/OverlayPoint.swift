//
//  OverlayPoint.swift
//  Cue Studio
//

import Foundation

/// A point on the video frame as fractions of its size, from the top left: (0.5, 0.5) is the
/// middle whatever the format or the export quality. Where texts and media sit.
nonisolated struct OverlayPoint: Codable, Hashable, Sendable {
    /// How close to an edge a center can go.
    static let margin = 0.04

    var x: Double
    var y: Double

    static let center = OverlayPoint(x: 0.5, y: 0.5)

    /// Kept inside the frame.
    var clamped: OverlayPoint {
        OverlayPoint(
            x: min(max(x.isFinite ? x : 0.5, Self.margin), 1 - Self.margin),
            y: min(max(y.isFinite ? y : 0.5, Self.margin), 1 - Self.margin)
        )
    }
}
