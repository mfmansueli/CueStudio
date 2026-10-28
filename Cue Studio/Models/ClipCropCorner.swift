//
//  ClipCropCorner.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// A corner of Crop's box, pulled to resize it.
nonisolated enum ClipCropCorner: CaseIterable, Sendable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    /// Which way it points from the box's middle: −1 left or up, 1 right or down.
    var direction: (x: CGFloat, y: CGFloat) {
        switch self {
        case .topLeading: (-1, -1)
        case .topTrailing: (1, -1)
        case .bottomLeading: (-1, 1)
        case .bottomTrailing: (1, 1)
        }
    }

    /// Where it is on `rect`.
    func point(of rect: CGRect) -> CGPoint {
        CGPoint(x: direction.x < 0 ? rect.minX : rect.maxX, y: direction.y < 0 ? rect.minY : rect.maxY)
    }
}
