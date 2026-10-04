//
//  HorizonLine.swift
//  Cue Studio
//

import SwiftUI

/// The reading line, the signature of the brand: a 2 pt yellow line with fading ends and a soft glow, and
/// a small arrow at the left. It breathes on a 2.4 s cycle; when the text follows the voice its glow can
/// flicker with the input level. Still under Reduce Motion.
struct HorizonLine: View {
    /// 0...1 voice level; nil keeps the line breathing.
    var level: Double?
    var showsArrow = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let breath = reduceMotion ? 1 : Self.breath(at: context.date.timeIntervalSinceReferenceDate)
            let glow = level.map { 0.75 + 0.25 * min(1, max(0, $0)) } ?? breath
            HStack(spacing: 0) {
                if showsArrow {
                    Triangle()
                        .fill(Palette.acc)
                        .frame(width: 8, height: 12)
                        .shadow(color: Palette.acc.opacity(0.8), radius: 4)
                }
                Capsule()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Palette.acc.opacity(0), location: 0),
                            .init(color: Palette.acc, location: 0.08),
                            .init(color: Palette.acc, location: 0.92),
                            .init(color: Palette.acc.opacity(0), location: 1),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 2)
                    .shadow(color: Palette.acc.opacity(0.8 * glow), radius: 7)
                    .shadow(color: Palette.acc.opacity(0.35 * glow), radius: 20)
                    .opacity(0.8 + 0.2 * glow)
            }
        }
        .accessibilityHidden(true)
    }

    /// 0.75...1 over one 2.4 s breath.
    static func breath(at time: TimeInterval) -> Double {
        0.875 + 0.125 * sin(time / CueMotion.Duration.horizonBreath * 2 * .pi)
    }

    private nonisolated struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

#if DEBUG
#Preview {
    HorizonLine().padding().background(Palette.bg)
}
#endif
