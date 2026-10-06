//
//  FaceShape.swift
//  Cue Studio
//

import CoreGraphics

/// A face's landmarks in the frame's pixels (so circles stay circles whatever the frame's shape), with what a mask needs to know about it: which way is up
/// the face (the heads in a shot are not always upright), how far it is from the brows to the chin, and the outline of the skin.
nonisolated struct FaceShape {
    let jaw: [CGPoint]
    let brows: [[CGPoint]]
    let eyes: [[CGPoint]]
    let lips: [CGPoint]
    /// The point of the jaw farthest from the brows.
    let chin: CGPoint
    let browCenter: CGPoint
    /// Unit vector from the chin to the brows, and the one across the face (from the first end of the jaw to the last).
    let up: CGVector
    let across: CGVector
    /// From the brows to the chin, and the face's width, in pixels.
    let browToChin: CGFloat
    let width: CGFloat

    init?(_ face: FaceLandmarks, frame: CGSize) {
        func pixels(_ points: [CGPoint]) -> [CGPoint] { points.map { CGPoint(x: $0.x * frame.width, y: $0.y * frame.height) } }
        jaw = pixels(face.contour)
        brows = [pixels(face.leftBrow), pixels(face.rightBrow)].filter { !$0.isEmpty }
        eyes = [pixels(face.leftEye), pixels(face.rightEye)]
        lips = pixels(face.outerLips)
        let anchor = Self.mean((brows.isEmpty ? eyes : brows).flatMap { $0 })
        guard let anchor, let chin = jaw.max(by: { Self.distance($0, anchor) < Self.distance($1, anchor) }), let first = jaw.first, let last = jaw.last
        else { return nil }
        self.chin = chin
        browCenter = anchor
        browToChin = Self.distance(anchor, chin)
        guard browToChin > 4 else { return nil }
        up = CGVector(dx: (anchor.x - chin.x) / browToChin, dy: (anchor.y - chin.y) / browToChin)
        let jawWidth = Self.distance(first, last)
        guard jawWidth > 4 else { return nil }
        across = CGVector(dx: (last.x - first.x) / jawWidth, dy: (last.y - first.y) / jawWidth)
        width = max(jawWidth, face.box.width * frame.width)
    }

    // MARK: - Outline

    /// The skin: the jaw, then up the sides of the head and over a forehead; a smooth closed curve, scaled toward its middle by `1 − 2 × inset`.
    func skinPath(inset: Double, transform: (CGPoint) -> CGPoint) -> CGPath {
        guard let first = jaw.first, let last = jaw.last else { return CGMutablePath() }
        let sideHeight = browToChin * 0.32
        let templeLast = point(last, along: up, by: sideHeight)
        let templeFirst = point(first, along: up, by: sideHeight)
        let center = CGPoint(x: (templeFirst.x + templeLast.x) / 2, y: (templeFirst.y + templeLast.y) / 2)
        let halfWidth = Self.distance(templeFirst, templeLast) / 2
        let top = point(browCenter, along: up, by: browToChin * 0.5)
        let height = max(0, (top.x - center.x) * up.dx + (top.y - center.y) * up.dy)
        var outline = jaw + [templeLast]
        for degrees in stride(from: 30.0, through: 150.0, by: 30.0) {
            let angle = degrees * .pi / 180
            outline.append(CGPoint(
                x: center.x + across.dx * halfWidth * cos(angle) + up.dx * height * sin(angle),
                y: center.y + across.dy * halfWidth * cos(angle) + up.dy * height * sin(angle)
            ))
        }
        outline.append(templeFirst)
        let middle = Self.mean(outline) ?? center
        let scale = CGFloat(1 - 2 * inset)
        let shrunk = outline.map { CGPoint(x: middle.x + ($0.x - middle.x) * scale, y: middle.y + ($0.y - middle.y) * scale) }
        return Self.smoothClosedPath(shrunk.map(transform))
    }

    /// The part of the frame the face and its forehead cover, a little over: whole pixels, inside the frame.
    func region(in frame: CGSize) -> CGRect {
        let outline = skinPath(inset: 0, transform: { $0 }).boundingBoxOfPath
        let margin = width * 0.06
        return outline.insetBy(dx: -margin, dy: -margin).integral.intersection(CGRect(origin: .zero, size: frame))
    }

    // MARK: - Features

    /// `gray` (0 to 1) over the eyes (and their lids and lashes), the brows and the lips, each wider than its outline by the share the feature needs, times
    /// `widen`: black to cut them out of a skin that is drawn white, white to draw only them.
    func paintFeatures(in context: CGContext, gray: CGFloat, transform: (CGPoint) -> CGPoint, widen: CGFloat) {
        context.setFillColor(gray: gray, alpha: 1)
        context.setStrokeColor(gray: gray, alpha: 1)
        for eye in eyes where eye.count >= 3 {
            context.addPath(Self.smoothClosedPath(Self.scaled(eye, by: 1.6 * widen).map(transform)))
            context.fillPath()
        }
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let scale = CGFloat(transform(CGPoint(x: 1, y: 0)).x - transform(.zero).x)
        context.setLineWidth(width * 0.07 * widen * abs(scale))
        for brow in brows where brow.count >= 2 {
            context.addLines(between: brow.map(transform))
            context.strokePath()
        }
        if lips.count >= 3 {
            context.addPath(Self.smoothClosedPath(Self.scaled(lips, by: 1.3 * widen).map(transform)))
            context.fillPath()
        }
    }

    /// A band across the face from just above the lips, as wide and as tall as the head: where the forehead and the cheeks are, not the beard.
    func aboveLips(transform: (CGPoint) -> CGPoint) -> CGPath {
        let lipsTop = lips.map { ($0.x - chin.x) * up.dx + ($0.y - chin.y) * up.dy }.max() ?? browToChin * 0.3
        let start = point(chin, along: up, by: lipsTop + browToChin * 0.06)
        let corners = [
            point(point(start, along: across, by: -width * 2), along: up, by: 0),
            point(point(start, along: across, by: width * 2), along: up, by: 0),
            point(point(start, along: across, by: width * 2), along: up, by: browToChin * 3),
            point(point(start, along: across, by: -width * 2), along: up, by: browToChin * 3),
        ].map(transform)
        let path = CGMutablePath()
        path.addLines(between: corners)
        path.closeSubpath()
        return path
    }

    // MARK: - Geometry

    private func point(_ origin: CGPoint, along direction: CGVector, by distance: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + direction.dx * distance, y: origin.y + direction.dy * distance)
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private static func mean(_ points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    /// `points` scaled about their mean.
    private static func scaled(_ points: [CGPoint], by factor: CGFloat) -> [CGPoint] {
        guard let middle = mean(points) else { return points }
        return points.map { CGPoint(x: middle.x + ($0.x - middle.x) * factor, y: middle.y + ($0.y - middle.y) * factor) }
    }

    /// A smooth closed curve through `points` (Catmull-Rom, as cubic Béziers).
    private static func smoothClosedPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        let count = points.count
        guard count >= 3 else { return path }
        path.move(to: points[0])
        for index in 0..<count {
            let previous = points[(index + count - 1) % count], current = points[index]
            let next = points[(index + 1) % count], after = points[(index + 2) % count]
            path.addCurve(
                to: next,
                control1: CGPoint(x: current.x + (next.x - previous.x) / 6, y: current.y + (next.y - previous.y) / 6),
                control2: CGPoint(x: next.x - (after.x - current.x) / 6, y: next.y - (after.y - current.y) / 6)
            )
        }
        path.closeSubpath()
        return path
    }
}
