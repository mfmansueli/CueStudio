//
//  SpeedCurve.swift
//  Cue Studio
//

import Foundation

/// Speed › Curve: a clip that speeds up and slows down as it plays. The speed is set at a few points along the clip's stretch
/// of the recording (0 is its start, 1 its end) and flows smoothly between them (a monotone cubic through the points, on a
/// logarithmic scale, so 0.5× and 2× are as far from 1× and the curve never overshoots a point). Where each moment of the
/// recording lands in the edit is the time it takes to get there at those speeds (the integral of 1 / speed), measured once on
/// a fine table, so the picture never steps and the timeline, the preview and the export agree. Pure.
nonisolated struct SpeedCurve: Codable, Hashable, Sendable {
    struct Point: Codable, Hashable, Sendable {
        /// Where along the clip, 0 to 1.
        var position: Double
        /// Times the speed it was filmed at.
        var speed: Double
    }

    /// Slowest and fastest a curve plays.
    static let speedRange: ClosedRange<Double> = 0.2...5
    /// Steps of the table the timing is read from.
    static let steps = 240

    /// In order of position, the first at 0 and the last at 1.
    let points: [Point]
    /// The ready-made curve it is; nil when the creator shaped it.
    let preset: SpeedCurvePreset?
    /// ∫ 1 / speed from 0 to each step's position (`steps` + 1 values): the edited share of the clip at each step.
    private let table: [Double]

    init(points: [Point], preset: SpeedCurvePreset? = nil) {
        var sorted = points
            .filter { $0.position.isFinite && $0.speed.isFinite }
            .map { Point(position: min(max($0.position, 0), 1), speed: min(max($0.speed, Self.speedRange.lowerBound), Self.speedRange.upperBound)) }
            .sorted { $0.position < $1.position }
        if sorted.isEmpty { sorted = [Point(position: 0, speed: 1), Point(position: 1, speed: 1)] }
        if let first = sorted.first, first.position > 0 { sorted.insert(Point(position: 0, speed: first.speed), at: 0) }
        if let last = sorted.last, last.position < 1 { sorted.append(Point(position: 1, speed: last.speed)) }
        self.points = sorted
        self.preset = preset
        table = Self.integrate(sorted)
    }

    // MARK: - Speed

    /// The speed at `position` (0 to 1 along the clip).
    func speed(at position: Double) -> Double {
        exp(Self.logSpeed(at: position, points: points))
    }

    /// Edited seconds a clip of `sourceLength` seconds of the recording plays for.
    func editedLength(sourceLength: TimeInterval) -> TimeInterval {
        sourceLength * (table.last ?? 1)
    }

    /// Seconds into the clip in the edit where `offset` seconds into its `sourceLength` of recording play.
    func editedOffset(forSource offset: TimeInterval, sourceLength: TimeInterval) -> TimeInterval {
        guard sourceLength > 0 else { return 0 }
        let position = min(max(offset / sourceLength, 0), 1)
        let scaled = position * Double(Self.steps)
        let index = min(Int(scaled), Self.steps - 1)
        let part = scaled - Double(index)
        return sourceLength * (table[index] + (table[index + 1] - table[index]) * part)
    }

    /// Seconds into its `sourceLength` of recording shown `offset` seconds into the clip in the edit.
    func sourceOffset(forEdited offset: TimeInterval, sourceLength: TimeInterval) -> TimeInterval {
        guard sourceLength > 0, let total = table.last, total > 0 else { return 0 }
        let target = min(max(offset / sourceLength, 0), total)
        // The step holding it.
        var low = 0, high = Self.steps
        while high - low > 1 {
            let middle = (low + high) / 2
            if table[middle] <= target { low = middle } else { high = middle }
        }
        let span = table[high] - table[low]
        let part = span > 0 ? (target - table[low]) / span : 0
        return sourceLength * (Double(low) + part) / Double(Self.steps)
    }

    /// The curve over part of the clip (`from` to `to`, 0 to 1), as a curve of its own: what each side of a split keeps.
    func part(from start: Double, to end: Double) -> SpeedCurve {
        let low = min(max(start, 0), 1), high = min(max(end, low + 0.000_1), 1)
        let inside = points.filter { $0.position > low + 0.000_1 && $0.position < high - 0.000_1 }
        let ends = [Point(position: low, speed: speed(at: low))] + inside + [Point(position: high, speed: speed(at: high))]
        // Between the kept points, enough samples that the shape stays the same.
        var sampled: [Point] = []
        for (from, to) in zip(ends, ends.dropFirst()) {
            sampled.append(from)
            for step in 1..<8 {
                let position = from.position + (to.position - from.position) * Double(step) / 8
                sampled.append(Point(position: position, speed: speed(at: position)))
            }
        }
        sampled.append(ends[ends.count - 1])
        return SpeedCurve(points: sampled.map { Point(position: ($0.position - low) / (high - low), speed: $0.speed) })
    }

    // MARK: - Math

    /// The log of the speed at `position`: Fritsch–Carlson monotone cubic through the points.
    private static func logSpeed(at position: Double, points: [Point]) -> Double {
        let xs = points.map(\.position), ys = points.map { log($0.speed) }
        guard xs.count > 1 else { return ys.first ?? 0 }
        let x = min(max(position, 0), 1)
        var index = 0
        while index < xs.count - 2, x > xs[index + 1] { index += 1 }
        let tangents = monotoneTangents(xs, ys)
        let h = xs[index + 1] - xs[index]
        guard h > 0 else { return ys[index] }
        let t = (x - xs[index]) / h
        let t2 = t * t, t3 = t2 * t
        return (2 * t3 - 3 * t2 + 1) * ys[index] + (t3 - 2 * t2 + t) * h * tangents[index]
            + (-2 * t3 + 3 * t2) * ys[index + 1] + (t3 - t2) * h * tangents[index + 1]
    }

    private static func monotoneTangents(_ xs: [Double], _ ys: [Double]) -> [Double] {
        let count = xs.count
        var slopes: [Double] = []
        for index in 0..<(count - 1) {
            let h = xs[index + 1] - xs[index]
            slopes.append(h > 0 ? (ys[index + 1] - ys[index]) / h : 0)
        }
        var tangents = [Double](repeating: 0, count: count)
        tangents[0] = slopes[0]
        tangents[count - 1] = slopes[count - 2]
        for index in 1..<(count - 1) {
            tangents[index] = slopes[index - 1] * slopes[index] <= 0 ? 0 : (slopes[index - 1] + slopes[index]) / 2
        }
        for index in 0..<(count - 1) {
            guard slopes[index] != 0 else {
                tangents[index] = 0
                tangents[index + 1] = 0
                continue
            }
            let a = tangents[index] / slopes[index], b = tangents[index + 1] / slopes[index]
            let length = a * a + b * b
            if length > 9 {
                let scale = 3 / sqrt(length)
                tangents[index] = scale * a * slopes[index]
                tangents[index + 1] = scale * b * slopes[index]
            }
        }
        return tangents
    }

    /// ∫ 1 / speed on `steps` steps (Simpson on each).
    private static func integrate(_ points: [Point]) -> [Double] {
        var table = [0.0]
        table.reserveCapacity(steps + 1)
        let step = 1 / Double(steps)
        var total = 0.0
        for index in 0..<steps {
            let a = Double(index) * step, b = a + step
            let fa = 1 / exp(logSpeed(at: a, points: points))
            let fm = 1 / exp(logSpeed(at: (a + b) / 2, points: points))
            let fb = 1 / exp(logSpeed(at: b, points: points))
            total += step / 6 * (fa + 4 * fm + fb)
            table.append(total)
        }
        return table
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case points, preset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            points: try container.decode([Point].self, forKey: .points),
            preset: try? container.decodeIfPresent(SpeedCurvePreset.self, forKey: .preset)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(points, forKey: .points)
        try container.encodeIfPresent(preset, forKey: .preset)
    }

    static func == (lhs: SpeedCurve, rhs: SpeedCurve) -> Bool {
        lhs.points == rhs.points && lhs.preset == rhs.preset
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(points)
        hasher.combine(preset)
    }
}
