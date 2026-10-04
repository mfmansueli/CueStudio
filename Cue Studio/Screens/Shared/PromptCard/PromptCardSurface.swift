//
//  PromptCardSurface.swift
//  Cue Studio
//

import SwiftUI

/// The idea card's look, from the board (3.2 `.hero`): two soft lights over `#1A1840` — violet from the top-left corner
/// (90% × 120% of the card, 55%, gone by 60%) and indigo from the bottom-right (80% × 100%, 60%, gone by 65%) — a 22 pt corner and
/// a 0.5 pt violet edge (40%), with the card's own small sky on top (`CardSky`). Without Apple Intelligence the card is plain.
struct PromptCardSurface<Content: View>: View {
    var animatesBackground = true
    /// Without Apple Intelligence the card is plain: no lights, no sky and nothing violet.
    var isNeutral = false
    /// A yellow scan line crosses the card while the field is being written in (6 s, ease in-out between 22% and 78%).
    var showsScan = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.heroRadius, style: .continuous)
        content()
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isNeutral {
                    shape.fill(Palette.surface2)
                } else {
                    PromptCardLights().clipShape(shape)
                }
            }
            .overlay {
                if !isNeutral {
                    CardSky(isActive: animatesBackground).clipShape(shape).allowsHitTesting(false)
                    PromptCardScan(isOn: showsScan && animatesBackground).clipShape(shape).allowsHitTesting(false)
                }
            }
            .overlay(shape.strokeBorder(isNeutral ? Palette.glassBorder : Palette.heroBorder, lineWidth: 0.5))
            .contentShape(shape)
    }
}

/// The two lights of the card, as ellipses sized by the card (CSS `radial-gradient(90% 120% at 0 0, …)`).
private struct PromptCardLights: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.heroBase))
            light(&context, size: size, color: Palette.heroViolet, center: .zero, rx: 0.9, ry: 1.2, stop: 0.6)
            light(&context, size: size, color: Palette.heroIndigo, center: CGPoint(x: size.width, y: size.height), rx: 0.8, ry: 1.0, stop: 0.65)
        }
        .accessibilityHidden(true)
    }

    private func light(_ context: inout GraphicsContext, size: CGSize, color: Color, center: CGPoint, rx: Double, ry: Double, stop: Double) {
        var layer = context
        layer.translateBy(x: center.x, y: center.y)
        layer.scaleBy(x: size.width * rx, y: size.height * ry)
        layer.fill(
            Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
            with: .radialGradient(Gradient(colors: [color, color.opacity(0)]), center: .zero, startRadius: 0, endRadius: stop)
        )
    }
}

/// The yellow line that crosses the card while an idea is written (`.scan`: 1.5 pt, 6 s, ease in-out, 22% ↔ 78%).
private struct PromptCardScan: View {
    let isOn: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isOn || reduceMotion)) { context in
            GeometryReader { proxy in
                let phase = reduceMotion ? 0.44 : Self.position(at: context.date.timeIntervalSinceReferenceDate)
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Palette.acc.opacity(0), Palette.acc.opacity(0.75), Palette.acc.opacity(0.75), Palette.acc.opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 1.5)
                    .shadow(color: Palette.acc.opacity(0.5), radius: 5)
                    .offset(y: proxy.size.height * phase)
            }
            .opacity(isOn ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: isOn)
        }
    }

    /// 0.22 → 0.78 → 0.22 over 6 s, eased at both ends.
    static func position(at time: TimeInterval) -> Double {
        let cycle = time.truncatingRemainder(dividingBy: 6) / 6
        let triangle = cycle < 0.5 ? cycle * 2 : (1 - cycle) * 2
        let eased = triangle * triangle * (3 - 2 * triangle)
        return 0.22 + 0.56 * eased
    }
}
