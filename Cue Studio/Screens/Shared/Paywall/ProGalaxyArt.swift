//
//  ProGalaxyArt.swift
//  Cue Studio
//

import SwiftUI

/// The Pro paywall's art (owner, 30/10/2026: Ultra AI's universe in the Pro): a galaxy seen at a slant round a golden planet, the same for
/// everyone (owner, 30/10/2026: not the colour picked in the Profile), two spiral arms of stars and soft light warming from Cue's gold at the
/// core to Ultra AI's violet at the tips (`Palette.Scripts.proGalaxy`), turning once a minute. Round it, the year's ring: twelve nodes, all
/// lit for Yearly and only this month's for Monthly, the light going round from the front when the plan changes (`ring`), each node that
/// lights sparkling as it does, and the lit ones catching the light now and then. The calm Pro from an export shows the waiting video as a
/// star pulsing at the front; the calm Pro of Ultra AI is violet, its ring the month's thirty scripts. A shooting star now and then.
///
/// On the opening (`time`, `ProOpeningScript`) the star that flew up becomes the planet: the arms unfurl face on, turning, their stars lighting
/// from the core out, the galaxy lies back to its slant on a spring and the ring wipes in round it, its nodes popping one after the other.
/// `finishedAt` is the creator subscribing: the nodes run into the core, it flashes and a gold wave crosses the plane. Still under Reduce
/// Motion. Decorative: hidden from VoiceOver.
struct ProGalaxyArt: View {
    enum Style { case pro, export, ultra }

    /// Which of the ring's nodes are lit, and since when: the light goes round from the front, a node every 35 ms (14 ms on the thirty).
    struct RingLight: Equatable {
        var lit: Int
        var was: Int
        var since: Date
    }

    let style: Style
    /// The galaxy's reach, in points; its ring goes `ringShare` further.
    let radius: CGFloat
    var ring: RingLight
    /// The second of the opening; its end shows everything in place.
    var time: Double = ProOpeningScript.settled
    var finishedAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = Date.now

    static let ringShare: CGFloat = 1.11
    /// How long the purchase's finish lasts before the Pro goes away.
    static let finishLength = 0.9
    /// The galaxy's height is this share of its width once it has lain down, and it leans back this much.
    private static let slant: CGFloat = 0.42
    private static let lean = -10 * Double.pi / 180
    /// A turn a minute.
    private static let spin = 2 * Double.pi / 60

    /// The space the art needs round its centre: the ring's width, and the galaxy's height face on during the opening.
    static func height(radius: CGFloat) -> CGFloat { radius * 2.3 }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion && finishedAt == nil)) { context in
            let clock = reduceMotion ? 0 : context.date.timeIntervalSince(appeared)
            let finish = finishedAt.map { min(1, max(0, context.date.timeIntervalSince($0) / Self.finishLength)) } ?? 0
            Canvas { canvas, size in
                draw(in: &canvas, size: size, clock: clock, now: context.date, finish: finish)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - The scene

    /// Where the galaxy is on the screen, how far it has lain back, turned and unfurled.
    private struct Frame {
        let centre: CGPoint
        let slant: CGFloat
        let lean: Double
        let turn: Double
        let scale: CGFloat

        /// A point of the galaxy's plane, `distance` from its core at `angle`, on the screen.
        func plane(_ distance: CGFloat, _ angle: Double) -> CGPoint {
            let x = distance * scale * cos(angle + turn)
            let y = distance * scale * slant * sin(angle + turn)
            return CGPoint(x: centre.x + x * cos(lean) - y * sin(lean), y: centre.y + x * sin(lean) + y * cos(lean))
        }
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, clock: Double, now: Date, finish: Double) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let unfurl = ProOpeningScript.unfurl.pose(at: time)
        let tilt = ProOpeningScript.tilt.pose(at: time).scale
        let galaxy = Frame(
            centre: centre, slant: 1 + (Self.slant - 1) * tilt, lean: Self.lean * tilt,
            turn: Self.spin * clock + unfurl.rotation * .pi / 180 + 4 * pow(finish, 2), scale: unfurl.scale
        )
        let plane = Frame(centre: centre, slant: Self.slant, lean: Self.lean, turn: 0, scale: 1)
        drawShootingStar(in: &canvas, centre: centre, width: size.width, clock: clock)
        drawRing(in: &canvas, plane, now: now, finish: finish, front: false)
        var arms = canvas
        arms.opacity = ProOpeningScript.unfurlFade.pose(at: time).opacity
        drawDust(in: &arms, galaxy)
        drawStars(in: &arms, galaxy)
        drawCore(in: &canvas, centre: centre, clock: clock, finish: finish)
        drawRing(in: &canvas, plane, now: now, finish: finish, front: true)
        if style == .export { drawVideoStar(in: &canvas, plane, clock: clock) }
        drawFinish(in: &canvas, plane, finish: finish)
    }

    // MARK: - The galaxy

    /// A star of the galaxy: its place in the plane (× `radius`), how big and bright it is, its colour, when it lights on the opening.
    private struct Mote {
        let distance: CGFloat
        let angle: Double
        let diameter: CGFloat
        let opacity: Double
        let color: Color
        let glows: Bool
        let delay: Double
    }

    /// A soft light along an arm: its place, its reach (× `radius`), its colour and strength.
    private struct Dust {
        let distance: CGFloat
        let angle: Double
        let reach: CGFloat
        let color: Color
        let opacity: Double
        let delay: Double
    }

    private struct Galaxy {
        let motes: [Mote]
        let dust: [Dust]
    }

    private static let warm = makeGalaxy(Palette.Scripts.proGalaxy, violet: false)
    private static let violet = makeGalaxy(Palette.Scripts.proGalaxyUltra, violet: true)

    /// The colour `along` an arm (0 at the core, 1 at its tip).
    private static func tone(_ along: Double, _ stops: [(color: Color, at: Double)]) -> Color {
        for index in 1..<stops.count where along <= stops[index].at {
            let from = stops[index - 1]
            return from.color.mix(with: stops[index].color, by: (along - from.at) / (stops[index].at - from.at))
        }
        return stops[stops.count - 1].color
    }

    /// The canvas the owner approved, star for star: two arms of 70 stars each on a spiral of two and a half turns, about one in eleven bigger
    /// and glowing; 14 soft lights on each arm, gold near the core; 46 faint stars between them. The same on every launch.
    private static func makeGalaxy(_ stops: [(color: Color, at: Double)], violet: Bool) -> Galaxy {
        var seed: UInt64 = 11
        func random() -> Double {
            seed = seed * 16_807 % 2_147_483_647
            return Double(seed) / 2_147_483_647
        }
        var motes: [Mote] = []
        var dust: [Dust] = []
        for arm in 0..<2 {
            for index in 0..<70 {
                let along = Double(index) / 69
                let angle = Double(arm) * .pi + along * 2.5 * .pi
                let reach = 0.05 + 0.43 * pow(along, 0.8)
                let jitter = (random() - 0.5) * 0.08 * (0.3 + along)
                let glows = random() < 0.09
                let diameter = glows ? 3.4 : 0.9 + random() * 1.7
                motes.append(Mote(
                    distance: 2 * (reach + jitter), angle: angle, diameter: diameter, opacity: 0.5 + random() * 0.5, color: tone(along, stops),
                    glows: glows, delay: 1.98 + along * 0.6
                ))
            }
            for index in 0..<14 {
                let along = (Double(index) + 0.5) / 14
                let color = !violet && along < 0.35 ? Palette.acc : along < 0.55 ? Palette.Scripts.proGalaxy[3].color : Palette.Scripts.proGalaxy[4].color
                dust.append(Dust(
                    distance: 2 * (0.05 + 0.43 * pow(along, 0.8)), angle: Double(arm) * .pi + along * 2.5 * .pi,
                    reach: (12 + 16 * (1 - along) + random() * 6) / 100, color: color, opacity: 0.36 - 0.16 * along, delay: 2 + along * 0.6
                ))
            }
        }
        let field = violet ? Palette.Scripts.proGalaxyUltra[1].color : Palette.ink
        for _ in 0..<46 {
            let angle = random() * 2 * .pi
            let reach = sqrt(random()) * 0.47
            let diameter = 0.7 + random() * 0.9
            let opacity = 0.25 + random() * 0.35
            motes.append(Mote(
                distance: 2 * reach, angle: angle, diameter: diameter, opacity: opacity, color: field, glows: false, delay: 2.1 + random() * 0.5
            ))
        }
        return Galaxy(motes: motes, dust: dust)
    }

    private var galaxy: Galaxy { style == .ultra ? Self.violet : Self.warm }

    /// How far a star or a light has come in on the opening: it pops from nothing over `length`, eased out.
    private func entrance(from delay: Double, length: Double) -> Double {
        let progress = min(1, max(0, (time - delay) / length))
        return 1 - (1 - progress) * (1 - progress)
    }

    /// The soft lights, lying in the galaxy's plane.
    private func drawDust(in canvas: inout GraphicsContext, _ frame: Frame) {
        var plane = canvas
        plane.translateBy(x: frame.centre.x, y: frame.centre.y)
        plane.rotate(by: .radians(frame.lean))
        plane.scaleBy(x: 1, y: frame.slant)
        for light in galaxy.dust {
            let shown = entrance(from: light.delay, length: 0.9)
            guard shown > 0.01 else { continue }
            let distance = light.distance * radius * frame.scale
            let point = CGPoint(x: distance * cos(light.angle + frame.turn), y: distance * sin(light.angle + frame.turn))
            let reach = light.reach * radius * frame.scale
            plane.fill(
                LightFX.disc(point, reach),
                with: .radialGradient(
                    Gradient(colors: [light.color.opacity(light.opacity * shown), light.color.opacity(0)]), center: point, startRadius: 0, endRadius: reach
                )
            )
        }
    }

    private func drawStars(in canvas: inout GraphicsContext, _ frame: Frame) {
        for mote in galaxy.motes {
            let shown = entrance(from: mote.delay, length: 0.45)
            guard shown > 0.01 else { continue }
            let point = frame.plane(mote.distance * radius, mote.angle)
            let dot = mote.diameter * 0.4 * shown
            if mote.glows {
                let halo = dot + 7
                canvas.fill(
                    LightFX.disc(point, halo),
                    with: .radialGradient(Gradient(colors: [mote.color.opacity(0.55 * shown), .clear]), center: point, startRadius: 0, endRadius: halo)
                )
            }
            canvas.fill(LightFX.disc(point, dot), with: .color(mote.color.opacity(mote.opacity * shown)))
        }
    }

    /// The planet at the core: Cue's gold, lit from the top left with its night side to the bottom right and a fine rim of light, in a glow that
    /// breathes (6 s); born white-hot from the star that flew up and cooling to gold.
    private func drawCore(in canvas: inout GraphicsContext, centre: CGPoint, clock: Double, finish: Double) {
        let core = CoreColor.gold
        let birth = ProOpeningScript.coreBirth.pose(at: time)
        guard birth.opacity > 0.01, birth.scale > 0.01 else { return }
        let swell = 1 + 0.8 * Self.smooth(0, 0.55, finish)
        let glow: (opacity: Double, scale: Double)
        if time < ProOpeningScript.glowBreathes {
            let pose = ProOpeningScript.coreGlow.pose(at: time)
            glow = (pose.opacity, pose.scale)
        } else {
            let breath = reduceMotion ? 0.5 : (1 - cos(clock / 6 * 2 * .pi)) / 2
            glow = (0.75 + 0.25 * breath, 1 + 0.12 * breath)
        }
        let glowColour = Color(hex: core.glow.hex)
        let reach = radius * 0.435 * glow.scale * swell
        canvas.fill(
            LightFX.disc(centre, reach),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: glowColour.opacity(0.42 * glow.opacity), location: 0), .init(color: glowColour.opacity(0.1 * glow.opacity), location: 0.55),
                    .init(color: glowColour.opacity(0), location: 1),
                ]),
                center: centre, startRadius: 0, endRadius: reach
            )
        )
        let size = radius * 0.095 * birth.scale * swell
        let halo = size + 14
        canvas.fill(
            LightFX.disc(centre, halo),
            with: .radialGradient(Gradient(colors: [glowColour.opacity(0.7), glowColour.opacity(0)]), center: centre, startRadius: size, endRadius: halo)
        )
        let stops = core.stops
        canvas.fill(
            LightFX.disc(centre, size),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hex: stops.highlight), location: 0), .init(color: Color(hex: stops.light), location: 0.34),
                    .init(color: Color(hex: stops.body), location: 0.68), .init(color: Color(hex: stops.edge), location: 1),
                ]),
                center: CGPoint(x: centre.x - size * 0.24, y: centre.y - size * 0.32), startRadius: 0, endRadius: size * 1.5
            )
        )
        // The night side, and the rim the light catches on the lit side.
        canvas.fill(
            LightFX.disc(centre, size),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .black.opacity(0), location: 0), .init(color: .black.opacity(0), location: 0.55),
                    .init(color: .black.opacity(0.45), location: 1),
                ]),
                center: CGPoint(x: centre.x - size * 0.45, y: centre.y - size * 0.5), startRadius: 0, endRadius: size * 2.1
            )
        )
        canvas.stroke(
            Path { path in
                path.addArc(center: centre, radius: size - 0.4, startAngle: .degrees(150), endAngle: .degrees(300), clockwise: false)
            },
            with: .color(Color(hex: core.stops.highlight).opacity(0.7)), lineWidth: 0.8
        )
        let hot = ProOpeningScript.whiteHot.pose(at: time).opacity
        if hot > 0.01 { canvas.fill(LightFX.disc(centre, size), with: .color(.white.opacity(hot))) }
    }

    // MARK: - The ring

    private var nodeCount: Int { style == .ultra ? UsagePolicy.proUltraScriptsPerMonth : 12 }

    /// Node `index`'s angle round the ring: the first at the front, the others going round.
    private func nodeAngle(_ index: Int) -> Double {
        .pi / 2 + 2 * .pi * Double(index) / Double(nodeCount)
    }

    private var stagger: Double { style == .ultra ? 0.014 : 0.035 }

    /// How lit node `index` is now, 0…1: the light goes round from the front, each node taking 0.3 s.
    private func light(of index: Int, now: Date) -> Double {
        if style == .ultra { return 1 }
        let was = index < ring.was ? 1.0 : 0
        let lit = index < ring.lit ? 1.0 : 0
        guard was != lit else { return lit }
        let progress = min(1, max(0, (now.timeIntervalSince(ring.since) - Double(index) * stagger) / 0.3))
        return was + (lit - was) * progress
    }

    /// How long a node sparkles when it lights.
    private static let sparkleLength = 0.75

    /// Seconds since node `index` began to light, while it sparkles; nil when it is not lighting (or is going out).
    private func ignition(of index: Int, now: Date) -> Double? {
        guard style != .ultra, !reduceMotion, index >= ring.was, index < ring.lit else { return nil }
        let age = now.timeIntervalSince(ring.since) - Double(index) * stagger
        return age >= 0 && age < Self.sparkleLength ? age : nil
    }

    /// The far half of the ring behind the galaxy (all of it, faintly) or the near half in front of it, and that half's nodes. It wipes in from
    /// the left on the opening.
    private func drawRing(in canvas: inout GraphicsContext, _ plane: Frame, now: Date, finish: Double, front: Bool) {
        let wipe = ProOpeningScript.ringWipe.pose(at: time).scale
        guard wipe > 0.01 else { return }
        let reach = radius * Self.ringShare * (1 - Self.ease(Self.smooth(0, 0.6, finish)))
        let ultra = style == .ultra
        var line = Path()
        for step in 0...96 {
            let angle = Double(step) / 96 * 2 * .pi
            if front, sin(angle) < 0 { continue }
            let point = plane.plane(reach, angle)
            if line.isEmpty { line.move(to: point) } else { line.addLine(to: point) }
        }
        var wiped = canvas
        let left = plane.centre.x - radius * Self.ringShare - 6
        wiped.clip(to: Path(CGRect(x: left, y: 0, width: (radius * Self.ringShare + 6) * 2 * wipe, height: plane.centre.y * 2)))
        let tint = ultra ? Palette.aiText : Palette.ink2
        wiped.stroke(line, with: .color(tint.opacity((front ? 0.55 : 0.25) * (1 - finish))), lineWidth: 1)

        for index in 0..<nodeCount {
            let angle = nodeAngle(index)
            guard (sin(angle) >= -0.01) == front else { continue }
            let pop = ProOpeningScript.nodePop(index, of: nodeCount).pose(at: time)
            guard pop.opacity > 0.01 else { continue }
            let point = plane.plane(reach, angle)
            let lit = light(of: index, now: now)
            let depth = front ? 1.0 : 0.5
            let igniting = ignition(of: index, now: now)
            let swell = igniting.map { 1 + 0.7 * Self.flare($0 / Self.sparkleLength) } ?? 1
            let dot = (ultra ? 2 : 2.5) * pop.scale * swell
            if lit > 0.01 {
                let halo = dot + 7
                let glow = ultra ? Palette.Scripts.ultraDust[0].opacity(0.75) : Palette.acc.opacity(0.6)
                canvas.fill(
                    LightFX.disc(point, halo),
                    with: .radialGradient(Gradient(colors: [glow.opacity(lit * depth * pop.opacity), .clear]), center: point, startRadius: 0, endRadius: halo)
                )
            }
            let litColour = ultra ? Palette.Scripts.proGalaxyUltra[0].color : Palette.Universe.starCream
            let colour = Palette.ink3.mix(with: litColour, by: lit)
            canvas.fill(LightFX.disc(point, dot), with: .color(colour.opacity(depth * pop.opacity)))
            if let igniting {
                drawSparkle(in: &canvas, at: point, age: igniting, seed: index, colour: litColour, strength: depth * pop.opacity)
            } else if lit > 0.99, !reduceMotion {
                drawTwinkle(in: &canvas, at: point, now: now, seed: index, colour: litColour, strength: depth * pop.opacity)
            }
        }
    }

    /// A node lighting (owner, 30/10/2026: more sparkle when the plan changes): a flash, a four-pointed glint turning a little as it fades, and
    /// five sparks flying out along the plane, added to the light under them.
    private func drawSparkle(in canvas: inout GraphicsContext, at point: CGPoint, age: Double, seed: Int, colour: Color, strength: Double) {
        let progress = age / Self.sparkleLength
        let flare = Self.flare(progress)
        var light = canvas
        light.blendMode = .plusLighter
        let flash = 3 + 9 * flare
        light.fill(
            LightFX.disc(point, flash),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.85 * flare * strength), Palette.acc.opacity(0.45 * flare * strength), .clear]),
                center: point, startRadius: 0, endRadius: flash
            )
        )
        Self.glint(in: &light, at: point, length: 4 + 12 * flare, turn: 0.5 * progress, colour: colour, opacity: flare * strength)
        for spark in 0..<5 {
            let angle = 2 * Double.pi * (Double(spark) / 5 + Double(seed) * 0.137)
            let reach = 3 + 15 * Self.ease(progress)
            let spot = CGPoint(x: point.x + cos(angle) * reach, y: point.y + sin(angle) * reach * 0.6)
            light.fill(LightFX.disc(spot, 0.2 + 1.1 * (1 - progress)), with: .color(colour.opacity((1 - progress) * strength)))
        }
    }

    /// Now and then a lit node catches the light: a small glint for a third of a second, each node at its own moment (every 2.6–4.4 s).
    private func drawTwinkle(in canvas: inout GraphicsContext, at point: CGPoint, now: Date, seed: Int, colour: Color, strength: Double) {
        let period = 2.6 + Double((seed * 7) % 10) * 0.2
        let phase = (now.timeIntervalSinceReferenceDate / period + Double(seed) * 0.37).truncatingRemainder(dividingBy: 1)
        guard phase < 0.1 else { return }
        let flare = sin(phase / 0.1 * .pi)
        var light = canvas
        light.blendMode = .plusLighter
        Self.glint(in: &light, at: point, length: 3 + 5 * flare, turn: 0, colour: colour, opacity: 0.6 * flare * strength)
    }

    /// A four-pointed star of light: long thin points round a bright middle.
    private static func glint(in canvas: inout GraphicsContext, at point: CGPoint, length: CGFloat, turn: Double, colour: Color, opacity: Double) {
        guard opacity > 0.01 else { return }
        var star = Path()
        for vertex in 0..<8 {
            let angle = turn + Double(vertex) * .pi / 4
            let reach = vertex.isMultiple(of: 2) ? length : 1.3
            let spot = CGPoint(x: point.x + cos(angle) * reach, y: point.y + sin(angle) * reach)
            if vertex == 0 { star.move(to: spot) } else { star.addLine(to: spot) }
        }
        star.closeSubpath()
        canvas.fill(
            star,
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(opacity), colour.opacity(opacity * 0.8), colour.opacity(0)]),
                center: point, startRadius: 0, endRadius: length
            )
        )
    }

    /// A sparkle's brightness over its life (0…1): up in its first sixth, then dying away.
    private static func flare(_ progress: Double) -> Double {
        progress < 0.16 ? ease(progress / 0.16) : pow(1 - (progress - 0.16) / 0.84, 2)
    }

    // MARK: - Moments

    /// The calm Pro from an export: the waiting video, a star at the ring's front sending out a ring of light every 2 s.
    private func drawVideoStar(in canvas: inout GraphicsContext, _ plane: Frame, clock: Double) {
        let point = plane.plane(radius * Self.ringShare, nodeAngle(0))
        canvas.fill(
            LightFX.disc(point, 16),
            with: .radialGradient(Gradient(colors: [Palette.acc.opacity(0.8), Palette.acc.opacity(0)]), center: point, startRadius: 3, endRadius: 16)
        )
        canvas.fill(LightFX.disc(point, 4.5), with: .color(.white))
        guard !reduceMotion else { return }
        let ping = 1 - pow(1 - clock.truncatingRemainder(dividingBy: 2) / 2, 2)
        canvas.stroke(LightFX.disc(point, 6.9 + 23 * ping), with: .color(Palette.acc.opacity(0.85 * (1 - ping))), lineWidth: 1.5)
    }

    /// Every 11 s (the first 4.5 s in) a shooting star crosses above the galaxy, left to right, falling a little.
    private func drawShootingStar(in canvas: inout GraphicsContext, centre: CGPoint, width: CGFloat, clock: Double) {
        guard !reduceMotion, time >= ProOpeningScript.settled, clock > 4.5 else { return }
        let lap = (clock - 4.5).truncatingRemainder(dividingBy: 11)
        guard lap >= 9.35, lap < 10.45 else { return }
        let progress = (lap - 9.35) / 1.1
        let opacity = progress < 0.18 ? progress / 0.18 : 1 - (progress - 0.18) / 0.82
        let angle = 16 * Double.pi / 180
        let tail = CGPoint(x: width * 0.05 + 230 * progress, y: centre.y - radius * 0.72 + 66 * progress)
        let head = CGPoint(x: tail.x + 92 * cos(angle), y: tail.y + 92 * sin(angle))
        var streak = Path()
        streak.move(to: tail)
        streak.addLine(to: head)
        canvas.stroke(
            streak, with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.9 * opacity)]), startPoint: tail, endPoint: head),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )
    }

    /// The creator subscribed: a white bloom as the nodes reach the core, and a gold wave out across the galaxy's plane.
    private func drawFinish(in canvas: inout GraphicsContext, _ plane: Frame, finish: Double) {
        guard finish > 0 else { return }
        let bloom = Self.smooth(0.45, 0.6, finish) * (1 - Self.smooth(0.6, 1, finish))
        if bloom > 0.01 {
            let reach = radius * 1.2
            canvas.fill(
                LightFX.disc(plane.centre, reach),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.9 * bloom), Palette.Universe.starGold.opacity(0.5 * bloom), .clear]),
                    center: plane.centre, startRadius: 0, endRadius: reach
                )
            )
        }
        let wave = Self.smooth(0.55, 1, finish)
        guard wave > 0, wave < 1 else { return }
        var ellipse = Path()
        let reach = radius * (0.3 + 1.3 * wave)
        for step in 0...72 {
            let point = plane.plane(reach, Double(step) / 72 * 2 * .pi)
            if step == 0 { ellipse.move(to: point) } else { ellipse.addLine(to: point) }
        }
        canvas.stroke(ellipse, with: .color(Palette.acc.opacity(0.8 * (1 - wave))), lineWidth: 2)
    }

    // MARK: - Easing

    private static func ease(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private static func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
        ease(min(1, max(0, (value - low) / (high - low))))
    }
}
