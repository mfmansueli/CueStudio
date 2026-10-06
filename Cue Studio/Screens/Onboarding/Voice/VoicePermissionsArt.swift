//
//  VoicePermissionsArt.swift
//  Cue Studio
//

import SwiftUI

/// The art at the top of 1.5: two orbs, "VOICE" and "CAMERA", joined by a beam of light with small lights flowing along it. The voice orb's
/// bars always move and rings open from it; the camera's lens is a closed iris of six blades until the camera is allowed, when they
/// open and a yellow core lights behind them (a green ring opens from the orb, a light crosses the glass). It draws in a 390 × 200 box (the
/// board's art starts at y 112). The unlock is a function of the seconds since the camera was allowed, read from the board's layers
/// (`MotionClip`: the board allows the camera at 4.4 s).
struct VoicePermissionsArt: View {
    /// Seconds since the camera was allowed; nil while it is not. A large number is the open iris at rest.
    let unlockAge: Double?
    /// Seconds since the chapter appeared, for what runs on its own.
    let time: Double

    private static let clip = MotionLibrary.clip("1.5_permissions")
    /// The board's second at which the unlock begins (the core's fade-in starts at 3.85 s; the iris begins to open at 3.7 s).
    private static let unlockStart = 3.7
    private static let voice = CGPoint(x: 122, y: 98)
    private static let camera = CGPoint(x: 268, y: 98)

    var body: some View {
        Canvas { context, _ in
            drawGlows(in: &context)
            drawVoice(in: &context)
            drawBeam(in: &context)
            drawCamera(in: &context)
            drawLabels(in: &context)
        }
        .frame(height: 200)
        .accessibilityHidden(true)
    }

    private var unlockSecond: Double { Self.unlockStart + min(unlockAge ?? 0, 5) }

    private func pose(_ layer: String, at second: Double? = nil, loops: Bool = false) -> MotionPose {
        Self.clip.pose(of: layer, at: second ?? (unlockAge == nil ? 0 : unlockSecond), loops: loops)
    }

    // MARK: - The sky behind it

    private func drawGlows(in context: inout GraphicsContext) {
        let lights: [(centre: CGPoint, color: Color)] = [
            (CGPoint(x: 10 + 0.30 * 370, y: 6 + 0.52 * 170), Palette.acc.opacity(0.14)),
            (CGPoint(x: 10 + 0.72 * 370, y: 6 + 0.52 * 170), Palette.nightViolet.opacity(0.22)),
        ]
        for light in lights {
            var layer = context
            layer.translateBy(x: light.centre.x, y: light.centre.y)
            layer.scaleBy(x: 185, y: 98.6)
            layer.fill(
                Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
                with: .radialGradient(Gradient(colors: [light.color, light.color.opacity(0)]), center: .zero, startRadius: 0, endRadius: 0.7)
            )
        }
        context.stroke(LightFX.disc(Self.voice, 64), with: .color(Palette.acc.opacity(0.12)), lineWidth: 1)
        context.stroke(LightFX.disc(Self.camera, 64), with: .color(Palette.flightLilac.opacity(0.14)), lineWidth: 1)
    }

    // MARK: - The voice orb

    private func drawVoice(in context: inout GraphicsContext) {
        // Two rings open from it, 1.2 s apart.
        for (index, delay) in [0.0, 1.2].enumerated() {
            let ring = Self.clip.pose(of: "L\(1 + index)", at: time + (index == 0 ? 0 : 2.4 - delay), loops: true)
            LightFX.ring(ring, at: Self.voice, radius: 52, color: Palette.acc.opacity(0.6), in: &context)
        }
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Palette.acc.opacity(0.34), radius: 23))
            layer.addFilter(.shadow(color: .black.opacity(0.45), radius: 13, y: 12))
            layer.fill(
                LightFX.disc(Self.voice, 42),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Palette.micGlassLight, location: 0), .init(color: Palette.micGlassMid, location: 0.48),
                        .init(color: Palette.micGlassDark, location: 1),
                    ]),
                    center: CGPoint(x: Self.voice.x - 42 + 0.34 * 84, y: Self.voice.y - 42 + 0.26 * 84), startRadius: 0, endRadius: 83
                )
            )
        }
        context.stroke(LightFX.disc(Self.voice, 41.5), with: .color(Palette.acc.opacity(0.7)), lineWidth: 1)
        context.stroke(LightFX.disc(Self.voice, 40), with: .color(Palette.acc.opacity(0.1)), lineWidth: 3)
        let heights: [CGFloat] = [26, 40, 32, 44, 24]
        for (index, height) in heights.enumerated() {
            let bar = Self.clip.pose(of: "L3", at: time + 0.9 - Double(index) * 0.15, loops: true)
            let x = Self.voice.x - 20 + CGFloat(index) * 9 + 2
            var layer = context
            layer.translateBy(x: x, y: Self.voice.y)
            layer.scaleBy(x: 1, y: bar.sy)
            layer.addFilter(.shadow(color: Palette.acc.opacity(0.55), radius: 4))
            layer.fill(
                Path(roundedRect: CGRect(x: -2, y: -height / 2, width: 4, height: height), cornerRadius: 2),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Palette.starCream, location: 0), .init(color: Palette.acc, location: 0.55),
                        .init(color: Palette.flightGoldShade, location: 1),
                    ]),
                    startPoint: CGPoint(x: 0, y: -height / 2), endPoint: CGPoint(x: 0, y: height / 2)
                )
            )
        }
    }

    // MARK: - The beam

    private func drawBeam(in context: inout GraphicsContext) {
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Palette.nightViolet.opacity(0.35), radius: 7))
            layer.fill(
                Path(roundedRect: CGRect(x: 166, y: 97, width: 58, height: 2), cornerRadius: 1),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Palette.acc.opacity(0.85), location: 0), .init(color: Palette.starCream.opacity(0.55), location: 0.45),
                        .init(color: Palette.flightLilac.opacity(0.85), location: 1),
                    ]),
                    startPoint: CGPoint(x: 166, y: 0), endPoint: CGPoint(x: 224, y: 0)
                )
            )
        }
        for delay in [0.0, 0.4, 0.8] {
            let flow = Self.clip.pose(of: "L8", at: time + 1.2 - delay, loops: true)
            guard flow.opacity > 0.01 else { continue }
            let point = CGPoint(x: 168.5 + flow.tx, y: 98)
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: Palette.acc.opacity(0.9), radius: 4))
                layer.fill(
                    LightFX.disc(point, 2.5),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: .white, location: 0), .init(color: Palette.starGold, location: 0.55), .init(color: Palette.acc, location: 1),
                        ]),
                        center: point, startRadius: 0, endRadius: 2.5
                    )
                )
                layer.opacity = flow.opacity
            }
        }
    }

    // MARK: - The camera orb

    private func drawCamera(in context: inout GraphicsContext) {
        let ring = pose("L11")
        LightFX.ring(ring, at: Self.camera, radius: 42, color: Palette.success, in: &context)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Palette.nightViolet.opacity(0.4), radius: 23))
            layer.addFilter(.shadow(color: .black.opacity(0.45), radius: 13, y: 12))
            layer.fill(
                LightFX.disc(Self.camera, 42),
                with: .radialGradient(
                    Gradient(colors: [Palette.lensRingLight, Palette.lensRingDark]),
                    center: CGPoint(x: Self.camera.x - 42 + 0.35 * 84, y: Self.camera.y - 42 + 0.3 * 84), startRadius: 0, endRadius: 83
                )
            )
        }
        context.stroke(LightFX.disc(Self.camera, 41.5), with: .color(Palette.flightLilac.opacity(0.7)), lineWidth: 1)
        drawTicks(in: &context)
        context.stroke(LightFX.disc(Self.camera, 33), with: .conicGradient(
            Gradient(stops: [
                .init(color: Palette.starLilac.opacity(0.55), location: 0), .init(color: .white.opacity(0.04), location: 0.25),
                .init(color: Palette.flightLilac.opacity(0.4), location: 0.55), .init(color: .white.opacity(0.05), location: 0.8),
                .init(color: Palette.starLilac.opacity(0.55), location: 1),
            ]),
            center: Self.camera, angle: .degrees(210)
        ), lineWidth: 1.5)
        drawLens(in: &context)
    }

    /// 24 fine ticks round the lens (1.2° wide every 15°).
    private func drawTicks(in context: inout GraphicsContext) {
        for tick in 0..<24 {
            let angle = Double(tick) * 15 * .pi / 180
            var path = Path()
            path.move(to: CGPoint(x: Self.camera.x + 37.5 * cos(angle), y: Self.camera.y + 37.5 * sin(angle)))
            path.addLine(to: CGPoint(x: Self.camera.x + 38 * cos(angle), y: Self.camera.y + 38 * sin(angle)))
            context.stroke(path, with: .color(Palette.starLilac.opacity(0.45)), lineWidth: 1.4)
        }
    }

    /// The lens: 50 pt of dark glass with the iris (six blades that slide out and turn once the camera is allowed), the core that lights behind it,
    /// a light that crosses the glass, and the glints.
    private func drawLens(in context: inout GraphicsContext) {
        var lens = context
        lens.clip(to: LightFX.disc(Self.camera, 25))
        lens.fill(LightFX.disc(Self.camera, 25), with: .color(Palette.lensCore))
        drawCore(in: &lens)
        var iris = lens
        iris.translateBy(x: Self.camera.x, y: Self.camera.y)
        iris.rotate(by: .degrees(time / 16 * 360))
        let blades: [(from: CGPoint, to: CGPoint)] = [
            (CGPoint(x: -1.33, y: -37.98), CGPoint(x: 33.55, y: -17.84)), (CGPoint(x: 32.23, y: -20.14), CGPoint(x: 32.23, y: 20.14)),
            (CGPoint(x: 33.55, y: 17.84), CGPoint(x: -1.33, y: 37.98)), (CGPoint(x: 1.33, y: 37.98), CGPoint(x: -33.55, y: 17.84)),
            (CGPoint(x: -32.23, y: 20.14), CGPoint(x: -32.23, y: -20.14)), (CGPoint(x: -33.55, y: -17.84), CGPoint(x: 1.33, y: -37.98)),
        ]
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(stops: [
                .init(color: Palette.lensGlassLight, location: 0), .init(color: Palette.lensRingLight, location: 0.45),
                .init(color: Palette.lensRingDark, location: 1),
            ]),
            center: .zero, startRadius: 0, endRadius: 38
        )
        for (index, blade) in blades.enumerated() {
            let move = pose("L\(15 + index)")
            var shape = Path()
            shape.move(to: .zero)
            shape.addLine(to: blade.from)
            shape.addArc(
                center: .zero, radius: 38, startAngle: Angle(radians: atan2(blade.from.y, blade.from.x)),
                endAngle: Angle(radians: atan2(blade.to.y, blade.to.x)), clockwise: false
            )
            shape.closeSubpath()
            var piece = iris
            piece.translateBy(x: move.tx, y: move.ty)
            piece.rotate(by: .degrees(move.rot))
            piece.fill(shape, with: shading)
            piece.stroke(shape, with: .color(Palette.flightLilac.opacity(0.5)), lineWidth: 0.6)
        }
        lens.fill(LightFX.disc(CGPoint(x: Self.camera.x - 6, y: Self.camera.y - 8), 2.2), with: .color(.white.opacity(0.8)))
        drawSweep(in: &lens)
        lens.fill(
            Path(ellipseIn: CGRect(x: Self.camera.x - 25 + 8, y: Self.camera.y - 25 + 6, width: 24, height: 11)),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.42), .white.opacity(0)]),
                startPoint: CGPoint(x: 0, y: Self.camera.y - 19), endPoint: CGPoint(x: 0, y: Self.camera.y - 8)
            )
        )
        lens.fill(
            LightFX.disc(CGPoint(x: Self.camera.x + 25 - 9 - 3, y: Self.camera.y + 25 - 8 - 3), 3),
            with: .color(Palette.flightIce.opacity(0.45))
        )
        context.stroke(LightFX.disc(Self.camera, 24.5), with: .color(Palette.lensEdge), lineWidth: 3)
        context.stroke(LightFX.disc(Self.camera, 23), with: .color(Palette.flightLilac.opacity(0.55)), lineWidth: 1)
    }

    /// The yellow core behind the open iris: a 28 pt sphere in a soft light, breathing (×1.09, 1.2 s).
    private func drawCore(in lens: inout GraphicsContext) {
        let reveal = pose("L12")
        guard reveal.opacity > 0.01 else { return }
        let breath = 1 + 0.045 * (1 - cos(time / 1.2 * 2 * .pi))
        var layer = lens
        layer.opacity = reveal.opacity
        layer.translateBy(x: Self.camera.x, y: Self.camera.y)
        layer.scaleBy(x: reveal.sx, y: reveal.sx)
        layer.fill(
            LightFX.disc(.zero, 39),
            with: .radialGradient(Gradient(colors: [Palette.acc.opacity(0.55), Palette.acc.opacity(0)]), center: .zero, startRadius: 0, endRadius: 24)
        )
        var ball = layer
        ball.scaleBy(x: breath, y: breath)
        ball.addFilter(.shadow(color: Palette.acc.opacity(0.55), radius: 9))
        ball.fill(
            LightFX.disc(.zero, 14),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Palette.flightGoldCream, location: 0), .init(color: Palette.starGold, location: 0.3),
                    .init(color: Palette.acc, location: 0.62),
                    .init(color: Palette.flightGoldDeep, location: 1),
                ]),
                center: CGPoint(x: -14 + 0.38 * 28, y: -14 + 0.34 * 28), startRadius: 0, endRadius: 26
            )
        )
    }

    /// A band of light across the glass as the iris opens (4.5–5.1 s).
    private func drawSweep(in lens: inout GraphicsContext) {
        let sweep = pose("L21")
        guard unlockAge != nil, sweep.tx > -69, sweep.tx < 69 else { return }
        var layer = lens
        layer.translateBy(x: Self.camera.x + sweep.tx, y: Self.camera.y)
        layer.rotate(by: .degrees(25))
        layer.fill(
            Path(CGRect(x: -9, y: -45, width: 18, height: 90)),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0), .white.opacity(0.55), .white.opacity(0)]), startPoint: CGPoint(x: -9, y: 0), endPoint: CGPoint(x: 9, y: 0)
            )
        )
    }

    // MARK: - Labels

    private func drawLabels(in context: inout GraphicsContext) {
        for (text, centre) in [("VOICE", Self.voice.x), ("CAMERA", Self.camera.x)] {
            context.draw(
                Text(verbatim: text).font(.system(size: 9.5, weight: .semibold, design: .monospaced)).tracking(1.33)
                    .foregroundStyle(Palette.flightInk.opacity(0.55)),
                at: CGPoint(x: centre, y: 156)
            )
        }
    }
}
