//
//  InspirationStarBurst.swift
//  Cue Studio
//

import SwiftUI

/// What "Another idea" looks like, over the card: the idea that leaves breaks into a dozen small stars that streak out and fade in
/// 0.35 s (violet and, now and then, the app's yellow), while the next card slides in under them. Drawn only while it plays, so nothing
/// keeps drawing on a card that is being read. Nothing under Reduce Motion (the cards only cross-fade). Decorative.
struct InspirationStarBurst: View {
    /// Goes up with each new idea: each value plays once.
    let trigger: Int

    static let duration: TimeInterval = 0.35

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?

    var body: some View {
        Group {
            if let start {
                TimelineView(.animation) { context in
                    let progress = min(1, context.date.timeIntervalSince(start) / Self.duration)
                    Canvas { canvas, size in draw(in: &canvas, size: size, progress: progress) }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: trigger) {
            guard trigger > 0, !reduceMotion else { return }
            start = .now
            try? await Task.sleep(for: .seconds(Self.duration + 0.05))
            if !Task.isCancelled { start = nil }
        }
    }

    /// Each star leaves from inside the card's text block, out along its own angle, with a short streak behind it; eased out, it slows
    /// as it fades.
    private func draw(in canvas: inout GraphicsContext, size: CGSize, progress: Double) {
        let eased = 1 - pow(1 - progress, 3)
        var generator = SeededGenerator(seed: UInt64(truncatingIfNeeded: trigger) &* 2_654_435_761 &+ 1)
        for index in 0..<12 {
            let origin = CGPoint(
                x: size.width * (0.18 + 0.64 * Double.random(in: 0...1, using: &generator)),
                y: size.height * (0.22 + 0.5 * Double.random(in: 0...1, using: &generator))
            )
            let angle = Double.random(in: 0...(2 * .pi), using: &generator)
            let reach = Double.random(in: 34...86, using: &generator)
            let radius = Double.random(in: 1.1...2.2, using: &generator)
            let head = CGPoint(x: origin.x + cos(angle) * reach * eased, y: origin.y + sin(angle) * reach * eased)
            let tail = CGPoint(x: origin.x + cos(angle) * reach * max(0, eased - 0.28), y: origin.y + sin(angle) * reach * max(0, eased - 0.28))
            let alpha = (1 - progress) * 0.9
            let color = index % 4 == 0 ? Palette.acc : Palette.Scripts.tipGlyph
            var streak = Path()
            streak.move(to: tail)
            streak.addLine(to: head)
            canvas.stroke(streak, with: .color(color.opacity(alpha * 0.5)), style: StrokeStyle(lineWidth: radius * 0.9, lineCap: .round))
            canvas.fill(
                Path(ellipseIn: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(alpha))
            )
        }
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
