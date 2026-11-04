//
//  VoiceFuelPainter.swift
//  Cue Studio
//

import SwiftUI

/// Draws My Cue Voice's fuel tank (`VoiceFuelTank`) at a moment of its launch: a glass tube where the sky's spaceship pours yellow plasma up to
/// what Cue knows, then the ship's flight out toward the viewer (`VoiceShipFlight`) on a taller canvas over the page. Everything is a function
/// of the seconds since the launch, so the same moment always draws the same frame.
///
/// The tube: deep night under glass (a light along its top, a shadow inside it, quarter marks etched at its edges); the plasma in two layers that
/// move apart (a darker amber behind, the yellow in front), so it reads as liquid with depth; its front lit where it meets the empty tube; a
/// pulse of light passing slowly through it. While the ship pours, the plasma's front leans back with its speed; when the ship
/// stops, it surges forward once, comes back and settles (a spring).
enum VoiceFuelPainter {
    /// The run along the tank.
    static let runSeconds: TimeInterval = 1.25
    static let tankHeight: CGFloat = 18
    /// The flight's canvas: from the tank's bottom up over the page, and past each side of the tank.
    static let flightHeight: CGFloat = 400
    static let flightInset: CGFloat = 40
    /// How far above the tank the ship turns to face the viewer.
    private static let turnHeight: CGFloat = 66
    /// The ship is wider than the tube it fills (the owner, 03/11/2026: it read too narrow inside it), so it is drawn on its own lane over the
    /// tank (`drawRunShip`), taller than the tube.
    private static let shipLength: CGFloat = 27
    static let shipLane: CGFloat = 44
    /// The front view's span when it has just turned: a little more than the top view's, as it is already coming closer.
    private static let frontSize: CGFloat = 32

    /// True while the ship is on screen (the run or the flight).
    static func isFlying(_ elapsed: TimeInterval?) -> Bool {
        guard let elapsed else { return false }
        return elapsed < runSeconds + VoiceShipFlight.duration
    }

    // MARK: - The tank

    /// The tank, `size` the tank's own. `level` is 0…1; `elapsed` the seconds since the launch (nil: no motion, full to its level, no ship).
    static func drawTank(level: Double, elapsed: TimeInterval?, time: TimeInterval, size: CGSize, in canvas: inout GraphicsContext) {
        let tank = CGRect(origin: .zero, size: CGSize(width: size.width, height: tankHeight))
        let target = tank.width * CGFloat(max(0, min(1, level)))
        let surface = Surface(target: target, elapsed: elapsed)
        let tube = Path(roundedRect: tank, cornerRadius: tankHeight / 2)

        canvas.fill(tube, with: .color(Palette.Fuel.tank))
        var inside = canvas
        inside.clip(to: tube)
        if surface.fill > 0.5 {
            drawPlasma(surface, time: time, in: tank, on: &inside)
        }
        drawGlass(in: tank, on: &inside)
        canvas.stroke(tube, with: .color(Palette.Fuel.rim), lineWidth: 1)
    }

    /// The ship during the run, riding just ahead of the plasma it pours, on a lane `shipLane` tall centred on the tube (`size` the lane's).
    static func drawRunShip(level: Double, elapsed: TimeInterval, time: TimeInterval, size: CGSize, in canvas: inout GraphicsContext) {
        let tank = CGRect(x: 0, y: (size.height - tankHeight) / 2, width: size.width, height: tankHeight)
        let surface = Surface(target: tank.width * CGFloat(max(0, min(1, level))), elapsed: elapsed)
        SpaceshipPainter.drawCraft(at: runPosition(fill: surface.fill, in: tank), heading: 0, length: shipLength, time: time, thrust: 1.3, in: &canvas)
    }

    /// The plasma's front at a moment: how far it reaches, how much it leans with the pour's speed, and the spring after the ship stops.
    private struct Surface {
        var fill: CGFloat
        var lean: CGFloat
        var surge: CGFloat
        var wave: Double

        init(target: CGFloat, elapsed: TimeInterval?) {
            guard let elapsed else {
                fill = target
                lean = 0
                surge = 0
                wave = 0.8
                return
            }
            let run = min(1, elapsed / runSeconds)
            fill = target * CGFloat(1 - pow(1 - run, 3))
            // The pour's speed (the ease's slope), in points per second: the front leans back with it.
            let speed = target * CGFloat(3 * pow(1 - run, 2) / runSeconds)
            lean = elapsed < runSeconds ? min(7, speed * 0.018) : 0
            let after = max(0, elapsed - runSeconds)
            surge = elapsed < runSeconds ? 0 : CGFloat(6 * exp(-3.4 * after) * sin(2 * .pi * 1.7 * after))
            wave = 1 + 1.6 * exp(-2 * after)
        }

        /// The front's x at `fraction` of the tube's height (0 its top): the surge moves the top more than the bottom, as liquid does.
        func front(at fraction: Double, time: TimeInterval, phase: Double) -> CGFloat {
            let ripple = wave * sin(fraction * .pi * 2 + time * 4.6 + phase) + wave * 0.45 * sin(fraction * .pi * 4.2 - time * 7.4 + phase)
            return fill + CGFloat(ripple) - lean * CGFloat(1 - fraction) + surge * CGFloat(1 - fraction * 0.6)
        }
    }

    private static func drawPlasma(_ surface: Surface, time: TimeInterval, in tank: CGRect, on canvas: inout GraphicsContext) {
        let back = plasmaPath(surface, time: time, phase: 1.9, ahead: 2.2, in: tank)
        canvas.fill(back, with: .color(Palette.Fuel.fuelBack))
        let front = plasmaPath(surface, time: time, phase: 0, ahead: 0, in: tank)
        canvas.fill(front, with: .linearGradient(
            Gradient(colors: [Palette.Fuel.fuel, Palette.Fuel.fuelDeep]),
            startPoint: CGPoint(x: 0, y: tank.minY + 2), endPoint: CGPoint(x: 0, y: tank.maxY)
        ))

        // The current: a pulse of light crossing the plasma every few seconds, as energy flowing through it.
        var current = canvas
        current.clip(to: front)
        let period = 2.8
        let cycle = (time / period).truncatingRemainder(dividingBy: 1)
        let centre = -24 + (surface.fill + 48) * CGFloat(cycle)
        current.fill(Path(tank), with: .linearGradient(
            Gradient(stops: [
                .init(color: Palette.Fuel.current.opacity(0), location: 0),
                .init(color: Palette.Fuel.current.opacity(0.6), location: 0.5),
                .init(color: Palette.Fuel.current.opacity(0), location: 1),
            ]),
            startPoint: CGPoint(x: centre - 22, y: tank.minY), endPoint: CGPoint(x: centre + 22, y: tank.maxY)
        ))

        // The front, lit where the plasma meets the empty tube.
        var edge = Path()
        for step in 0...12 {
            let fraction = Double(step) / 12
            let point = CGPoint(x: surface.front(at: fraction, time: time, phase: 0), y: tank.minY + tank.height * fraction)
            if step == 0 { edge.move(to: point) } else { edge.addLine(to: point) }
        }
        canvas.stroke(edge, with: .color(Palette.Fuel.meniscus.opacity(0.3)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        canvas.stroke(edge, with: .color(Palette.Fuel.meniscus), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
    }

    private static func plasmaPath(_ surface: Surface, time: TimeInterval, phase: Double, ahead: CGFloat, in tank: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: tank.minX, y: tank.minY))
        for step in 0...12 {
            let fraction = Double(step) / 12
            let x = surface.front(at: fraction, time: time, phase: phase) + ahead
            path.addLine(to: CGPoint(x: max(tank.minX, x), y: tank.minY + tank.height * fraction))
        }
        path.addLine(to: CGPoint(x: tank.minX, y: tank.maxY))
        path.closeSubpath()
        return path
    }

    /// The glass over everything inside: a shadow under its top edge, a light along it and a fainter one at the bottom, and the quarter marks
    /// etched at the top and bottom edges.
    private static func drawGlass(in tank: CGRect, on canvas: inout GraphicsContext) {
        canvas.fill(Path(tank), with: .linearGradient(
            Gradient(colors: [Palette.Fuel.innerShadow, Palette.Fuel.innerShadow.opacity(0)]),
            startPoint: CGPoint(x: 0, y: tank.minY), endPoint: CGPoint(x: 0, y: tank.minY + 6)
        ))
        let radius = tankHeight / 2
        for (y, colour) in [(tank.minY + 2.6, Palette.Fuel.glassLight), (tank.maxY - 2.4, Palette.Fuel.glassLight.opacity(0.3))] {
            var line = Path()
            line.move(to: CGPoint(x: tank.minX + radius, y: y))
            line.addLine(to: CGPoint(x: tank.maxX - radius, y: y))
            canvas.stroke(line, with: .color(colour), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        }
        for quarter in 1...3 {
            let x = tank.minX + tank.width * CGFloat(quarter) / 4
            for (from, to) in [(tank.minY, tank.minY + 4), (tank.maxY - 4, tank.maxY)] {
                var mark = Path()
                mark.move(to: CGPoint(x: x, y: from))
                mark.addLine(to: CGPoint(x: x, y: to))
                canvas.stroke(mark, with: .color(Palette.Fuel.rim), lineWidth: 1)
            }
        }
    }

    /// During the run the ship rides just ahead of the plasma it pours, always whole inside the tube.
    private static func runPosition(fill: CGFloat, in tank: CGRect) -> CGPoint {
        let half = shipLength * 0.5
        return CGPoint(x: min(tank.maxX - half, max(tank.minX + half, fill + shipLength * 0.35)), y: tank.midY)
    }

    // MARK: - The flight

    /// The flight out, on a canvas `flightHeight` tall whose bottom is the tank's bottom and `flightInset` wider on each side.
    static func drawFlight(level: Double, elapsed: TimeInterval, time: TimeInterval, size: CGSize, in canvas: inout GraphicsContext) {
        let tank = CGRect(x: flightInset, y: size.height - tankHeight, width: size.width - flightInset * 2, height: tankHeight)
        let start = runPosition(fill: tank.minX + tank.width * CGFloat(max(0, min(1, level))), in: tank)
        let anchor = CGPoint(x: tank.midX, y: tank.minY - turnHeight)
        let moment = elapsed - runSeconds
        guard let pose = VoiceShipFlight.pose(at: moment, origin: start, anchor: anchor) else { return }
        switch pose.view {
        case .top:
            drawTrail(moment: moment, origin: start, anchor: anchor, on: &canvas)
            drawTop(pose, time: time, on: &canvas)
        case .front:
            drawLight(pose, on: &canvas)
            drawForce(moment: moment, origin: start, anchor: anchor, opacity: pose.opacity, on: &canvas)
            // Motion blur as it rushes at the glass: the last instants, fainter behind it.
            for lag in [0.05, 0.025] where pose.scale > 3 {
                if let earlier = VoiceShipFlight.pose(at: moment - lag, origin: start, anchor: anchor), earlier.view == .front {
                    drawFront(earlier, time: time, opacity: 0.22 * pose.opacity, on: &canvas)
                }
            }
            drawFront(pose, time: time, opacity: pose.opacity, on: &canvas)
            drawFlash(pose, on: &canvas)
        }
    }

    private static func drawTop(_ pose: VoiceShipFlight.Pose, time: TimeInterval, on canvas: inout GraphicsContext) {
        var craft = canvas
        craft.opacity = pose.opacity
        craft.translateBy(x: pose.position.x, y: pose.position.y)
        craft.rotate(by: .radians(pose.heading))
        craft.scaleBy(x: CGFloat(max(0.02, pose.along)), y: CGFloat(pose.across))
        SpaceshipPainter.drawCraft(at: .zero, heading: 0, length: shipLength, time: time, bank: pose.bank, thrust: pose.thrust, in: &craft)
    }

    private static func drawFront(_ pose: VoiceShipFlight.Pose, time: TimeInterval, opacity: Double, on canvas: inout GraphicsContext) {
        var craft = canvas
        craft.opacity = opacity
        craft.translateBy(x: pose.position.x, y: pose.position.y)
        craft.rotate(by: .radians(pose.roll))
        SpaceshipPainter.drawCraftFront(
            at: .zero, size: frontSize * CGFloat(pose.scale), opening: pose.opening, thrust: pose.thrust, time: time, in: &craft
        )
    }

    /// The force behind the ship as it comes at the viewer: a shock wave where it boosts (a ring that spreads wide and fades, with a flash at
    /// its heart), then a ring pushed out every 0.08 s from where the ship was, each spreading and fading behind it as it comes closer.
    private static func drawForce(moment: TimeInterval, origin: CGPoint, anchor: CGPoint, opacity: Double, on canvas: inout GraphicsContext) {
        let boost = VoiceShipFlight.anticipation + VoiceShipFlight.launch
        let since = moment - boost
        guard since >= 0 else { return }
        if since < 0.42 {
            let spread = since / 0.42
            let radius = 12 + 105 * CGFloat(VoiceShipFlight.easeOut(spread))
            let fade = pow(1 - spread, 1.8)
            ring(at: anchor, radius: radius, squash: 0.78, width: 2.2 * (1 - spread) + 0.5, opacity: fade, on: &canvas)
            if since < 0.14 {
                let flash = 1 - since / 0.14
                let glare = 44.0
                canvas.fill(
                    Path(ellipseIn: CGRect(x: anchor.x - glare, y: anchor.y - glare, width: glare * 2, height: glare * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.7 * flash), Palette.Sky.shipEngine.opacity(0.3 * flash), .clear]),
                        center: anchor, startRadius: 0, endRadius: glare
                    )
                )
            }
        }
        var emitted = boost + 0.06
        while emitted < moment {
            let age = moment - emitted
            if age < 0.4, let then = VoiceShipFlight.pose(at: emitted, origin: origin, anchor: anchor), then.view == .front {
                let size = frontSize * CGFloat(then.scale)
                let fade = pow(1 - age / 0.4, 1.6) * opacity
                ring(at: then.position, radius: size * CGFloat(0.34 + 1.7 * age), squash: 0.74, width: max(0.6, size * 0.05 * CGFloat(1 - age / 0.4)),
                     opacity: 0.8 * fade, on: &canvas)
            }
            emitted += 0.08
        }
    }

    /// One ring of force: a bright thin line over a wide faint one, flattened as a ring seen a little from above.
    private static func ring(
        at centre: CGPoint, radius: CGFloat, squash: CGFloat, width: CGFloat, opacity: Double, on canvas: inout GraphicsContext
    ) {
        let oval = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius * squash, width: radius * 2, height: radius * 2 * squash))
        canvas.stroke(oval, with: .color(Palette.Sky.shipEngine.opacity(0.22 * opacity)), lineWidth: width * 4)
        canvas.stroke(oval, with: .color(Palette.Fuel.forceRing.opacity(opacity)), lineWidth: width)
    }

    /// The ion trail behind the ship on its way out: where it really flew in the last fifth of a second, tapering from ion blue to violet.
    private static func drawTrail(moment: TimeInterval, origin: CGPoint, anchor: CGPoint, on canvas: inout GraphicsContext) {
        guard moment > VoiceShipFlight.anticipation else { return }
        let steps = 14
        var previous: CGPoint?
        for step in 0...steps {
            let fraction = Double(step) / Double(steps)
            let at = max(VoiceShipFlight.anticipation, moment - 0.2 * fraction)
            guard let pose = VoiceShipFlight.pose(at: at, origin: origin, anchor: anchor), pose.view == .top else { continue }
            let tail = CGPoint(
                x: pose.position.x - cos(pose.heading) * shipLength * 0.5 * pose.along,
                y: pose.position.y - sin(pose.heading) * shipLength * 0.5 * pose.along
            )
            if let previous {
                var segment = Path()
                segment.move(to: previous)
                segment.addLine(to: tail)
                let colour = Palette.Sky.shipEngine.mix(with: Palette.Sky.shipTrailFar, by: fraction)
                let fade = pow(1 - fraction, 1.4)
                canvas.stroke(segment, with: .color(colour.opacity(0.18 * fade)), style: StrokeStyle(lineWidth: 5 * (1 - fraction * 0.7), lineCap: .round))
                canvas.stroke(segment, with: .color(colour.opacity(0.9 * fade)), style: StrokeStyle(lineWidth: 1.4 * (1 - fraction * 0.8), lineCap: .round))
            }
            previous = tail
        }
    }

    /// The engines' light on the page as the ship comes closer.
    private static func drawLight(_ pose: VoiceShipFlight.Pose, on canvas: inout GraphicsContext) {
        guard pose.glow > 0 else { return }
        let radius = frontSize * CGFloat(pose.scale) * 1.6 + 40
        let centre = pose.position
        canvas.fill(
            Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [Palette.Sky.shipEngine.opacity(0.16 * pose.glow * pose.opacity), Palette.Sky.shipEngine.opacity(0)]),
                center: centre, startRadius: 0, endRadius: radius
            )
        )
    }

    /// The flash as it passes the glass.
    private static func drawFlash(_ pose: VoiceShipFlight.Pose, on canvas: inout GraphicsContext) {
        guard pose.flash > 0 else { return }
        let radius = frontSize * CGFloat(pose.scale) * 0.9
        let centre = pose.position
        canvas.fill(
            Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.6 * pose.flash), Palette.Sky.shipEngine.opacity(0.25 * pose.flash), .clear]),
                center: centre, startRadius: 0, endRadius: radius
            )
        )
    }
}
