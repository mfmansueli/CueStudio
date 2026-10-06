//
//  AuroraCardBackground.swift
//  Cue Studio
//

import SwiftUI

/// What sits behind a highlighted AI card: a soft violet aurora drifting slowly over `base`, a thin
/// light that runs around the rounded border and a yellow scan line along the bottom edge.
/// Decoration only: it takes no touches, is hidden from VoiceOver and draws behind the card's
/// content, clipped to the card's shape.
///
/// One `TimelineView` redraws just these layers (a `Canvas`, a gradient stroke and the scan line),
/// never the card's content. It pauses when the card is off screen or scrolled out, when the app is
/// not active, or when `isActive` is false, and resumes from the same frame. With Reduce Motion it
/// stays still: the aurora at rest, the border as a quiet violet line and the scan line dim in
/// the middle of the edge.
struct AuroraCardBackground: View {
    /// The card's surface: the aurora drifts over it.
    var base: Color = Palette.surface
    var cornerRadius: CGFloat = Metrics.cardRadius
    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = false
    @State private var isScrollVisible = true
    @State private var clock = MotionClock()

    private static let borderWidth: CGFloat = 1.5
    private static let scanLineHeight: CGFloat = 1.5

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            base
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isRunning)) { context in
                let time = reduceMotion ? 0 : clock.elapsed(at: context.date)
                ZStack {
                    Canvas { context, size in paintAurora(in: &context, size: size, time: time) }
                    GeometryReader { geometry in
                        border(shape, size: geometry.size, time: time)
                        scanLine(width: geometry.size.width, height: geometry.size.height, time: time)
                    }
                }
            }
        }
        .clipShape(shape)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .transaction { $0.animation = nil }
        .onAppear { isOnScreen = true }
        .onDisappear {
            isOnScreen = false
            clock.setRunning(false, at: .now)
        }
        .onScrollVisibilityChange(threshold: 0.01) { isScrollVisible = $0 }
        .onChange(of: isRunning, initial: true) { _, running in
            clock.setRunning(running, at: .now)
        }
    }

    private var isRunning: Bool {
        isActive && isOnScreen && isScrollVisible && scenePhase == .active && !reduceMotion
    }

    // MARK: - Drawing

    private func paintAurora(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let reach = max(size.width, size.height)
        for light in AuroraMotion.Light.allCases {
            let color = Self.color(of: light)
            let center = AuroraMotion.center(of: light, at: time)
            let gradient = Gradient(stops: [
                .init(color: color, location: 0),
                .init(color: color.opacity(0.4), location: 0.5),
                .init(color: color.opacity(0), location: 1),
            ])
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    gradient,
                    center: CGPoint(x: center.x * size.width, y: center.y * size.height),
                    startRadius: 0,
                    endRadius: reach * light.radius
                )
            )
        }
    }

    private static func color(of light: AuroraMotion.Light) -> Color {
        switch light {
        case .violet, .glow: Palette.Aurora.violet
        case .indigo: Palette.Aurora.indigo
        case .shade: Palette.Scripts.insetShade
        }
    }

    /// The yellow line along the bottom edge: a bright stretch that crosses it, fading at both ends.
    private func scanLine(width: CGFloat, height: CGFloat, time: TimeInterval) -> some View {
        let center = reduceMotion ? 0.5 : AuroraMotion.scanCenter(at: time)
        let length = width * AuroraMotion.scanLength
        let line = Palette.Aurora.scanLine
        return LinearGradient(
            colors: [line.opacity(0), line.opacity(reduceMotion ? 0.35 : 0.9), line.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: length, height: Self.scanLineHeight)
        .position(x: center * width, y: height - Self.scanLineHeight / 2)
    }

    /// The light along the border: it fades in and out at both ends, so it never looks like a
    /// bar with a cut end. Still, it is a faint full line.
    @ViewBuilder
    private func border(_ shape: RoundedRectangle, size: CGSize, time: TimeInterval) -> some View {
        if reduceMotion {
            shape.strokeBorder(Palette.Aurora.borderLight.opacity(0.35), lineWidth: 1)
        } else {
            let highlight = AuroraMotion.highlight(at: time, size: size)
            let share = highlight.span / (2 * .pi)
            let light = Palette.Aurora.borderLight
            shape.strokeBorder(
                AngularGradient(
                    stops: [
                        .init(color: light.opacity(0), location: 0),
                        .init(color: light.opacity(0.3), location: share * 0.5),
                        .init(color: light.opacity(0.85), location: share * 0.8),
                        .init(color: light.opacity(0), location: share),
                        .init(color: light.opacity(0), location: 1),
                    ],
                    center: .center,
                    angle: .radians(highlight.start)
                ),
                lineWidth: Self.borderWidth
            )
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        AuroraCardBackground()
            .frame(height: 180)
        AuroraCardBackground(base: Palette.surface2, cornerRadius: 20)
            .frame(height: 120)
    }
    .padding()
    .background(Palette.bg)
}
#endif
