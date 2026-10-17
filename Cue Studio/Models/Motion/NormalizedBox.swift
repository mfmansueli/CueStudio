//
//  NormalizedBox.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// A rectangle on a recording's upright frame as fractions of its size, from the top left: what Vision found (a face, a body,
/// the object a text follows), whatever the recording's resolution. Stored as four numbers, so a long recording's analysis stays
/// small.
nonisolated struct NormalizedBox: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = max(0, width)
        self.height = max(0, height)
    }

    /// A box around `center`, `width` × `height`, kept inside the frame.
    init(center: CGPoint, width: Double, height: Double) {
        let w = min(1, max(0, width)), h = min(1, max(0, height))
        self.init(x: min(max(0, center.x - w / 2), 1 - w), y: min(max(0, center.y - h / 2), 1 - h), width: w, height: h)
    }

    var midX: Double { x + width / 2 }
    var midY: Double { y + height / 2 }
    var center: CGPoint { CGPoint(x: midX, y: midY) }
    var area: Double { width * height }

    /// How much two boxes cover each other (intersection over union), 0 to 1.
    func overlap(with other: NormalizedBox) -> Double {
        let shared = sharedArea(with: other)
        guard shared > 0 else { return 0 }
        let union = area + other.area - shared
        return union > 0 ? shared / union : 0
    }

    /// The area the two boxes share.
    func sharedArea(with other: NormalizedBox) -> Double {
        let left = max(x, other.x), right = min(x + width, other.x + other.width)
        let top = max(y, other.y), bottom = min(y + height, other.y + other.height)
        return right > left && bottom > top ? (right - left) * (bottom - top) : 0
    }

    /// Vision's box (lower-left origin) on the top-left one.
    static func fromVision(_ rect: CGRect) -> NormalizedBox {
        NormalizedBox(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The box in Vision's coordinates (lower-left origin).
    var visionRect: CGRect {
        CGRect(x: x, y: 1 - y - height, width: width, height: height)
    }

    // MARK: - Coding

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        x = try container.decode(Double.self)
        y = try container.decode(Double.self)
        width = try container.decode(Double.self)
        height = try container.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in [x, y, width, height] {
            try container.encode(Float(value))
        }
    }
}
