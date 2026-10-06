//
//  StarfieldView.swift
//  Cue Studio
//

import SwiftUI

/// The sky of the browse screens and the onboarding: three layers of stars drifting down at their own
/// speed and two soft violet nebulae (all of Calm), and, at Lively only, 14 small twinkling stars (half with the cross glint of a
/// phone-camera star) and a comet every two minutes or so. Galactic is Lively with the colours of a galaxy (three nebulae, the Milky Way
/// band) and a spaceship in place of the comet. Never over the camera, a take or the editor.
///
/// One `Canvas` in a `TimelineView` at 30 fps (it is ambient). It stops, on a still frame, when the
/// view is off screen, the app is not active or Reduce Motion is on (Low Power Mode does not stop it), and it
/// draws nothing at all when the density is Off.
struct StarfieldView: View {
    var density: SkyDensity = .calm
    var seed: UInt64 = 27
    /// Seconds added to the app's clock when the comet's and the spaceship's schedules are read (the catalogue sends a spaceship on demand).
    var scheduleShift: TimeInterval = 0
    /// The first flight keeps the sky its boards were drawn with, whatever Calm and Lively became: its own twinkles and its comet.
    var twinkleCountOverride: Int?
    var cometOverride: Bool?
    /// How strongly the stars are drawn (delicate in the app; the first flight keeps the strength of its boards).
    var look = StarfieldMath.delicateLook

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = false
    @State private var clock = MotionClock()

    private var twinkles: [StarfieldMath.Twinkle] { StarfieldMath.twinkles(count: twinkleCountOverride ?? density.twinkleCount, seed: seed) }
    private var nebulae: [StarfieldMath.Nebula] {
        density.isGalactic ? StarfieldMath.galacticNebulae(seed: seed) : StarfieldMath.nebulae(seed: seed)
    }
    private var bandDust: [StarfieldMath.BandStar] { density.isGalactic ? StarfieldMath.bandStars(seed: seed) : [] }

    var body: some View {
        Group {
            if density != .off {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isRunning)) { context in
                    let time = clock.elapsed(at: context.date)
                    Canvas { canvas, size in
                        draw(in: &canvas, size: size, time: time)
                    }
                }
                .onAppear { isOnScreen = true }
                .onDisappear {
                    isOnScreen = false
                    clock.setRunning(false, at: .now)
                }
                .onChange(of: isRunning, initial: true) { _, running in
                    clock.setRunning(running, at: .now)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var isRunning: Bool {
        isOnScreen && scenePhase == .active && !reduceMotion
    }

    // MARK: - Drawing

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for nebula in nebulae { drawNebula(nebula, in: &canvas, size: size, time: time) }
        if density.isGalactic { GalacticSkyPainter.drawBand(in: &canvas, size: size, time: time, dust: bandDust) }
        for (index, layer) in StarfieldMath.layers.enumerated() {
            drawLayer(layer, seed: seed &+ UInt64(index) &* 101, in: &canvas, size: size, time: time)
        }
        for twinkle in twinkles { drawTwinkle(twinkle, in: &canvas, size: size, time: time) }
        let schedule = Self.sinceLaunch() + scheduleShift
        if cometOverride ?? density.hasComet, let comet = StarfieldMath.comet(at: schedule, size: size, seed: seed) {
            drawComet(comet, in: &canvas)
        }
        // A frozen frame (Reduce Motion, the app in the background) never catches a spaceship halfway.
        if density.hasSpaceship, isRunning, let ship = StarfieldMath.spaceship(at: schedule, size: size, seed: seed) {
            SpaceshipPainter.draw(ship, time: time, in: &canvas)
        }
    }

    private func drawLayer(
        _ layer: StarfieldMath.Layer, seed: UInt64, in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval
    ) {
        let stars = StarfieldMath.stars(in: layer, seed: seed)
        let offset = StarfieldMath.drift(of: layer, at: time)
        let columns = Int(ceil(size.width / layer.tile.width))
        let rows = Int(ceil(size.height / layer.tile.height)) + 1
        for row in -1..<rows {
            for column in 0..<columns {
                let origin = CGPoint(x: CGFloat(column) * layer.tile.width, y: CGFloat(row) * layer.tile.height + offset)
                for star in stars {
                    let point = CGPoint(x: origin.x + star.x * layer.tile.width, y: origin.y + star.y * layer.tile.height)
                    guard point.y > -4, point.y < size.height + 4 else { continue }
                    let size = star.size * look.size
                    let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
                    canvas.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.opacity * look.opacity)))
                }
            }
        }
    }

    private func drawNebula(
        _ nebula: StarfieldMath.Nebula, in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval
    ) {
        let phase = StarfieldMath.nebulaPhase(at: time, period: nebula.period)
        let center = CGPoint(x: size.width * nebula.x + (phase - 0.5) * 40, y: size.height * nebula.y + (0.5 - phase) * 40)
        let radius = nebula.diameter / 2 * (1 + 0.16 * phase)
        let violet = nebula.hue.color
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: violet.opacity(nebula.opacity), location: 0),
                    .init(color: violet.opacity(nebula.opacity * 0.45), location: 0.4),
                    .init(color: violet.opacity(nebula.opacity * 0.1), location: 0.75),
                    .init(color: violet.opacity(0), location: 1),
                ]),
                center: center, startRadius: 0, endRadius: radius
            )
        )
    }

    private func drawTwinkle(
        _ twinkle: StarfieldMath.Twinkle, in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval
    ) {
        let phase = time / twinkle.cycle + twinkle.phase
        let level = StarfieldMath.twinkleLevel(at: phase)
        let center = CGPoint(x: size.width * twinkle.x, y: size.height * twinkle.y)
        let color: Color = switch twinkle.tint {
        case .white: .white
        case .warm: Color(hex: 0xFFF3C4)
        case .lilac: Color(hex: 0xE4DEFF)
        }
        let diameter = twinkle.size * level.scale
        let opacity = level.opacity * look.opacity
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)),
            with: .color(color.opacity(opacity))
        )
        guard twinkle.hasGlint else { return }
        // The cross: two hairlines that fade toward their ends.
        let half = StarfieldMath.glintHalfLength * level.scale
        for angle in [0.0, 90.0] {
            let radians = angle * .pi / 180
            let end = CGVector(dx: cos(radians) * half, dy: sin(radians) * half)
            var line = Path()
            line.move(to: CGPoint(x: center.x - end.dx, y: center.y - end.dy))
            line.addLine(to: CGPoint(x: center.x + end.dx, y: center.y + end.dy))
            canvas.stroke(
                line,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0), color.opacity(opacity * 0.9), color.opacity(0)]),
                    startPoint: CGPoint(x: center.x - end.dx, y: center.y - end.dy),
                    endPoint: CGPoint(x: center.x + end.dx, y: center.y + end.dy)
                ),
                lineWidth: 0.8
            )
        }
    }

    /// The comet's clock is the app's, not the screen's: it carries on while the creator moves between tabs.
    private static let launchedAt = ProcessInfo.processInfo.systemUptime

    static func sinceLaunch() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime - launchedAt
    }

    /// A glowing head with a tail of 140 to 210 pt fading behind it.
    private func drawComet(_ comet: StarfieldMath.Comet, in canvas: inout GraphicsContext) {
        let head = CGPoint(
            x: comet.start.x + comet.direction.dx * comet.distance * comet.progress,
            y: comet.start.y + comet.direction.dy * comet.distance * comet.progress
        )
        let tail = CGPoint(x: head.x - comet.direction.dx * comet.tail, y: head.y - comet.direction.dy * comet.tail)
        var line = Path()
        line.move(to: tail)
        line.addLine(to: head)
        canvas.stroke(
            line,
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0), .white.opacity(comet.opacity)]), startPoint: tail, endPoint: head
            ),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )
        canvas.fill(
            Path(ellipseIn: CGRect(x: head.x - 1.6, y: head.y - 1.6, width: 3.2, height: 3.2)),
            with: .color(.white.opacity(comet.opacity))
        )
    }
}

/// The sky behind a browse screen, from the creator's Starry sky setting.
struct SkyBackground: ViewModifier {
    @Environment(PersonalizationService.self) private var personalization
    /// The night glow and the colour under it: nil is the browse screens' (`BgWash.navigation` over `bg`, or the galactic night at Galactic),
    /// otherwise the one a board of the stories draws.
    var lights: [BgWash.Light]?
    var base: Color?

    func body(content: Content) -> some View {
        let sky = personalization.sky
        content.background {
            ZStack {
                // The night glow (v29): a violet light from the top left, the same on every browse screen, sky on or off.
                BgWash(lights: lights ?? BgWash.browse(sky), base: base ?? BgWash.browseBase(sky))
                StarfieldView(density: sky)
            }
            .ignoresSafeArea()
        }
    }
}

extension View {
    /// The night and its stars behind this screen. Only on browse screens: never over the camera, a
    /// take or the editor.
    func skyBackground() -> some View {
        modifier(SkyBackground())
    }

    /// The night and its stars with the glow of one board (`BgWash.sendOff`…), over `base`.
    func skyBackground(wash lights: [BgWash.Light], base: Color = Palette.bg) -> some View {
        modifier(SkyBackground(lights: lights, base: base))
    }
}

#if DEBUG
#Preview {
    StarfieldView(density: .lively)
        .background(Palette.bg)
}
#endif
