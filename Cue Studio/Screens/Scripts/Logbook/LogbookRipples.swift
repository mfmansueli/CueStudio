//
//  LogbookRipples.swift
//  Cue Studio
//

import SwiftUI

/// The rings round the Logbook's microphone while it listens: three of them leave the circle one after the other and fade as they
/// spread, like ripples on water, reaching further when the voice is louder (`level`, 0…1). Drawn inside the button's own fixed area, so
/// nothing around it moves. Reduce Motion: one still ring. Decorative.
struct LogbookRipples: View {
    let level: Double
    /// The circle's radius while it listens: the rings leave from its edge.
    var radius: CGFloat = 65

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    private static let period: TimeInterval = 1.8
    private static let count = 3

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            Canvas { canvas, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let loudness = min(1, max(0, level))
                guard !reduceMotion else {
                    ring(&canvas, center: center, radius: radius + 10, opacity: 0.35)
                    return
                }
                let reach = 16 + 26 * loudness
                let elapsed = context.date.timeIntervalSince(start)
                for index in 0..<Self.count {
                    let phase = (elapsed / Self.period + Double(index) / Double(Self.count)).truncatingRemainder(dividingBy: 1)
                    let spread = 1 - pow(1 - phase, 2)
                    ring(&canvas, center: center, radius: radius + reach * spread, opacity: 0.5 * (1 - phase))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func ring(_ canvas: inout GraphicsContext, center: CGPoint, radius: CGFloat, opacity: Double) {
        let box = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        canvas.stroke(Path(ellipseIn: box), with: .color(Palette.acc.opacity(opacity)), lineWidth: 2)
    }
}
