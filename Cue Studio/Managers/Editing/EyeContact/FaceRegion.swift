//
//  FaceRegion.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The square, turned part of an upright frame the face landmarks read (`FaceMeshModel`, a 256-pixel crop): around the face, its
/// sides along and across the line between the eyes, as MediaPipe's face mesh crops it. Pure.
nonisolated struct FaceRegion: Hashable, Sendable {
    /// Centre, in upright pixels.
    var center: SIMD2<Double>
    /// Side, in upright pixels.
    var side: Double
    /// Turn of the line between the eyes from the horizontal, radians (clockwise on screen).
    var angle: Double

    /// The crop's side in pixels.
    static let cropSide = 256
    /// The crop's side over the face landmarks' extent when it follows them (MediaPipe uses 1.5; 1.4 matched its own output best
    /// on Cue takes, `tools/eyecontact`).
    static let landmarksScale = 1.4
    /// The crop's side over a Vision face box's longer side, when the face is found again.
    static let faceBoxScale = 1.7

    /// Around face landmarks (upright pixels): turned by the line from `first` to `second` (the outer eye corners), the extent of
    /// all the points along and across it, scaled.
    static func around(_ points: [SIMD2<Double>], first: SIMD2<Double>, second: SIMD2<Double>) -> FaceRegion? {
        guard !points.isEmpty else { return nil }
        let angle = atan2(second.y - first.y, second.x - first.x)
        let cosine = cos(angle), sine = sin(angle)
        // Into the face's own axes (turned back by the angle), where the extent is a plain box.
        func turned(_ point: SIMD2<Double>) -> SIMD2<Double> { SIMD2(point.x * cosine + point.y * sine, -point.x * sine + point.y * cosine) }
        var low = turned(points[0]), high = low
        for point in points.dropFirst() {
            let local = turned(point)
            low = SIMD2(min(low.x, local.x), min(low.y, local.y))
            high = SIMD2(max(high.x, local.x), max(high.y, local.y))
        }
        let middle = (low + high) / 2
        let center = SIMD2(middle.x * cosine - middle.y * sine, middle.x * sine + middle.y * cosine)
        let side = max(high.x - low.x, high.y - low.y) * landmarksScale
        return side > 1 ? FaceRegion(center: center, side: side, angle: angle) : nil
    }

    /// Around a face box (upright pixels, from Vision) turned by `roll` (radians).
    static func around(box: CGRect, roll: Double) -> FaceRegion? {
        let side = Double(max(box.width, box.height)) * faceBoxScale
        return side > 1 ? FaceRegion(center: SIMD2(Double(box.midX), Double(box.midY)), side: side, angle: roll) : nil
    }

    /// Crop pixels (0…`cropSide`, top-left origin) → upright pixels.
    var cropToUpright: CGAffineTransform {
        let scale = side / Double(Self.cropSide)
        let half = Double(Self.cropSide) / 2
        return CGAffineTransform(translationX: -half, y: -half)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(rotationAngle: angle))
            .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
    }
}
