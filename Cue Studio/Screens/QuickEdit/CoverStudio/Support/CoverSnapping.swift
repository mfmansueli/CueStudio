//
//  CoverSnapping.swift
//  Cue Studio
//

import Foundation

/// Where something dragged on a cover sticks: the middle across and down, and the thirds down, within a small distance. Pure,
/// so the canvas's guides and the tests agree.
enum CoverSnapping {
    /// How close (share of the cover) a center sticks.
    static let distance = 0.02
    static let verticalStops = [1.0 / 3, 0.5, 2.0 / 3]

    /// `point` stuck to the guides it's close to, and which guides it's on.
    static func snapped(_ point: OverlayPoint) -> (point: OverlayPoint, vertical: Bool, horizontal: Double?) {
        var snapped = point.clamped
        let vertical = abs(snapped.x - 0.5) < distance
        if vertical { snapped.x = 0.5 }
        let stop = verticalStops.first { abs(snapped.y - $0) < distance }
        if let stop { snapped.y = stop }
        return (snapped, vertical, stop)
    }
}
