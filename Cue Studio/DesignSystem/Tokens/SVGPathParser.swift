//
//  SVGPathParser.swift
//  Cue Studio
//

import CoreGraphics
import Foundation
import SwiftUI

/// Turns the `d` of an SVG path into a SwiftUI `Path`, so the icons are drawn in code with a stroke that
/// depends on their size (see `CueIconView`). Supports what the icon set uses: M L H V C S Q A Z, absolute and
/// relative, with numbers written the compact way ("4.5.5", "-1.5", flags glued together). Elliptical arcs
/// (with rotation) are turned into cubic curves, as the SVG specification describes (F.6.5).
nonisolated enum SVGPathParser {
    static func path(from data: String) -> Path {
        var reader = Reader(Array(data.unicodeScalars))
        var builder = Builder()
        var command: Character = "M"
        while true {
            reader.skipSeparators()
            guard !reader.isAtEnd else { break }
            if let next = reader.peekCommand() {
                command = next
                reader.advance()
                if command == "Z" || command == "z" {
                    builder.close()
                    continue
                }
            } else if command == "M" {
                command = "L"
            } else if command == "m" {
                command = "l"
            }
            guard builder.apply(command, reading: &reader) else { break }
        }
        return builder.path
    }

    // MARK: - Building

    /// The path so far and where the pen is, with one method per command.
    private struct Builder {
        var path = Path()
        private var current = CGPoint.zero
        private var start = CGPoint.zero
        /// The last control point of a cubic curve, for the smooth command (S); nil after anything else.
        private var lastCubicControl: CGPoint?

        mutating func close() {
            path.closeSubpath()
            current = start
            lastCubicControl = nil
        }

        /// Reads one set of arguments for `command` and draws it. False when the data ran out or isn't understood.
        mutating func apply(_ command: Character, reading reader: inout Reader) -> Bool {
            let origin = command.isLowercase ? current : .zero
            switch command.uppercased() {
            case "M", "L": return line(command.uppercased() == "M", origin, &reader)
            case "H", "V": return axisLine(horizontal: command.uppercased() == "H", relative: command.isLowercase, &reader)
            case "C", "S": return cubic(smooth: command.uppercased() == "S", origin, &reader)
            case "Q": return quadratic(origin, &reader)
            case "A": return arc(origin, &reader)
            default: return false
            }
        }

        private mutating func line(_ isMove: Bool, _ origin: CGPoint, _ reader: inout Reader) -> Bool {
            guard let point = reader.point(relativeTo: origin) else { return false }
            if isMove {
                path.move(to: point)
                start = point
            } else {
                path.addLine(to: point)
            }
            current = point
            lastCubicControl = nil
            return true
        }

        private mutating func axisLine(horizontal: Bool, relative: Bool, _ reader: inout Reader) -> Bool {
            guard let value = reader.number() else { return false }
            if horizontal {
                current = CGPoint(x: relative ? current.x + value : value, y: current.y)
            } else {
                current = CGPoint(x: current.x, y: relative ? current.y + value : value)
            }
            path.addLine(to: current)
            lastCubicControl = nil
            return true
        }

        private mutating func cubic(smooth: Bool, _ origin: CGPoint, _ reader: inout Reader) -> Bool {
            let first: CGPoint
            if smooth {
                first = lastCubicControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
            } else {
                guard let point = reader.point(relativeTo: origin) else { return false }
                first = point
            }
            guard let second = reader.point(relativeTo: origin), let end = reader.point(relativeTo: origin) else { return false }
            path.addCurve(to: end, control1: first, control2: second)
            lastCubicControl = second
            current = end
            return true
        }

        private mutating func quadratic(_ origin: CGPoint, _ reader: inout Reader) -> Bool {
            guard let control = reader.point(relativeTo: origin), let end = reader.point(relativeTo: origin) else { return false }
            path.addQuadCurve(to: end, control: control)
            lastCubicControl = nil
            current = end
            return true
        }

        private mutating func arc(_ origin: CGPoint, _ reader: inout Reader) -> Bool {
            guard let radiusX = reader.number(), let radiusY = reader.number(), let rotation = reader.number(),
                  let large = reader.flag(), let sweep = reader.flag(), let end = reader.point(relativeTo: origin) else { return false }
            Arc(start: current, radiusX: radiusX, radiusY: radiusY, rotation: rotation, large: large, sweep: sweep, end: end)
                .add(to: &path)
            lastCubicControl = nil
            current = end
            return true
        }
    }

    // MARK: - Arcs

    /// An SVG elliptical arc, turned into cubic curves of at most a quarter turn each.
    private struct Arc {
        let start: CGPoint
        let radiusX: Double
        let radiusY: Double
        let rotation: Double
        let large: Bool
        let sweep: Bool
        let end: CGPoint

        func add(to path: inout Path) {
            var rx = abs(radiusX)
            var ry = abs(radiusY)
            guard start != end else { return }
            guard rx > 0, ry > 0 else {
                path.addLine(to: end)
                return
            }
            let phi = rotation * .pi / 180
            let cosPhi = cos(phi)
            let sinPhi = sin(phi)
            let halfDx = (start.x - end.x) / 2
            let halfDy = (start.y - end.y) / 2
            let x1 = cosPhi * halfDx + sinPhi * halfDy
            let y1 = -sinPhi * halfDx + cosPhi * halfDy
            // Radii too small to reach the end are scaled up until they do.
            let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
            if lambda > 1 {
                rx *= lambda.squareRoot()
                ry *= lambda.squareRoot()
            }
            let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
            let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
            let sign: Double = large == sweep ? -1 : 1
            let coefficient = denominator == 0 ? 0 : sign * max(0, numerator / denominator).squareRoot()
            let cx1 = coefficient * rx * y1 / ry
            let cy1 = -coefficient * ry * x1 / rx
            let centerX = cosPhi * cx1 - sinPhi * cy1 + (start.x + end.x) / 2
            let centerY = sinPhi * cx1 + cosPhi * cy1 + (start.y + end.y) / 2

            let theta = Self.angle(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
            var delta = Self.angle((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
            if !sweep, delta > 0 { delta -= 2 * .pi }
            if sweep, delta < 0 { delta += 2 * .pi }

            let segments = max(1, Int((abs(delta) / (.pi / 2) - 1e-9).rounded(.up)))
            let step = delta / Double(segments)
            let handle = 4.0 / 3.0 * tan(step / 4)

            /// A point of the ellipse at `angle`, pushed along its tangent by `tangent` (a curve's control point).
            func point(_ angle: Double, tangent: Double = 0) -> CGPoint {
                let ux = cos(angle) - tangent * sin(angle)
                let uy = sin(angle) + tangent * cos(angle)
                return CGPoint(x: centerX + rx * ux * cosPhi - ry * uy * sinPhi, y: centerY + rx * ux * sinPhi + ry * uy * cosPhi)
            }
            for index in 0..<segments {
                let from = theta + Double(index) * step
                let to = from + step
                path.addCurve(
                    to: index == segments - 1 ? end : point(to),
                    control1: point(from, tangent: handle), control2: point(to, tangent: -handle)
                )
            }
        }

        /// The signed angle from one vector to another.
        private static func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let length = (ux * ux + uy * uy).squareRoot() * (vx * vx + vy * vy).squareRoot()
            let value = acos(min(1, max(-1, (ux * vx + uy * vy) / length)))
            return ux * vy - uy * vx < 0 ? -value : value
        }
    }

    // MARK: - Reading

    /// A cursor over the path data.
    private struct Reader {
        private let scalars: [Unicode.Scalar]
        private var index = 0

        init(_ scalars: [Unicode.Scalar]) { self.scalars = scalars }

        var isAtEnd: Bool { index >= scalars.count }

        mutating func advance() { index += 1 }

        mutating func skipSeparators() {
            while index < scalars.count, scalars[index] == " " || scalars[index] == "," || scalars[index] == "\n" || scalars[index] == "\t" {
                index += 1
            }
        }

        func peekCommand() -> Character? {
            guard index < scalars.count else { return nil }
            let character = Character(scalars[index])
            return "MmLlHhVvCcSsQqAaZz".contains(character) ? character : nil
        }

        /// "-1.5", ".5", "4.5.5" (two numbers), "1e-3".
        mutating func number() -> Double? {
            skipSeparators()
            let begin = index
            if index < scalars.count, scalars[index] == "-" || scalars[index] == "+" { index += 1 }
            var seenDot = false
            while index < scalars.count {
                let scalar = scalars[index]
                if scalar.properties.numericType != nil, scalar.isASCII {
                    index += 1
                } else if scalar == ".", !seenDot {
                    seenDot = true
                    index += 1
                } else {
                    break
                }
            }
            if index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
                index += 1
                if index < scalars.count, scalars[index] == "-" || scalars[index] == "+" { index += 1 }
                while index < scalars.count, scalars[index].isASCII, scalars[index].properties.numericType != nil { index += 1 }
            }
            guard index > begin else { return nil }
            var text = ""
            text.unicodeScalars.append(contentsOf: scalars[begin..<index])
            return Double(text)
        }

        /// An arc flag: one character, 0 or 1, which may be glued to what follows.
        mutating func flag() -> Bool? {
            skipSeparators()
            guard index < scalars.count else { return nil }
            defer { index += 1 }
            switch scalars[index] {
            case "0": return false
            case "1": return true
            default: return nil
            }
        }

        mutating func point(relativeTo origin: CGPoint) -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return CGPoint(x: origin.x + x, y: origin.y + y)
        }
    }
}
