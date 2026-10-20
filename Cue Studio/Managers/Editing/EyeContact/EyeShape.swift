//
//  EyeShape.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// One eye as the face landmarks found it in a frame (`FaceMeshModel`): its opening's outline, 16 points from the outer corner
/// along the lower lid to the inner corner and back along the upper lid, and its iris (centre and radius), on the top-left unit square
/// of the recording's upright frame (the radius in widths of the frame). Which eye it is comes from where it is in the picture (the
/// one on the image's left or right), so a mirrored recording is read the same way.
nonisolated struct EyeShape: Hashable, Sendable {
    /// Outline points: 0 is the outer corner, 1–7 the lower lid (outer to inner), 8 the inner corner, 9–15 the upper lid (inner to
    /// outer).
    var contour: [SIMD2<Double>]
    var iris: SIMD2<Double>
    var irisRadius: Double

    /// The eye's frame in pixels: see `frame`.
    typealias Frame = (center: SIMD2<Double>, across: SIMD2<Double>, down: SIMD2<Double>, width: Double)

    static let pointCount = 16
    static let outerCorner = 0
    static let innerCorner = 8
    /// The lower lid's points, outer corner to inner corner (both included).
    static let lowerLid = Array(0...8)
    /// The upper lid's points, inner corner to outer corner (both included).
    static let upperLid = [8, 9, 10, 11, 12, 13, 14, 15, 0]

    init(contour: [SIMD2<Double>], iris: SIMD2<Double>, irisRadius: Double) {
        self.contour = contour
        self.iris = iris
        self.irisRadius = irisRadius
    }

    var isComplete: Bool { contour.count == Self.pointCount }

    var outerCorner: SIMD2<Double> { contour[Self.outerCorner] }
    var innerCorner: SIMD2<Double> { contour[Self.innerCorner] }

    /// The same eye in pixels of a frame of `size`.
    func scaled(to size: CGSize) -> EyeShape {
        let scale = SIMD2(Double(size.width), Double(size.height))
        return EyeShape(contour: contour.map { $0 * scale }, iris: iris * scale, irisRadius: irisRadius * Double(size.width))
    }

    /// The eye's frame in pixels (call it on a `scaled` eye): the corners' midpoint, the unit vector from the eye's image-left corner
    /// to its image-right one (`across`), the one turned a quarter clockwise (`down`, toward the lower lid when upright) and the
    /// distance between the corners.
    var frame: Frame {
        let (left, right) = outerCorner.x < innerCorner.x ? (outerCorner, innerCorner) : (innerCorner, outerCorner)
        let width = max(0.000_001, ((right - left) * (right - left)).sum().squareRoot())
        let across = (right - left) / width
        return ((left + right) / 2, across, SIMD2(-across.y, across.x), width)
    }

    /// How open the eye is: the lids' mean gap over its middle over the corners' distance (about 0.25 to 0.4 open, under 0.1
    /// closed). Call it on a `scaled` eye.
    var openness: Double {
        let frame = frame
        let gaps = [0.3, 0.4, 0.5, 0.6, 0.7].map { share -> Double in
            let along = (share - 0.5) * frame.width
            return lid(Self.lowerLid, at: along, frame: frame) - lid(Self.upperLid, at: along, frame: frame)
        }
        return max(0, gaps.reduce(0, +) / Double(gaps.count)) / frame.width
    }

    /// Where the iris is from the corners' midpoint, across and down, in eye widths. Call it on a `scaled` eye.
    var irisOffset: SIMD2<Double> {
        let frame = frame
        let offset = iris - frame.center
        return SIMD2((offset * frame.across).sum(), (offset * frame.down).sum()) / frame.width
    }

    /// How far down (along `frame.down`) a lid is at `along` (along `frame.across`) from the corners' midpoint, in pixels: linear
    /// between its points.
    func lid(_ indices: [Int], at along: Double, frame: Frame) -> Double {
        let points = indices.map { index -> SIMD2<Double> in
            let offset = contour[index] - frame.center
            return SIMD2((offset * frame.across).sum(), (offset * frame.down).sum())
        }.sorted { $0.x < $1.x }
        guard let first = points.first, let last = points.last else { return 0 }
        if along <= first.x { return first.y }
        if along >= last.x { return last.y }
        for (a, b) in zip(points, points.dropFirst()) where along <= b.x {
            let t = b.x > a.x ? (along - a.x) / (b.x - a.x) : 0
            return a.y + (b.y - a.y) * t
        }
        return last.y
    }
}
