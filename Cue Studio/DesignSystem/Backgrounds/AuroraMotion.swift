//
//  AuroraMotion.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where the aurora's lights are and where the border's light runs, at a given time: pure
/// functions, so the motion is tested apart from drawing (`AuroraCardBackground`).
///
/// Every light moves on sines with different periods (10–14 s), so the drift never repeats in a
/// way the eye catches, and nothing jumps: the position is continuous in time.
nonisolated enum AuroraMotion {
    /// The soft lights behind the card, from the one that sets the mood to the shade that gives depth.
    enum Light: CaseIterable {
        case violet
        case indigo
        case glow
        case shade

        /// How far it reaches, as a share of the card's longer side.
        var radius: Double {
            switch self {
            case .violet: 0.72
            case .indigo: 0.62
            case .glow: 0.52
            case .shade: 0.58
            }
        }
    }

    /// Seconds for the border's light to go once around the card.
    static let lapDuration: TimeInterval = 9
    /// How much of the border the light covers, as a share of its length.
    static let lightLength = 0.3

    /// The light's center in the card, as shares of its width and height (0...1 is inside).
    static func center(of light: Light, at time: TimeInterval) -> CGPoint {
        let turn = 2 * Double.pi
        switch light {
        case .violet:
            return CGPoint(
                x: 0.26 + 0.24 * sin(turn * time / 12 + 0.4) + 0.03 * sin(turn * time / 4.4),
                y: 0.16 + 0.20 * sin(turn * time / 10 + 1.1)
            )
        case .indigo:
            return CGPoint(x: 0.74 + 0.22 * sin(turn * time / 14 + 2.0), y: 0.34 + 0.20 * cos(turn * time / 11))
        case .glow:
            return CGPoint(x: 0.50 + 0.28 * cos(turn * time / 13 + 0.8), y: 0.86 + 0.10 * sin(turn * time / 10.5))
        case .shade:
            return CGPoint(x: 0.56 + 0.20 * cos(turn * time / 11.5 + 3.1), y: 0.72 + 0.14 * sin(turn * time / 14 + 0.3))
        }
    }

    // MARK: - Scan line

    /// Seconds for the yellow scan line to cross the card's bottom edge once.
    static let scanDuration: TimeInterval = 12
    /// How much of the edge the bright part covers, as a share of the card's width.
    static let scanLength = 0.4

    /// Where the middle of the scan line's bright part is, as a share of the card's width. It
    /// enters from beyond the left edge and leaves beyond the right one, so the line never starts or
    /// stops in the middle of the card.
    static func scanCenter(at time: TimeInterval) -> Double {
        let lap = (time / scanDuration).truncatingRemainder(dividingBy: 1)
        let progress = lap < 0 ? lap + 1 : lap
        return -scanLength / 2 + progress * (1 + scanLength)
    }

    // MARK: - Border

    /// The light on the border: where it starts and how far it spans, in radians clockwise from the
    /// right of the card's center, which is how an angular gradient counts.
    struct Highlight: Equatable {
        let start: Double
        let span: Double
    }

    static func highlight(at time: TimeInterval, size: CGSize) -> Highlight {
        let head = time / lapDuration
        let startAngle = angle(atPerimeterFraction: head - lightLength, size: size)
        let endAngle = angle(atPerimeterFraction: head, size: size)
        var span = endAngle - startAngle
        if span <= 0 { span += 2 * .pi }
        return Highlight(start: startAngle, span: span)
    }

    /// The angle, from the card's center, of the point `fraction` of the way around its edge
    /// (clockwise from the top left corner). The light runs at an even pace along the edge, so on a
    /// wide card it sweeps a wider angle on the short sides.
    static func angle(atPerimeterFraction fraction: Double, size: CGSize) -> Double {
        let point = offsetFromCenter(atPerimeterFraction: fraction, size: size)
        let angle = atan2(point.y, point.x)
        return angle < 0 ? angle + 2 * .pi : angle
    }

    static func offsetFromCenter(atPerimeterFraction fraction: Double, size: CGSize) -> CGPoint {
        let width = size.width, height = size.height
        var distance = (fraction - fraction.rounded(.down)) * 2 * (width + height)
        if distance <= width { return CGPoint(x: -width / 2 + distance, y: -height / 2) }
        distance -= width
        if distance <= height { return CGPoint(x: width / 2, y: -height / 2 + distance) }
        distance -= height
        if distance <= width { return CGPoint(x: width / 2 - distance, y: height / 2) }
        distance -= width
        return CGPoint(x: -width / 2, y: height / 2 - distance)
    }
}
