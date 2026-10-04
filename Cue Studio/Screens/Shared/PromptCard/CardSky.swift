//
//  CardSky.swift
//  Cue Studio
//

import SwiftUI

/// The card's own small sky (v29 · 02-Tokens "Card ambient sky"): a little dust, four twinkles on the board's 3.2 s keyframes —
/// two of them with the phone-camera cross glint — and a shooting star every 11 s (130 × 1.5 pt, 160°, ~0.66 s). Quiet and
/// low: it sits behind the words. Still under Reduce Motion (the twinkles at rest, no shooting star), and paused when the card is covered.
struct CardSky: View {
    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private struct Twinkle {
        let x: Double
        let y: Double
        let size: Double
        let period: Double
        let delay: Double
        let hasCross: Bool
        let tint: Color
    }

    private static let twinkles = [
        Twinkle(x: 0.74, y: 0.22, size: 3, period: 4.1, delay: 1.3, hasCross: true, tint: Color(hex: 0xFFF3C4)),
        Twinkle(x: 0.52, y: 0.62, size: 2, period: 3.0, delay: 2.1, hasCross: false, tint: Color(hex: 0xE4DEFF)),
        Twinkle(x: 0.17, y: 0.34, size: 2.6, period: 3.4, delay: 0, hasCross: true, tint: .white),
        Twinkle(x: 0.9, y: 0.78, size: 1.8, period: 2.8, delay: 1.7, hasCross: false, tint: .white),
    ]

    /// Opacity and scale of the board's `@keyframes twinkle` at a point of its cycle.
    private static let keyframes: [(at: Double, opacity: Double, scale: Double)] = [
        (0, 0.2, 0.7), (0.12, 1, 1.25), (0.22, 0.45, 0.85), (0.38, 0.95, 1.1), (0.55, 0.25, 0.75), (0.72, 1, 1.3), (0.86, 0.5, 0.9), (1, 0.2, 0.7),
    ]

    private var isRunning: Bool { isActive && !reduceMotion && scenePhase == .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isRunning)) { context in
            Canvas { canvas, size in
                let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                dust(&canvas, size: size)
                for twinkle in Self.twinkles { draw(twinkle, in: &canvas, size: size, time: time) }
                if !reduceMotion { shootingStar(&canvas, size: size, time: time) }
            }
        }
        .accessibilityHidden(true)
    }

    private func dust(_ canvas: inout GraphicsContext, size: CGSize) {
        let points: [(Double, Double, Double)] = [
            (0.08, 0.1, 0.5), (0.31, 0.46, 0.35), (0.62, 0.12, 0.45), (0.83, 0.5, 0.4), (0.44, 0.88, 0.3), (0.95, 0.15, 0.4),
        ]
        for (x, y, alpha) in points {
            let rect = CGRect(x: size.width * x - 0.5, y: size.height * y - 0.5, width: 1, height: 1)
            canvas.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
        }
    }

    private func draw(_ twinkle: Twinkle, in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let cycle = ((time - twinkle.delay) / twinkle.period).truncatingRemainder(dividingBy: 1)
        let (opacity, scale) = Self.value(at: cycle < 0 ? cycle + 1 : cycle)
        let center = CGPoint(x: size.width * twinkle.x, y: size.height * twinkle.y)
        let radius = twinkle.size / 2 * scale
        let glow = radius * 2.4
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
            with: .radialGradient(Gradient(colors: [twinkle.tint.opacity(0.45 * opacity), .clear]), center: center, startRadius: 0, endRadius: glow)
        )
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(twinkle.tint.opacity(opacity))
        )
        guard twinkle.hasCross else { return }
        for horizontal in [true, false] {
            var line = Path()
            line.move(to: CGPoint(x: center.x - (horizontal ? 8 : 0), y: center.y - (horizontal ? 0 : 8)))
            line.addLine(to: CGPoint(x: center.x + (horizontal ? 8 : 0), y: center.y + (horizontal ? 0 : 8)))
            canvas.stroke(
                line,
                with: .linearGradient(
                    Gradient(colors: [.white.opacity(0), .white.opacity(0.9 * opacity), .white.opacity(0)]),
                    startPoint: CGPoint(x: center.x - (horizontal ? 8 : 0), y: center.y - (horizontal ? 0 : 8)),
                    endPoint: CGPoint(x: center.x + (horizontal ? 8 : 0), y: center.y + (horizontal ? 0 : 8))
                ),
                lineWidth: 1
            )
        }
    }

    /// Linear interpolation of the keyframes.
    static func value(at cycle: Double) -> (opacity: Double, scale: Double) {
        for index in 1..<keyframes.count where cycle <= keyframes[index].at {
            let from = keyframes[index - 1], to = keyframes[index]
            let t = (cycle - from.at) / (to.at - from.at)
            return (from.opacity + (to.opacity - from.opacity) * t, from.scale + (to.scale - from.scale) * t)
        }
        return (0.2, 0.7)
    }

    /// 1% → 6% of an 11 s cycle (0.66 s): it flies from the right, 380 pt along 160°, and fades.
    private func shootingStar(_ canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let cycle = (time + 3.5).truncatingRemainder(dividingBy: 11) / 11
        guard cycle > 0.01, cycle < 0.06 else { return }
        let progress = (cycle - 0.01) / 0.05
        let angle = 160.0 * .pi / 180
        let direction = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
        let start = CGPoint(x: size.width * 0.9, y: size.height * 0.06)
        let travelled = -60 + 380 * progress
        let head = CGPoint(x: start.x + direction.x * travelled, y: start.y + direction.y * travelled)
        let tail = CGPoint(x: head.x - direction.x * 130, y: head.y - direction.y * 130)
        let alpha = progress < 0.2 ? progress / 0.2 : 1 - (progress - 0.2) / 0.8
        var line = Path()
        line.move(to: tail)
        line.addLine(to: head)
        canvas.stroke(
            line,
            with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.9 * alpha)]), startPoint: tail, endPoint: head),
            lineWidth: 1.5
        )
    }
}
