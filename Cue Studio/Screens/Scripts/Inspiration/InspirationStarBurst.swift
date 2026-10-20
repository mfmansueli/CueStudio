//
//  InspirationStarBurst.swift
//  Cue Studio
//

import SwiftUI

/// What "Another idea" looks like, around the card: as the idea leaves, a ring of small four-pointed sparkles lights along the card's edge,
/// one after the other, drifts outward and goes out in 0.65 s (violet and white, and now and then the app's yellow), while the next card
/// comes in under them. Drawn only while it plays, so nothing keeps drawing on a card that is being read. Nothing under Reduce Motion
/// (the cards only cross-fade). Decorative.
struct InspirationStarBurst: View {
    /// Goes up with each new idea: each value plays once.
    let trigger: Int

    static let duration: TimeInterval = 0.65
    /// How far past the card's edge the sparkles go: the view is laid out this much bigger than the card.
    static let reach: CGFloat = 22

    private static let count = 14
    /// Each sparkle's own life, inside `duration`: the last one lights `duration - life` after the first.
    private static let life = 0.42

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

    /// Each sparkle sits on the card's edge (the view is `reach` bigger on every side), lights a beat after the one before it around the
    /// card, swells and turns as it drifts outward, then shrinks away; a soft halo lights behind it.
    private func draw(in canvas: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let card = CGRect(origin: .zero, size: size).insetBy(dx: Self.reach, dy: Self.reach)
        var generator = SeededGenerator(seed: UInt64(truncatingIfNeeded: trigger) &* 2_654_435_761 &+ 1)
        let lead = Self.duration - Self.life
        for index in 0..<Self.count {
            // Spread around the edge, a little loose so it never reads as a pattern.
            let around = (Double(index) + Double.random(in: 0.15...0.85, using: &generator)) / Double(Self.count)
            let (point, outward) = Self.edge(of: card, at: around)
            let drift = Double.random(in: 7...Double(Self.reach) - 4, using: &generator)
            let size = Double.random(in: 3.2...6.4, using: &generator)
            let spin = Double.random(in: -50...50, using: &generator)
            let delay = lead * Double(index) / Double(Self.count - 1)
            let local = (elapsed - delay) / Self.life
            guard local > 0, local < 1 else { continue }
            // Swells fast and shrinks slow; drifts out eased.
            let swell = sin(.pi * pow(local, 0.7))
            let travel = 1 - pow(1 - local, 3)
            let center = CGPoint(x: point.x + outward.dx * drift * travel, y: point.y + outward.dy * drift * travel)
            let color: Color = index % 5 == 2 ? Palette.acc : (index.isMultiple(of: 2) ? Palette.Scripts.tipGlyph : Palette.aiTextStrong)
            let radius = size * swell
            canvas.fill(
                Path(ellipseIn: CGRect(x: center.x - radius * 1.6, y: center.y - radius * 1.6, width: radius * 3.2, height: radius * 3.2)),
                with: .color(color.opacity(0.18 * swell))
            )
            canvas.fill(Self.sparkle(at: center, radius: radius, turn: .degrees(spin * local)), with: .color(color.opacity(0.95 * swell)))
        }
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
