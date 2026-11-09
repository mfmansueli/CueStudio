//
//  BrandLogoCorner.swift
//  Cue Studio
//

import Foundation

/// Where a logo sits on the video, inside the platforms' safe area.
nonisolated enum BrandLogoCorner: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = BrandLogoCorner.topRight

    case topLeft, topRight, bottomLeft, bottomRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topLeft: String(localized: "Top left")
        case .topRight: String(localized: "Top right")
        case .bottomLeft: String(localized: "Bottom left")
        case .bottomRight: String(localized: "Bottom right")
        }
    }

    /// The logo's center for a logo `width` wide (share of the video) and `aspect` (width over height) on a video of
    /// `videoAspect`: off the edges by the safe margins the captions keep, clear of the platforms' buttons at the bottom right.
    func center(width: Double, aspect: Double, videoAspect: Double) -> OverlayPoint {
        let height = width / max(aspect, 0.1) * videoAspect
        let side = 0.06 + width / 2
        let top = 0.1 + height / 2
        let bottom = 0.78 - height / 2
        switch self {
        case .topLeft: return OverlayPoint(x: side, y: top)
        case .topRight: return OverlayPoint(x: 1 - side, y: top)
        case .bottomLeft: return OverlayPoint(x: side, y: bottom)
        case .bottomRight: return OverlayPoint(x: 1 - side - 0.1, y: bottom)
        }
    }
}
