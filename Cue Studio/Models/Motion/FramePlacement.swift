//
//  FramePlacement.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How a recording's upright frame lands on the edit's frame at a moment: held steady by Stabilize (moved, turned and zoomed as
/// the compositor does), then cropped (where Format puts the crop, or where Follow face has it then) or fitted whole with bars.
/// Turns a point of the recording into a point of the video, and back: Track places what follows an object with it. Pure.
nonisolated struct FramePlacement: Sendable {
    /// The recording's upright frame, in pixels.
    let uprightSize: CGSize
    /// The part kept, from the top left, in pixels: its size is the edit's frame.
    let crop: CGRect
    var follow: FaceFollowPath?
    var fits = false
    /// Stabilize's path for the clip, when it has one.
    var steady: StabilizationPath?

    /// The crop at `time` (seconds of the recording), from the top left.
    func crop(at time: TimeInterval) -> CGRect {
        guard let follow, uprightSize.width > 0, uprightSize.height > 0 else { return crop }
        let center = follow.center(at: time)
        let left = min(max(0, center.x * uprightSize.width - crop.width / 2), uprightSize.width - crop.width)
        let top = min(max(0, center.y * uprightSize.height - crop.height / 2), uprightSize.height - crop.height)
        return CGRect(x: left, y: top, width: crop.width, height: crop.height)
    }

    /// Fit: the scale of the recording and where it sits in the frame.
    private var fitted: (scale: Double, x: Double, y: Double) {
        let scale = min(crop.width / max(1, uprightSize.width), crop.height / max(1, uprightSize.height))
        return (scale, (crop.width - uprightSize.width * scale) / 2, (crop.height - uprightSize.height * scale) / 2)
    }

    /// The point of the video showing `point` of the recording (fractions of each, from the top left) at `time`.
    func videoPoint(for point: CGPoint, at time: TimeInterval) -> OverlayPoint {
        guard crop.width > 0, crop.height > 0 else { return .center }
        let held = steadied(CGPoint(x: point.x * uprightSize.width, y: point.y * uprightSize.height), at: time)
        let x = held.x, y = held.y
        if fits {
            let fit = fitted
            return OverlayPoint(x: (x * fit.scale + fit.x) / crop.width, y: (y * fit.scale + fit.y) / crop.height)
        }
        let rect = crop(at: time)
        return OverlayPoint(x: (x - rect.minX) / rect.width, y: (y - rect.minY) / rect.height)
    }

    /// The point of the recording under `point` of the video at `time`.
    func recordingPoint(for point: OverlayPoint, at time: TimeInterval) -> CGPoint {
        guard uprightSize.width > 0, uprightSize.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        let held: CGPoint
        if fits {
            let fit = fitted
            held = CGPoint(x: (point.x * crop.width - fit.x) / max(0.000_1, fit.scale), y: (point.y * crop.height - fit.y) / max(0.000_1, fit.scale))
        } else {
            let rect = crop(at: time)
            held = CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
        }
        let filmed = unsteadied(held, at: time)
        return CGPoint(x: filmed.x / uprightSize.width, y: filmed.y / uprightSize.height)
    }

    /// How much of the recording's width and height a share `side` of the video's width takes (a square on screen).
    func recordingSize(forVideoWidth side: Double) -> (width: Double, height: Double) {
        guard uprightSize.width > 0, uprightSize.height > 0 else { return (side, side) }
        let pixels = side * crop.width / (fits ? max(0.000_1, fitted.scale) : 1) / (steady?.zoom ?? 1)
        return (pixels / uprightSize.width, pixels / uprightSize.height)
    }

    // MARK: - Stabilize

    /// Where `point` (pixels of the upright recording, from the top left) is once Stabilize moved, turned (clockwise positive)
    /// and zoomed the frame around its center at `time`, as `CueVideoCompositor.steadied` draws it.
    private func steadied(_ point: CGPoint, at time: TimeInterval) -> CGPoint {
        guard let steady else { return point }
        let correction = steady.correction(at: time)
        let x = point.x - uprightSize.width / 2, y = point.y - uprightSize.height / 2
        let cosine = cos(correction.angle), sine = sin(correction.angle)
        return CGPoint(
            x: uprightSize.width / 2 + steady.zoom * (x * cosine - y * sine) + correction.dx * uprightSize.width,
            y: uprightSize.height / 2 + steady.zoom * (x * sine + y * cosine) + correction.dy * uprightSize.height
        )
    }

    /// The point of the recording as filmed that Stabilize put at `point` at `time`.
    private func unsteadied(_ point: CGPoint, at time: TimeInterval) -> CGPoint {
        guard let steady, steady.zoom > 0 else { return point }
        let correction = steady.correction(at: time)
        let x = (point.x - uprightSize.width / 2 - correction.dx * uprightSize.width) / steady.zoom
        let y = (point.y - uprightSize.height / 2 - correction.dy * uprightSize.height) / steady.zoom
        let cosine = cos(correction.angle), sine = sin(correction.angle)
        return CGPoint(x: uprightSize.width / 2 + x * cosine + y * sine, y: uprightSize.height / 2 - x * sine + y * cosine)
    }
}
