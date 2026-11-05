//
//  InspirationStarBurst.swift
//  Cue Studio
//

import SwiftUI

/// What "Another idea" looks like, around the card: magic dust (owner, 05/11/2026). As the idea leaves, a dust of small grains lifts off the
/// card's edge and floats slowly outward, twinkling, like fairy dust; among it a few larger four-pointed sparkles twinkle twice and go out; and
/// a few grains are caught on the next card, drift a little onto it and go out there. Violet and white, now and then the app's yellow; 1.1 s in
/// all, while the next card comes in under it. Drawn only while it plays, so nothing keeps drawing on a card that is being read. Nothing under
/// Reduce Motion (the cards only cross-fade). Decorative.
struct InspirationStarBurst: View {
    /// Goes up with each new idea: each value plays once.
    let trigger: Int

    static let duration: TimeInterval = 1.1
    /// How far past the card's edge the dust goes: the view is laid out this much bigger than the card.
    static let reach: CGFloat = 26

    private static let grains = 38
    private static let sparkles = 5
    /// Grains that land on the next card instead of floating away.
    private static let caught = 7

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?

    var body: some View {
        Group {
            if let start {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    Canvas { canvas, size in draw(in: &canvas, size: size, elapsed: elapsed) }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        // Only a new idea plays it (not the view coming back on screen).
        .onChange(of: trigger) {
            guard !reduceMotion else { return }
            let started = Date.now
            start = started
            Task {
                try? await Task.sleep(for: .seconds(Self.duration + 0.05))
                if start == started { start = nil }
            }
        }
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let card = CGRect(origin: .zero, size: size).insetBy(dx: Self.reach, dy: Self.reach)
        var generator = SeededGenerator(seed: UInt64(truncatingIfNeeded: trigger) &* 2_654_435_761 &+ 1)
        // The dust: lifts off the edge in the first quarter second, floats out and up, slower and slower, twinkling as it fades.
        for index in 0..<Self.grains {
            let around = (Double(index) + Double.random(in: 0...1, using: &generator)) / Double(Self.grains)
            let (point, outward) = Self.edge(of: card, at: around)
            let delay = Double.random(in: 0...0.28, using: &generator)
            let life = Double.random(in: 0.55...0.8, using: &generator)
            let drift = Double.random(in: 6...Double(Self.reach) - 2, using: &generator)
            let sideways = Double.random(in: -8...8, using: &generator)
            let radius = Double.random(in: 0.7...1.7, using: &generator)
            let phase = Double.random(in: 0...(2 * .pi), using: &generator)
            let color = Self.color(index, generator: &generator)
            let local = (elapsed - delay) / life
            guard local > 0, local < 1 else { continue }
            let travel = 1 - pow(1 - local, 2.4)
            let tangent = CGVector(dx: -outward.dy, dy: outward.dx)
            let center = CGPoint(
                x: point.x + (outward.dx * drift + tangent.dx * sideways) * travel,
                y: point.y + (outward.dy * drift + tangent.dy * sideways) * travel - 5 * travel
            )
            let fade = min(1, local / 0.12) * pow(1 - local, 1.3)
            let twinkle = 0.7 + 0.3 * sin(phase + local * 22)
            Self.grain(in: &canvas, at: center, radius: radius, color: color, opacity: fade * twinkle)
        }
        // The larger sparkles: twice brighter, twice dimmer, and out, turning slowly.
        for index in 0..<Self.sparkles {
            let around = (Double(index) + Double.random(in: 0.2...0.8, using: &generator)) / Double(Self.sparkles)
            let (point, outward) = Self.edge(of: card, at: around)
            let delay = Double.random(in: 0.04...0.3, using: &generator)
            let life = 0.72
            let drift = Double.random(in: 6...14, using: &generator)
            let size = Double.random(in: 4.5...6.8, using: &generator)
            let spin = Double.random(in: -40...40, using: &generator)
            let color: Color = index == 2 ? Palette.acc : (index.isMultiple(of: 2) ? Palette.Scripts.tipGlyph : Palette.aiTextStrong)
            let local = (elapsed - delay) / life
            guard local > 0, local < 1 else { continue }
            let twice = abs(sin(.pi * 2 * pow(local, 0.85))) * (1 - 0.45 * local)
            let travel = 1 - pow(1 - local, 2)
            let center = CGPoint(x: point.x + outward.dx * drift * travel, y: point.y + outward.dy * drift * travel - 3 * travel)
            let radius = size * (0.35 + 0.65 * twice)
            canvas.fill(
                Path(ellipseIn: CGRect(x: center.x - radius * 1.8, y: center.y - radius * 1.8, width: radius * 3.6, height: radius * 3.6)),
                with: .color(color.opacity(0.16 * twice))
            )
            canvas.fill(Self.sparkle(at: center, radius: radius, turn: .degrees(spin * local)), with: .color(color.opacity(0.95 * twice)))
        }
        // A few grains caught by the next card: they settle a little inside its edge, glow once and go out there.
        for index in 0..<Self.caught {
            let around = (Double(index) + Double.random(in: 0.1...0.9, using: &generator)) / Double(Self.caught)
            let (point, outward) = Self.edge(of: card, at: around)
            let delay = Double.random(in: 0.3...0.5, using: &generator)
            let life = Double.random(in: 0.45...0.6, using: &generator)
            let inward = Double.random(in: 5...14, using: &generator)
            let radius = Double.random(in: 0.9...1.5, using: &generator)
            let color = Self.color(index + 1, generator: &generator)
            let local = (elapsed - delay) / life
            guard local > 0, local < 1 else { continue }
            let settle = 1 - pow(1 - local, 3)
            let center = CGPoint(x: point.x - outward.dx * inward * settle, y: point.y - outward.dy * inward * settle)
            let glow = sin(.pi * pow(local, 0.6))
            Self.grain(in: &canvas, at: center, radius: radius, color: color, opacity: glow)
        }
    }

    /// One grain of dust: a dot and a soft halo around it.
    private static func grain(in canvas: inout GraphicsContext, at center: CGPoint, radius: Double, color: Color, opacity: Double) {
        let halo = radius * 3.2
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
            with: .color(color.opacity(0.14 * opacity))
        )
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(color.opacity(0.95 * opacity))
        )
    }

    /// Mostly violet and white, one in eight the app's yellow.
    private static func color(_ index: Int, generator: inout SeededGenerator) -> Color {
        let pick = Double.random(in: 0...1, using: &generator)
        if pick < 0.125 { return Palette.acc }
        return pick < 0.56 ? Palette.Scripts.tipGlyph : Palette.aiTextStrong
    }

    /// A point on the card's edge, `fraction` of the way around it clockwise from the top-leading corner, and the way out from there.
    private static func edge(of card: CGRect, at fraction: Double) -> (CGPoint, CGVector) {
        let perimeter = 2 * (card.width + card.height)
        var distance = fraction.truncatingRemainder(dividingBy: 1) * perimeter
        if distance < card.width { return (CGPoint(x: card.minX + distance, y: card.minY), CGVector(dx: 0, dy: -1)) }
        distance -= card.width
        if distance < card.height { return (CGPoint(x: card.maxX, y: card.minY + distance), CGVector(dx: 1, dy: 0)) }
        distance -= card.height
        if distance < card.width { return (CGPoint(x: card.maxX - distance, y: card.maxY), CGVector(dx: 0, dy: 1)) }
        distance -= card.width
        return (CGPoint(x: card.minX, y: card.maxY - distance), CGVector(dx: -1, dy: 0))
    }

    /// A four-pointed star with concave sides, the app's sparkle.
    private static func sparkle(at center: CGPoint, radius: Double, turn: Angle) -> Path {
        var path = Path()
        let waist = radius * 0.22
        for point in 0..<4 {
            let angle = turn.radians + Double(point) * .pi / 2
            let tip = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            let next = angle + .pi / 4
            let notch = CGPoint(x: center.x + cos(next) * waist, y: center.y + sin(next) * waist)
            if point == 0 { path.move(to: tip) } else { path.addLine(to: tip) }
            path.addLine(to: notch)
        }
        path.closeSubpath()
        return path
    }

    /// The same stars for the same idea: a small, fast, seeded generator (SplitMix64).
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        init(seed: UInt64) { state = seed }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }
}
