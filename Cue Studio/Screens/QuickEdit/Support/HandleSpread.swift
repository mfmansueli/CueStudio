//
//  HandleSpread.swift
//  Cue Studio
//

import CoreGraphics

/// Where a shape's handles go on the preview so a finger always reaches each one, whatever the shape's size (a mask on a small
/// window, a Blur area over an eye). Each handle starts where it means (a side, a corner, past an edge) and, when a handle
/// placed before it, or the shape's middle (kept free to drag the shape by), is closer than a finger needs, it moves out
/// along its own way until there's room. One with no room on its side of the preview goes to the other side when it has one
/// (a mask's single width tab, which pulls both sides anyway); else, brought onto the preview, a handle that crowds another
/// there takes the nearest free spot around it (a small shape in a corner of the preview). Pure, so the layout is tested
/// without a screen.
nonisolated enum HandleSpread {
    struct Handle: Equatable, Sendable {
        let id: String
        /// The point it belongs to: the side or corner of the outline it changes, or where ↻ and the soft-edge arrow stand.
        let anchor: CGPoint
        /// The way it moves out when crowded, from the shape's middle outwards.
        let outward: CGVector
        /// The same handle on the shape's other side, used when its own side has no room on the preview.
        let otherSide: Side?

        init(_ id: String, at anchor: CGPoint, outward: CGVector, otherSide: (anchor: CGPoint, outward: CGVector)? = nil) {
            self.id = id
            self.anchor = anchor
            self.outward = Self.unit(outward)
            self.otherSide = otherSide.map { Side(anchor: $0.anchor, outward: Self.unit($0.outward)) }
        }

        private static func unit(_ vector: CGVector) -> CGVector {
            let length = (vector.dx * vector.dx + vector.dy * vector.dy).squareRoot()
            return length > 0 ? CGVector(dx: vector.dx / length, dy: vector.dy / length) : .zero
        }
    }

    /// A handle's other side: the point it belongs to there and its way out.
    struct Side: Equatable, Sendable {
        let anchor: CGPoint
        let outward: CGVector
    }

    /// Where a handle sits, and the point of the shape it belongs to (its anchor, or its other side's).
    struct Spot: Equatable, Sendable {
        let point: CGPoint
        let anchor: CGPoint
    }

    /// Each handle's spot, in the order given (the first ones keep theirs): never closer than `spacing` to the shape's middle
    /// (`center`) or to another, and at least `margin` inside `bounds`.
    static func place(_ handles: [Handle], around center: CGPoint, in bounds: CGRect, spacing: CGFloat, margin: CGFloat) -> [String: Spot] {
        var placed: [CGPoint] = [center]
        var spots: [String: Spot] = [:]
        let inside = bounds.insetBy(dx: margin, dy: margin)
        for handle in handles {
            var anchor = handle.anchor
            var point = spread(from: handle.anchor, along: handle.outward, clearOf: placed, by: spacing)
            if !fits(point, in: inside), let other = handle.otherSide {
                let flipped = spread(from: other.anchor, along: other.outward, clearOf: placed, by: spacing)
                if fits(flipped, in: inside) {
                    point = flipped
                    anchor = other.anchor
                }
            }
            point = clamped(point, in: inside)
            // Brought back onto the preview it may crowd one again: the nearest free spot around it, the middle kept free if it can be.
            if placed.contains(where: { distance($0, point) < spacing - 0.01 }) {
                point = nearestFree(to: point, avoiding: placed, spacing: spacing, in: inside)
                    ?? nearestFree(to: point, avoiding: Array(placed.dropFirst()), spacing: spacing, in: inside)
                    ?? point
            }
            placed.append(point)
            spots[handle.id] = Spot(point: point, anchor: anchor)
        }
        return spots
    }

    // MARK: - Geometry

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    /// From `anchor`, out along `way` past every one of `others` it crowds: each push only moves it further from the middle.
    private static func spread(from anchor: CGPoint, along way: CGVector, clearOf others: [CGPoint], by spacing: CGFloat) -> CGPoint {
        var point = anchor
        for _ in 0...others.count {
            guard let crowded = others.first(where: { distance($0, point) < spacing - 0.01 }) else { break }
            point = pushed(point, along: way == .zero ? away(from: crowded, to: point) : way, clearOf: crowded, by: spacing)
        }
        return point
    }

    /// `point` moved along `way` (a unit vector) just far enough to be `spacing` from `other`.
    private static func pushed(_ point: CGPoint, along way: CGVector, clearOf other: CGPoint, by spacing: CGFloat) -> CGPoint {
        let wx = point.x - other.x, wy = point.y - other.y
        let along = wx * way.dx + wy * way.dy
        let gap = wx * wx + wy * wy - spacing * spacing
        let step = -along + max(0, along * along - gap).squareRoot()
        return CGPoint(x: point.x + way.dx * max(0, step), y: point.y + way.dy * max(0, step))
    }

    private static func away(from other: CGPoint, to point: CGPoint) -> CGVector {
        let dx = point.x - other.x, dy = point.y - other.y
        let length = (dx * dx + dy * dy).squareRoot()
        return length > 0.01 ? CGVector(dx: dx / length, dy: dy / length) : CGVector(dx: 0, dy: -1)
    }

    private static func fits(_ point: CGPoint, in rect: CGRect) -> Bool {
        point.x >= rect.minX - 0.5 && point.x <= rect.maxX + 0.5 && point.y >= rect.minY - 0.5 && point.y <= rect.maxY + 0.5
    }

    private static func clamped(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, rect.minX), max(rect.minX, rect.maxX)), y: min(max(point.y, rect.minY), max(rect.minY, rect.maxY)))
    }

    /// The free spot closest to `point` on `rect`, `spacing` from every one of `others`, looked for on rings around it.
    private static func nearestFree(to point: CGPoint, avoiding others: [CGPoint], spacing: CGFloat, in rect: CGRect) -> CGPoint? {
        for radius in stride(from: CGFloat(6), through: spacing * 4, by: 6) {
            let ring = (0..<24).map { step -> CGPoint in
                let angle = CGFloat(step) / 24 * 2 * .pi
                return CGPoint(x: point.x + cos(angle) * radius, y: point.y + sin(angle) * radius)
            }
            let free = ring.filter { spot in fits(spot, in: rect) && others.allSatisfy { distance($0, spot) >= spacing - 0.01 } }
            if let best = free.min(by: { distance($0, point) < distance($1, point) }) { return best }
        }
        return nil
    }
}
