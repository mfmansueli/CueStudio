//
//  FaceLandmarks.swift
//  Cue Studio
//

import CoreGraphics

/// A face found in a frame, and the outlines of what is not skin on it, all in the frame's own unit square: x and y from 0 to 1, y up from the bottom
/// edge (Vision's and Core Image's). A frame of any size gives the same numbers for the same shot.
nonisolated struct FaceLandmarks: Hashable, Sendable {
    /// The face from the brows to the chin.
    var box: CGRect
    /// The jaw, from one ear round the chin to the other.
    var contour: [CGPoint]
    var leftEye: [CGPoint]
    var rightEye: [CGPoint]
    var leftBrow: [CGPoint]
    var rightBrow: [CGPoint]
    var outerLips: [CGPoint]
    var innerLips: [CGPoint]

    init(
        box: CGRect, contour: [CGPoint], leftEye: [CGPoint], rightEye: [CGPoint], leftBrow: [CGPoint], rightBrow: [CGPoint],
        outerLips: [CGPoint], innerLips: [CGPoint]
    ) {
        self.box = box
        self.contour = contour
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.leftBrow = leftBrow
        self.rightBrow = rightBrow
        self.outerLips = outerLips
        self.innerLips = innerLips
    }

    /// Enough of a face to draw a mask: a jaw, both eyes and the lips.
    var isUsable: Bool {
        contour.count >= 5 && leftEye.count >= 3 && rightEye.count >= 3 && outerLips.count >= 3
    }

    var center: CGPoint { CGPoint(x: box.midX, y: box.midY) }

    /// These landmarks carried `offset` (in the frame's unit square) along.
    func translated(by offset: CGVector) -> FaceLandmarks {
        func shift(_ points: [CGPoint]) -> [CGPoint] { points.map { CGPoint(x: $0.x + offset.dx, y: $0.y + offset.dy) } }
        return FaceLandmarks(
            box: box.offsetBy(dx: offset.dx, dy: offset.dy), contour: shift(contour), leftEye: shift(leftEye), rightEye: shift(rightEye),
            leftBrow: shift(leftBrow), rightBrow: shift(rightBrow), outerLips: shift(outerLips), innerLips: shift(innerLips)
        )
    }

    /// These landmarks moved `rate` (0…1) of the way to `other`: where a face is when a new detection says a little different than the last. Outlines with
    /// another number of points (a different Vision revision) are taken whole.
    func moved(toward other: FaceLandmarks, rate: Double) -> FaceLandmarks {
        let amount = CGFloat(min(max(rate, 0), 1))
        func mix(_ from: CGPoint, _ to: CGPoint) -> CGPoint {
            CGPoint(x: from.x + (to.x - from.x) * amount, y: from.y + (to.y - from.y) * amount)
        }
        func mix(_ from: [CGPoint], _ to: [CGPoint]) -> [CGPoint] {
            from.count == to.count ? zip(from, to).map { mix($0, $1) } : to
        }
        let origin = mix(box.origin, other.box.origin)
        let corner = mix(CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: other.box.maxX, y: other.box.maxY))
        return FaceLandmarks(
            box: CGRect(x: origin.x, y: origin.y, width: corner.x - origin.x, height: corner.y - origin.y),
            contour: mix(contour, other.contour), leftEye: mix(leftEye, other.leftEye), rightEye: mix(rightEye, other.rightEye),
            leftBrow: mix(leftBrow, other.leftBrow), rightBrow: mix(rightBrow, other.rightBrow),
            outerLips: mix(outerLips, other.outerLips), innerLips: mix(innerLips, other.innerLips)
        )
    }
}
