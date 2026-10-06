//
//  OnboardingUniverseCanvas.swift
//  Cue Studio
//

import SwiftUI

/// The creator as a white star ("YOU") with rays, and a world on its own tilted orbit for each topic (the board's 1.2: orbits of 140, 216 and
/// 292 pt across, flattened to 42% and turned −12°). A picked topic's planet pops where the light from its chip lands (`TopicBirth`) and its
/// orbit draws round it. On entry a yellow ring opens round the core, in continuity with the star that exploded on 1.1.
struct OnboardingUniverseCanvas: View {
    let topics: [OnboardingTopic]
    let born: [String: Date]
    /// When the first video's star was lit, if it was: a yellow star above the orbits with a line to the creator.
    var star: Date?
    /// The chapter's opening clock (`MotionScreen`): the yellow ring and the cross of light at the core play from it. Nil shows the core at rest.
    var opening: MotionTime?
    /// UI tests: the youngest world stands still at this age.
    var frozenBirthAge: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The orbit's width at `index` (the first picked is the smallest), its tilt, and how long a turn takes (seconds).
    private static func radiusX(_ index: Int) -> CGFloat { 70 + CGFloat(index) * 38 }
    private static let squash: CGFloat = 0.42
    private static let tilt = Angle.degrees(-12)
    private static let periods: [Double] = [14, 22, 9, 18]
    private static let diameters: [CGFloat] = [18, 14, 16, 14]

    /// Where the planet of the topic at `index` is, on a canvas of `size`, at `time` (seconds since the reference date).
    static func worldPoint(index: Int, in size: CGSize, time: TimeInterval) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radiusX = Self.radiusX(index)
        let angle = Double(index) * 2.1 + 2 * .pi * time / periods[min(index, periods.count - 1)]
        let local = CGPoint(x: radiusX * cos(angle), y: radiusX * squash * sin(angle))
        let cosT = cos(tilt.radians), sinT = sin(tilt.radians)
        return CGPoint(x: center.x + local.x * cosT - local.y * sinT, y: center.y + local.x * sinT + local.y * cosT)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            Canvas { canvas, size in
                draw(in: &canvas, size: size, time: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate, now: context.date)
            }
        }
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval, now: Date) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        drawMotes(in: &canvas, center: center, time: time)
        drawCore(in: &canvas, center: center, time: time)
        if let opening, !opening.isStill || opening.clock > 0 { drawEntry(at: opening.clock, in: &canvas, center: center) }
        if let star { drawStar(from: star, in: &canvas, center: center, size: size, now: now) }
        // A world per topic.
        for (index, topic) in topics.enumerated() {
            let age = reduceMotion ? 99 : frozenAge(for: topic, now: now)
            drawWorld(topic, index: index, age: age, in: &canvas, center: center, size: size, time: time)
        }
    }

    // MARK: - The motes

    /// Eight specks of light the core pulls in (the board's `grav`): each starts out in the dark, glows to 90% by a quarter of its way, and falls
    /// toward the core shrinking to 0.3, `cubic-bezier(.42,0,1,1)`, again and again. Offsets from the core: start, the way it falls, its
    /// cycle and when its first one begins.
    private static let motes: [(from: CGPoint, by: CGPoint, cycle: Double, delay: Double)] = [
        (CGPoint(x: -155, y: -116), CGPoint(x: 132, y: 99), 6.6, 3.7), (CGPoint(x: 155, y: -66), CGPoint(x: -132, y: 56), 7.0, 4.7),
        (CGPoint(x: 135, y: 104), CGPoint(x: -115, y: -88), 6.8, 4.6), (CGPoint(x: -135, y: 114), CGPoint(x: 115, y: -97), 5.1, 2.3),
        (CGPoint(x: 5, y: -136), CGPoint(x: -4, y: 116), 7.4, 3.2), (CGPoint(x: -75, y: 134), CGPoint(x: 64, y: -114), 7.3, 0.6),
        (CGPoint(x: 95, y: -116), CGPoint(x: -81, y: 99), 6.2, 1.2), (CGPoint(x: 55, y: 134), CGPoint(x: -47, y: -114), 6.4, 2.9),
    ]

    private func drawMotes(in canvas: inout GraphicsContext, center: CGPoint, time: TimeInterval) {
        guard !reduceMotion else { return }
        let fall = UnitCurve.css(0.42, 0, 1, 1)
        for mote in Self.motes {
            let phase = (time - mote.delay).truncatingRemainder(dividingBy: mote.cycle) / mote.cycle
            guard time > mote.delay else { continue }
            let progress = phase < 0 ? phase + 1 : phase
            let eased = fall.value(at: progress)
            let opacity = progress < 0.25 ? progress / 0.25 * 0.9 : 0.9 * (1 - (progress - 0.25) / 0.75)
            let point = CGPoint(x: center.x + mote.from.x + mote.by.x * eased, y: center.y + mote.from.y + mote.by.y * eased)
            let radius = 1 * (1 - 0.7 * progress)
            canvas.drawLayer { layer in
                layer.addFilter(.shadow(color: Palette.starLilac.opacity(0.9), radius: 5))
                layer.fill(
                    Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(Palette.starLilac.opacity(opacity))
                )
            }
        }
    }

    // MARK: - The core

    /// The board's core (1.2): a 22 pt sphere (`#fff → #F2EEFF → #C9BFFF`) in two soft glows that breathe over 3 s (white 18 → 26 pt of blur,
    /// violet 60 → 84), twelve faint rays turning once in a minute, and a ring of light that opens and fades every 2.8 s.
    private func drawCore(in canvas: inout GraphicsContext, center: CGPoint, time: TimeInterval) {
        let breath = reduceMotion ? 0 : 0.5 - 0.5 * cos(2 * .pi * time / 3)
        softDisc(
            in: &canvas, center: center, radius: 11 + 20 + 12 * breath, blur: 60 + 24 * breath,
            color: Palette.nightViolet.opacity(0.30 + 0.10 * breath)
        )
        softDisc(
            in: &canvas, center: center, radius: 11 + 6 + 4 * breath, blur: 18 + 8 * breath, color: .white.opacity(0.30 + 0.12 * breath)
        )
        drawRays(in: &canvas, center: center, time: time)
        if !reduceMotion {
            let halo = Self.clip.pose(of: "L18", at: time, loops: true)
            let radius = 20 * halo.sx
            canvas.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Palette.starLilac.opacity(0.7 * halo.opacity)), lineWidth: 1.5
            )
        }
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - 11, y: center.y - 11, width: 22, height: 22)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white, location: 0), .init(color: Palette.flightCoreMid, location: 0.5),
                    .init(color: Palette.flightCoreEdge, location: 1),
                ]),
                center: center, startRadius: 0, endRadius: 11
            )
        )
        canvas.draw(
            Text("YOU").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.4).foregroundStyle(Palette.flightInk.opacity(0.75)),
            at: CGPoint(x: center.x, y: center.y + 33)
        )
    }

    /// A glow like CSS's `box-shadow: 0 0 <blur> <spread> colour`: solid out to `radius - blur / 2`, half at `radius`, nothing at `radius + blur / 2`.
    private func softDisc(in canvas: inout GraphicsContext, center: CGPoint, radius: CGFloat, blur: CGFloat, color: Color) {
        let outer = radius + blur / 2
        let inner = max(0, radius - blur / 2)
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color, location: 0), .init(color: color, location: inner / outer),
                    .init(color: color.opacity(0.5), location: radius / outer), .init(color: color.opacity(0), location: 1),
                ]),
                center: center, startRadius: 0, endRadius: outer
            )
        )
    }

    /// `repeating-conic-gradient` of the board: a ray every 30°, 8° wide and peaking at 17°, seen through a mask solid to 14% of the 140 pt box
    /// and gone at 62%; the whole turns in 60 s.
    private func drawRays(in canvas: inout GraphicsContext, center: CGPoint, time: TimeInterval) {
        let turn = reduceMotion ? 0 : time / 60 * 360
        for ray in 0..<12 {
            let middle = Angle.degrees(Double(ray) * 30 + 17 + turn - 90)
            var wedge = Path()
            wedge.move(to: center)
            wedge.addArc(center: center, radius: 44, startAngle: middle - .degrees(4), endAngle: middle + .degrees(4), clockwise: false)
            wedge.closeSubpath()
            canvas.fill(
                wedge,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Palette.starLilac.opacity(0.10), location: 0), .init(color: Palette.starLilac.opacity(0.10), location: 9.8 / 44),
                        .init(color: Palette.starLilac.opacity(0), location: 1),
                    ]),
                    center: center, startRadius: 0, endRadius: 44
                )
            )
        }
    }

    /// How old a world is: from its pick, or, in a UI test taking a picture, the frozen age for the one picked last and "long ago" for the others.
    private func frozenAge(for topic: OnboardingTopic, now: Date) -> TimeInterval {
        guard let picked = born[topic.id] else { return 99 }
        guard let frozenBirthAge else { return now.timeIntervalSince(picked) }
        return picked == born.values.max() ? frozenBirthAge : 99
    }

    /// The core lights as the star lands (1.25 s): a yellow ring opens in 0.9 s and, a little after, a cross of light opens and closes on it.
    private func drawEntry(at clock: Double, in canvas: inout GraphicsContext, center: CGPoint) {
        let ring = Self.clip.pose(of: "L69", at: clock)
        if ring.opacity > 0.01 {
            let radius = 21 * ring.sx
            canvas.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Palette.acc.opacity(ring.opacity)), lineWidth: 1.5
            )
        }
        let cross = Self.clip.pose(of: "L20", at: clock)
        guard cross.opacity > 0.01, cross.sx > 0.01 else { return }
        var layer = canvas
        layer.opacity = cross.opacity
        layer.translateBy(x: center.x, y: center.y)
        layer.scaleBy(x: cross.sx, y: cross.sx)
        layer.addFilter(.shadow(color: .white.opacity(0.8), radius: 6))
        layer.fill(Path(roundedRect: CGRect(x: -35, y: -0.9, width: 70, height: 1.8), cornerRadius: 0.9), with: .color(.white.opacity(0.9)))
        layer.fill(Path(roundedRect: CGRect(x: -0.9, y: -24.5, width: 1.8, height: 49), cornerRadius: 0.9), with: .color(.white.opacity(0.9)))
    }

    private static let clip = MotionLibrary.clip("1.2_topics")

    /// The first video, shared or saved: a four-point yellow star joined to "YOU" by a thin line that draws itself.
    private func drawStar(from lit: Date, in canvas: inout GraphicsContext, center: CGPoint, size: CGSize, now: Date) {
        let age = now.timeIntervalSince(lit)
        guard age > 0 else { return }
        let place = CGPoint(x: center.x + size.width * 0.16, y: center.y - size.height * 0.38)
        var link = Path()
        link.move(to: center)
        link.addLine(to: place)
        canvas.stroke(link.trimmedPath(from: 0, to: min(1, age / 0.8)), with: .color(Palette.acc.opacity(0.5)), lineWidth: 1)
        let pop = min(1, age / 0.5)
        let radius = 11 * (pop < 0.6 ? pop / 0.6 * 1.5 : 1.5 - (pop - 0.6) / 0.4 * 0.5)
        var star = Path()
        for step in 0..<8 {
            let length = step.isMultiple(of: 2) ? radius : radius * 0.26
            let angle = Double(step) * .pi / 4 - .pi / 2
            let corner = CGPoint(x: place.x + length * cos(angle), y: place.y + length * sin(angle))
            if step == 0 { star.move(to: corner) } else { star.addLine(to: corner) }
        }
        star.closeSubpath()
        var glow = canvas
        glow.addFilter(.shadow(color: Palette.acc.opacity(0.9), radius: 8))
        glow.fill(star, with: .color(Palette.acc))
        if age > 0.6 {
            canvas.draw(
                Text(String(localized: "FIRST TAKE · TODAY")).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.accText),
                at: CGPoint(x: place.x, y: place.y - 22)
            )
        }
    }

    private func drawWorld(
        _ topic: OnboardingTopic, index: Int, age: TimeInterval, in canvas: inout GraphicsContext,
        center: CGPoint, size: CGSize, time: TimeInterval
    ) {
        let color = OnboardingTopic.color(at: index)
        let radiusX = Self.radiusX(index)
        let radiusY = radiusX * Self.squash
        // The orbit draws for 1.3 s from the landing (1.75 s after the pick), with a white light that runs round it once.
        let orbit = TopicBirth.pose(TopicBirth.orbit, at: age)
        var path = Path(ellipseIn: CGRect(x: -radiusX, y: -radiusY, width: radiusX * 2, height: radiusY * 2))
        path = path.applying(CGAffineTransform(rotationAngle: Self.tilt.radians).concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
        if orbit.drawn > 0 { canvas.stroke(path.trimmedPath(from: 0, to: orbit.drawn), with: .color(color.opacity(0.4)), lineWidth: 1) }
        let runner = TopicBirth.pose(TopicBirth.orbitLight, at: age)
        if runner.opacity > 0.01, let dash = runner.dash {
            let start = max(0, -dash / 100), end = min(1, (-dash + 6) / 100)
            if end > start {
                canvas.drawLayer { layer in
                    layer.addFilter(.shadow(color: Palette.starCream.opacity(0.9), radius: 4))
                    layer.stroke(path.trimmedPath(from: start, to: end), with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
        // The planet springs out where the light lands (×2.4 → ×0.82 → ×1.1 → ×1 in 0.76 s).
        let pop = TopicBirth.pose(TopicBirth.planet, at: age)
        guard pop.opacity > 0.01, pop.sx > 0.01 else { return }
        let point = Self.worldPoint(index: index, in: size, time: time)
        let diameter = Self.diameters[min(index, Self.diameters.count - 1)] * pop.sx
        canvas.drawLayer { layer in
            layer.addFilter(.shadow(color: color.opacity(0.8), radius: 6))
            layer.fill(
                Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter)),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.9), color, color.opacity(0.6)]),
                    center: CGPoint(x: point.x - diameter * 0.2, y: point.y - diameter * 0.2), startRadius: 0, endRadius: diameter
                )
            )
        }
        // Its name arrives 0.3 s after the landing, rising 4 pt, and leaves again after a couple of seconds.
        let label = TopicBirth.pose(TopicBirth.label, at: age)
        if label.opacity > 0.01 {
            canvas.draw(
                Text(topic.label.uppercased()).font(.system(size: 9.5, weight: .semibold, design: .monospaced)).tracking(1.3)
                    .foregroundStyle(color.opacity(label.opacity)),
                at: CGPoint(x: point.x, y: point.y + diameter / 2 + 12 + label.ty)
            )
        }
    }
}
