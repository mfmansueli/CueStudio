//
//  PersonPlacement.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where the cut-out creator stands over a new background (Background's color, photo or blur, or a photo or video shown Behind you):
/// the recording's frame, with everything around the creator taken out, scaled around its middle by `scale` and moved so its middle
/// is at `center` (fractions of the frame, from the top left). As recorded: the middle, at full size.
nonisolated struct PersonPlacement: Codable, Hashable, Sendable {
    /// Smallest and largest the creator can be, as a share of the recorded size.
    static let scaleRange: ClosedRange<Double> = 0.3...1.5
    static let asRecorded = PersonPlacement()

    var center: OverlayPoint = .center
    var scale: Double = 1

    /// The middle of the frame at full size: nothing moved.
    var isAsRecorded: Bool {
        abs(center.x - 0.5) < 0.000_5 && abs(center.y - 0.5) < 0.000_5 && abs(scale - 1) < 0.000_5
    }

    /// Kept where the creator can still be seen: the scale in its range, the middle anywhere on the frame.
    var kept: PersonPlacement {
        PersonPlacement(
            center: OverlayPoint(x: min(max(center.x.isFinite ? center.x : 0.5, 0), 1), y: min(max(center.y.isFinite ? center.y : 0.5, 0), 1)),
            scale: min(max(scale.isFinite ? scale : 1, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        )
    }

    /// Moved by `offset` (fractions of the frame).
    func moved(by offset: CGSize) -> PersonPlacement {
        PersonPlacement(center: OverlayPoint(x: center.x + Double(offset.width), y: center.y + Double(offset.height)), scale: scale).kept
    }

    /// Scaled by `factor` around where it stands.
    func scaled(by factor: Double) -> PersonPlacement {
        PersonPlacement(center: center, scale: scale * factor).kept
    }

    /// Where the recording's frame lands on a frame of `size`, from the top left (what the editor outlines on the preview).
    func rect(in size: CGSize) -> CGRect {
        let placed = kept
        let width = size.width * placed.scale, height = size.height * placed.scale
        return CGRect(x: placed.center.x * size.width - width / 2, y: placed.center.y * size.height - height / 2, width: width, height: height)
    }

    /// The same as a Core Image transform for a picture of `extent` (y from the bottom): scaled around its middle, its middle moved to
    /// `center`.
    func transform(for extent: CGRect) -> CGAffineTransform {
        let placed = kept
        let target = CGPoint(x: extent.minX + placed.center.x * extent.width, y: extent.minY + (1 - placed.center.y) * extent.height)
        return CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
            .concatenating(CGAffineTransform(scaleX: placed.scale, y: placed.scale))
            .concatenating(CGAffineTransform(translationX: target.x, y: target.y))
    }
}
