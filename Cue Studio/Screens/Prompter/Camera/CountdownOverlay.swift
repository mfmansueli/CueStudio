//
//  CountdownOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Before recording starts: "LET'S CUE" and the seconds left in a ring of 12 stars that light one after another
/// while an arc fills around them. Each number comes in from 1.35× and blurred (0.22 s) and leaves in 0.2 s, with a
/// light haptic; the length is the countdown chosen in Prompter settings. Tap anywhere to cancel.
struct CountdownOverlay: View {
    /// The seconds left.
    let value: Int
    /// The countdown's length in seconds.
    let total: Int
    /// A line under the ring ("Just talk…" when the text follows the voice).
    var hint: String?
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    static let stars = 12
    private static let diameter: CGFloat = 240

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    ring
                    VStack(spacing: 0) {
                        Text("LET’S CUE")
                            .font(CueStudioFont.hud)
                            .tracking(2)
                            .foregroundStyle(Palette.accText)
                        number
                    }
                }
                .frame(width: Self.diameter, height: Self.diameter)
                if let hint {
                    Text(hint).font(.system(size: 18)).foregroundStyle(Color.white.opacity(0.9)).multilineTextAlignment(.center)
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 8)
            VStack {
                Spacer()
                Text("TAP ANYWHERE TO CANCEL")
                    .font(CueStudioFont.hud)
                    .tracking(1.5)
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.bottom, 56)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onCancel)
        .onChange(of: value) { Haptics.apply() }
        .onAppear { Haptics.apply() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Recording in \(value)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Cancels the countdown"))
        .accessibilityIdentifier("prompter.countdown")
    }

    // MARK: - Parts

    private var number: some View {
        Text("\(value)")
            .font(.system(size: 120, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .shadow(color: Palette.acc.opacity(0.35), radius: 24)
            .id(value)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .modifier(active: NumberEntry(progress: 0), identity: NumberEntry(progress: 1)),
                removal: .opacity.animation(.easeIn(duration: 0.2))
            ))
            .animation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.22), value: value)
    }

    private var ring: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let progress = reduceMotion
                ? Double(total - value + 1) / Double(total)
                : min(1, max(0, context.date.timeIntervalSince(startedAt) / Double(max(1, total))))
            Canvas { canvas, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = size.width / 2 - 14
                Self.drawArc(in: &canvas, center: center, radius: radius, progress: progress)
                for index in 0..<Self.stars {
                    let lit = progress >= Double(index) / Double(Self.stars) - 0.0001 && (index == 0 || progress > 0)
                    let age = progress * Double(Self.stars) - Double(index)
                    Self.drawStar(in: &canvas, center: center, radius: radius, index: index, isLit: lit, age: age)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private static func point(center: CGPoint, radius: CGFloat, index: Int) -> CGPoint {
        let angle = Double(index) / Double(stars) * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
    }

    private static func drawArc(in canvas: inout GraphicsContext, center: CGPoint, radius: CGFloat, progress: Double) {
        var track = Path()
        track.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        canvas.stroke(track, with: .color(.white.opacity(0.14)), lineWidth: 1)
        guard progress > 0 else { return }
        var arc = Path()
        arc.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false)
        canvas.stroke(arc, with: .color(Palette.acc), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    /// A star at rest is a faint dot; as the arc reaches it, it flashes to 1.8× and settles lit.
    private static func drawStar(in canvas: inout GraphicsContext, center: CGPoint, radius: CGFloat, index: Int, isLit: Bool, age: Double) {
        let at = point(center: center, radius: radius, index: index)
        guard isLit else {
            canvas.fill(Path(ellipseIn: CGRect(x: at.x - 2, y: at.y - 2, width: 4, height: 4)), with: .color(.white.opacity(0.3)))
            return
        }
        let flash = max(0, 1 - age / 0.8)
        let size = 13 * (1 + 0.8 * flash)
        var glow = canvas
        glow.addFilter(.shadow(color: Palette.acc.opacity(0.9), radius: 6 + 6 * flash))
        glow.fill(sparkle(at: at, size: size), with: .color(Palette.acc))
    }

    /// A four-point star.
    private static func sparkle(at point: CGPoint, size: CGFloat) -> Path {
        let outer = size / 2
        let inner = outer * 0.28
        var path = Path()
        for step in 0..<8 {
            let radius = step.isMultiple(of: 2) ? outer : inner
            let angle = Double(step) * .pi / 4 - .pi / 2
            let corner = CGPoint(x: point.x + radius * CGFloat(cos(angle)), y: point.y + radius * CGFloat(sin(angle)))
            if step == 0 { path.move(to: corner) } else { path.addLine(to: corner) }
        }
        path.closeSubpath()
        return path
    }

    /// The number coming in: from 1.35× and blurred (10 pt) to its place.
    private struct NumberEntry: ViewModifier {
        var progress: Double

        func body(content: Content) -> some View {
            content
                .scaleEffect(1.35 - 0.35 * progress)
                .blur(radius: 10 * (1 - progress))
                .opacity(progress)
        }
    }
}

/// The flare when the countdown ends and recording starts: a burst of light, over in 0.6 s.
struct CountdownFlare: View {
    let trigger: Int

    var body: some View {
        IgniteEffect(trigger: trigger, diameter: 28)
            .scaleEffect(4)
            .onChange(of: trigger) { Haptics.record() }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
