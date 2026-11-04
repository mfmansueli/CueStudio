//
//  UltraWaitScene.swift
//  Cue Studio
//

import SwiftUI

/// The scene round Ultra AI's star while it writes (`StarTransitionOverlay`; the owner's calls, 30/10/2026: a paid script waits in something
/// larger and more alive than Apple Intelligence's orbit, clean and never still). A small galaxy turns round the star inside the ring of
/// passes (`UltraPassOrbit`), seen at a slant: two spiral arms of soft light with a few sharp stars on them, turning all the while (one turn
/// in 26 s), brighter as the pass on now comes (`UltraSceneMoment.charge`). Each pass is a chapter (`UltraWaitTimeline`):
/// - the draft: each step of its words makes the star pulse and sends a spark riding an arm out to a new star, so the galaxy fills as it is
///   written;
/// - the polish in the creator's voice, which also corrects the claims (`UltraFlow.standard`): a beam sweeps round the galaxy and lights what it
///   touches, while the galaxy warms from violet to gold, from the inside out, as the polish comes.
/// The lab's flow with a check of its own (`UltraFlow.checked`) gives the beam a chapter between them, before the warmth.
///
/// As the star ignites, the idea's moon (white) leaves it for an orbit of its own; as a pass ends, its node on the ring lets go of a moon (the
/// draft's violet, the voice's gold; with the lab's check, the check's white instead of the idea's) and the galaxy gives it
/// its light; the moon, a small world lit on the side facing the star, takes a tilted orbit of its own (drawn, fainter behind the star),
/// passing behind the star and in front of it. Outside the ring, space goes on (`drawSky`): a field of faint stars turning slowly, a shooting
/// star every 6 to 10 s, a meteor shower every 11 to 16 s, a comet passing every 13 to 19 s; a chapter that runs past 20 s sends a comet low
/// over the galaxy, which flares as it passes. When the script is there (`finish`), the moons
/// and the galaxy spiral into the star, it flashes and a wave of light runs out (`IdeaTransitionService.ultraFinishDuration`).
///
/// Drawn in two layers so the star sits inside it: `.back` (the sky, the far half of the galaxy, the beam, what is behind the star) under the
/// star, `.front` (the near half, what passes in front, the wave) over it. Every frame is drawn from the timeline's date, so it moves while
/// the model thinks and nothing arrives. Cheap to draw: one Canvas each, gradients, no shadows or blurs. Decorative. Reduce Motion: nothing
/// turns, flies or crosses; the galaxy and the moons are still, and the finish fades.
struct UltraWaitScene: View {
    enum Layer {
        case back, front
    }

    let layer: Layer
    let meter: WritingProgressMeter?
    let centre: CGPoint
    /// The scene's reach from the star (`radius(in:)`).
    let radius: CGFloat
    /// When the scene began (the star ignited), in `now`'s seconds.
    let began: TimeInterval
    /// When the finish began, or nil while the AI writes.
    let finish: TimeInterval?

    @Environment(\.accessibilityReduceMotion) private var still

    /// The scene's clock: the meter's own (`WritingProgressMeter`), the time since the iPhone started.
    static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// The scene's reach on a screen: about a third of its width, never past 17% of its height (the words go under it) or 160 pt.
    static func radius(in size: CGSize) -> CGFloat {
        min(160, size.width * 0.36, size.height * 0.17)
    }

    /// The ring of passes round the star (`UltraPassOrbit`), at this share of the reach; the words go `wordsGap` under it.
    static let ringShare: CGFloat = 0.62
    static let wordsGap: CGFloat = 34

    var body: some View {
        TimelineView(.animation(minimumInterval: still ? 0.25 : 1.0 / 60)) { context in
            // The frame's own date, read in the drawing: a Canvas whose drawing reads nothing new is not drawn again, and the galaxy
            // stood still while the model thought (the owner saw it on the iPhone, 30/10/2026).
            let time = Self.now + context.date.timeIntervalSinceNow
            Canvas { canvas, size in
                let moment = UltraSceneMoment(
                    time: time, finish: finish, passStarts: meter?.passStarts ?? [], count: meter?.pass?.count ?? UltraFlow.standard.calls,
                    arrivals: meter?.arrivals ?? [], pass: meter?.pass?.index, passShown: meter?.passFraction ?? 0
                )
                if layer == .back { drawSky(in: &canvas, size: size, moment) }
                drawArms(in: &canvas, moment)
                if layer == .back { drawBeam(in: &canvas, moment) }
                drawStars(in: &canvas, moment)
                drawSparks(in: &canvas, moment)
                drawOrbits(in: &canvas, moment)
                drawMoons(in: &canvas, moment)
                if layer == .front { drawWave(in: &canvas, moment) }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// How much the star swells now from the last of its words, 0…1: it pulses as each step arrives.
    static func pulse(_ meter: WritingProgressMeter?, at time: TimeInterval) -> Double {
        guard let last = meter?.arrivals.last else { return 0 }
        let since = time - last.time
        guard since >= 0, since < 0.4 else { return 0 }
        return (1 - since / 0.4) * (1 - since / 0.4)
    }

    /// Pass `index`'s moon colour, of `count` passes: the draft's violet, the check's white, the voice's gold.
    static func moonColour(of index: Int, count: Int) -> Color {
        Palette.Scripts.ultraMoons[orbit(of: index, count: count)]
    }

    // MARK: - The galaxy

    /// The galaxy seen at a slant: its height is this share of its width, and it leans a little (radians).
    private static let slant: CGFloat = 0.36
    private static let lean = -0.14
    /// Its two arms: logarithmic spirals from `armStart` to `armEnd` of the reach, winding `armTurn` radians, drawn in `armSegments`.
    private static let armStart = 0.14
    private static let armEnd = 0.58
    private static let armTurn = 1.3 * Double.pi
    private static let armSegments = 32
    /// How fast it turns, radians a second (a turn in 26 s).
    private static let spin = 0.24
    /// Its stars: `firstStars` from the start, one more for each spark of the draft.
    private static let starCount = 26
    private static let firstStars = 10
    /// A spark's ride from the star along an arm to its new star, and that star's bloom as it lights.
    private static let sparkFlight: TimeInterval = 0.9
    private static let bloomTime: TimeInterval = 0.6

    /// How far the galaxy has turned now; the finish whirls it in.
    private func turned(_ moment: UltraSceneMoment) -> Double {
        (still ? 0 : Self.spin * (moment.time - began)) + 5 * moment.fall * moment.fall
    }

    /// The point `along` arm `arm` (0 at the star, 1 at its tip): its distance from the star and its angle round the galaxy.
    private func arm(_ arm: Int, along: Double, _ moment: UltraSceneMoment) -> (distance: CGFloat, angle: Double) {
        let distance = radius * Self.armStart * pow(Self.armEnd / Self.armStart, along) * (1 - Self.ease(moment.fall))
        return (distance, Double(arm) * .pi + along * Self.armTurn + turned(moment))
    }

    /// A point of the galaxy's plane, `distance` from the star at `angle`, on the screen.
    private func plane(_ distance: CGFloat, _ angle: Double) -> CGPoint {
        let x = distance * cos(angle)
        let y = distance * Self.slant * sin(angle)
        return CGPoint(x: centre.x + x * cos(Self.lean) - y * sin(Self.lean), y: centre.y + x * sin(Self.lean) + y * cos(Self.lean))
    }

    private func belongs(depth: Double) -> Bool {
        (depth >= 0) == (layer == .front)
    }

    /// Violet warming to gold where the polish has reached (`along`, from the inside out).
    private func tint(_ base: Color, along: Double, _ moment: UltraSceneMoment) -> Color {
        let warm = Self.smooth(0, 1, (moment.warmth * 1.3 - along) / 0.3)
        return warm > 0 ? base.mix(with: Palette.World.skyStarYou, by: warm) : base
    }

    /// How much the check's beam lights a point at `angle`, 0…1.
    private func swept(_ angle: Double, _ moment: UltraSceneMoment) -> Double {
        moment.beam * exp(-pow(Self.wrapped(angle - moment.beamAngle) / 0.25, 2))
    }

    /// The arms: a wide soft band of light and a fine bright line along it, brightest a third of the way out and gone at the star and at the
    /// tip. They unfurl from the star as the scene begins.
    private func drawArms(in canvas: inout GraphicsContext, _ moment: UltraSceneMoment) {
        let unfurl = still ? 1 : Self.ease(min(1, (moment.time - began) / 1.6))
        let glow = (0.6 + 0.4 * moment.charge) * (1 + 0.6 * moment.flare) * (1 - Self.smooth(0.8, 1, moment.fall))
        let band = Palette.Scripts.ultraDust[0]
        let line = Palette.Scripts.ultraDust[1]
        for index in 0..<2 {
            for segment in 0..<Self.armSegments {
                let from = Double(segment) / Double(Self.armSegments)
                guard from < unfurl else { break }
                let to = min(unfurl, Double(segment + 1) / Double(Self.armSegments))
                let start = arm(index, along: from, moment)
                let end = arm(index, along: to, moment)
                let middle = (from + to) / 2
                let depth = sin((start.angle + end.angle) / 2)
                guard belongs(depth: depth) else { continue }
                let lit = swept((start.angle + end.angle) / 2, moment)
                let shape = sin(.pi * pow(middle, 0.75)) * (unfurl < 1 ? min(1, (unfurl - middle) * 6) : 1)
                let strength = shape * glow * (0.55 + 0.45 * (depth + 1) / 2) * (1 + 1.2 * lit)
                var path = Path()
                path.move(to: plane(start.distance, start.angle))
                path.addLine(to: plane(end.distance, end.angle))
                canvas.stroke(
                    path, with: .color(tint(band, along: middle, moment).opacity(min(1, 0.11 * strength))),
                    style: StrokeStyle(lineWidth: 7, lineCap: .butt)
                )
                let fine = tint(line, along: middle, moment).mix(with: .white, by: lit * 0.6)
                canvas.stroke(path, with: .color(fine.opacity(min(1, 0.38 * strength))), style: StrokeStyle(lineWidth: 1, lineCap: .butt))
            }
        }
    }

    /// Star `index`'s place: its arm, how far along it, and how far off it (radians round the galaxy).
    private static func place(of index: Int) -> (arm: Int, along: Double, off: Double) {
        let seed = Double(index)
        return (index % 2, 0.12 + 0.82 * UltraWaitTimeline.unit(seed * 1.31), (UltraWaitTimeline.unit(seed * 2.71) - 0.5) * 0.45)
    }

    /// When star `index` lights: the first ones one after the other once the arms have unfurled, the others as their spark arrives.
    private func lighting(of index: Int, _ moment: UltraSceneMoment) -> TimeInterval? {
        if index < Self.firstStars { return began + 0.9 + 0.08 * Double(index) }
        let spark = index - Self.firstStars
        guard moment.draftArrivals.indices.contains(spark) else { return nil }
        return moment.draftArrivals[spark] + (still ? 0 : Self.sparkFlight)
    }

    /// The stars on the arms: a sharp point each, the brighter ones in a soft glow, twinkling slowly; a new one blooms as it lights.
    private func drawStars(in canvas: inout GraphicsContext, _ moment: UltraSceneMoment) {
        let fade = 1 - Self.smooth(0.8, 1, moment.fall)
        for index in 0..<Self.starCount {
            guard let lit = lighting(of: index, moment), moment.time >= lit else { continue }
            let since = moment.time - lit
            let place = Self.place(of: index)
            let onArm = arm(place.arm, along: place.along, moment)
            let angle = onArm.angle + place.off
            let depth = sin(angle)
            guard belongs(depth: depth) else { continue }
            let seed = Double(index)
            let point = plane(onArm.distance * (1 + (UltraWaitTimeline.unit(seed * 5.3) - 0.5) * 0.2), angle)
            let twinkle = still ? 1 : 0.7 + 0.3 * sin(moment.time * (0.7 + 1.3 * UltraWaitTimeline.unit(seed * 4.1)) + seed)
            let shown = min(1, since / (index < Self.firstStars ? 0.5 : 0.25))
            let bloom = still ? 0 : max(0, 1 - since / Self.bloomTime)
            let lift = max(bloom, swept(angle, moment), moment.flare * 0.6)
            let opacity = shown * twinkle * (0.6 + 0.4 * (depth + 1) / 2) * fade
            let base = index % 5 == 2 ? Palette.World.skyStarYou : (index % 2 == 0 ? Palette.Scripts.ultraDust[1] : Color.white)
            let colour = tint(base, along: place.along, moment)
            let size = (0.6 + 0.7 * UltraWaitTimeline.unit(seed * 3.7)) * (1 + 0.6 * lift)
            if UltraWaitTimeline.unit(seed * 4.9) > 0.6 || lift > 0.1 {
                let halo = size * (4 + 4 * lift)
                canvas.fill(
                    Self.circle(point, halo),
                    with: .radialGradient(
                        Gradient(colors: [colour.opacity(min(1, 0.3 + 0.5 * lift) * opacity), .clear]), center: point, startRadius: 0, endRadius: halo
                    )
                )
            }
            canvas.fill(Self.circle(point, size), with: .color(colour.opacity(opacity)))
        }
    }

    /// The check's beam: a soft slice of light going round the galaxy, brightest at its leading edge.
    private func drawBeam(in canvas: inout GraphicsContext, _ moment: UltraSceneMoment) {
        guard !still, moment.beam > 0.01 else { return }
        let reach = radius * Self.armEnd * 1.08
        let light = Palette.Scripts.ultraBeam
        for slice in 0..<5 {
            let lead = moment.beamAngle - Double(slice) * 0.08
            var wedge = Path()
            wedge.move(to: centre)
            for step in 0...4 { wedge.addLine(to: plane(reach, lead - 0.08 * Double(step) / 4)) }
            wedge.closeSubpath()
            let strength = 0.16 * moment.beam * (1 - Double(slice) / 5)
            canvas.fill(
                wedge,
                with: .radialGradient(Gradient(colors: [light.opacity(strength), light.opacity(0)]), center: centre, startRadius: 0, endRadius: reach)
            )
        }
    }

    /// The draft's sparks: each rides an arm from the star out to the star it lights.
    private func drawSparks(in canvas: inout GraphicsContext, _ moment: UltraSceneMoment) {
        guard !still, moment.fall == 0 else { return }
        for (spark, arrived) in moment.draftArrivals.prefix(Self.starCount - Self.firstStars).enumerated() {
            let flight = (moment.time - arrived) / Self.sparkFlight
            guard flight >= 0, flight < 1 else { continue }
            let place = Self.place(of: Self.firstStars + spark)
            let travel = 1 - pow(1 - flight, 2.4)
            let onArm = arm(place.arm, along: place.along * travel, moment)
            let angle = onArm.angle + place.off * travel
            guard belongs(depth: sin(angle)) else { continue }
            let point = plane(onArm.distance, angle)
            let opacity = flight < 0.12 ? flight / 0.12 : 1
            canvas.fill(
                Self.circle(point, 5),
                with: .radialGradient(Gradient(colors: [Color.white.opacity(0.4 * opacity), .clear]), center: point, startRadius: 0, endRadius: 5)
            )
            canvas.fill(SparkShape.path(center: point, radius: 2.6, turn: .radians(flight * 1.5)), with: .color(.white.opacity(opacity)))
        }
    }

    // MARK: - The moons

    /// The moons' orbits, by colour (violet, white, gold): reach (share of the scene's), slant, lean (radians), speed (radians a second)
    /// and where each starts.
    private static let moonReach: [CGFloat] = [0.8, 0.92, 1.04]
    private static let moonSlant: [CGFloat] = [0.34, 0.5, 0.26]
    private static let moonLean: [Double] = [-0.24, 0.35, 0.07]
    private static let moonSpeed: [Double] = [0.55, 0.95, 0.4]
    private static let moonPhase: [Double] = [0.3, 2.4, 4.4]

    /// Pass `index`'s orbit: the draft's first, the polish's last, the check's between (none without the check).
    private static func orbit(of index: Int, count: Int) -> Int {
        index == count - 1 ? 2 : min(index, 1)
    }

    private func moonPoint(_ orbit: Int, _ angle: Double, scale: CGFloat) -> CGPoint {
        let reach = radius * Self.moonReach[orbit] * scale
        let x = reach * cos(angle)
        let y = reach * Self.moonSlant[orbit] * sin(angle)
        let lean = Self.moonLean[orbit]
        return CGPoint(x: centre.x + x * cos(lean) - y * sin(lean), y: centre.y + x * sin(lean) + y * cos(lean))
    }

    /// Pass `index`'s node on the ring, where its moon is born (`UltraPassOrbit` puts it after its arc, clockwise from the top).
    private func node(of index: Int, count: Int) -> CGPoint {
        let turn = 2 * .pi * Double(index + 1) / Double(max(1, count))
        let ring = radius * Self.ringShare
        return CGPoint(x: centre.x + ring * sin(turn), y: centre.y - ring * cos(turn))
    }

    /// A moon on its way: its orbit and colour, when it is born and how long it takes to reach its orbit, and where it leaves from.
    private struct MoonFlight {
        let orbit: Int
        let colour: Color
        let birth: (time: TimeInterval, length: TimeInterval)
        let from: CGPoint
    }

    /// The idea's moon leaves the star this long after it ignites.
    private static let ideaMoonDelay: TimeInterval = 0.8

    /// Every moon of the scene: each pass's, from its node, and with the app's two passes (`UltraFlow.standard`) the idea's first, white,
    /// out of the star as it ignites into the orbit a check would take (the owner, 04/11/2026: with two passes the voice's moon is born only in
    /// the finish, so the wait had a single moon).
    private func flights(_ moment: UltraSceneMoment) -> [MoonFlight] {
        let count = moment.timeline.count
        var flights: [MoonFlight] = []
        if count == 2 {
            flights.append(MoonFlight(
                orbit: 1, colour: Palette.Scripts.ultraMoons[1], birth: (began + Self.ideaMoonDelay, UltraWaitTimeline.hold), from: centre
            ))
        }
        for index in 0..<count {
            guard let birth = birth(of: index, moment) else { continue }
            flights.append(MoonFlight(
                orbit: Self.orbit(of: index, count: count), colour: Self.moonColour(of: index, count: count), birth: birth,
                from: node(of: index, count: count)
            ))
        }
        return flights
    }

    /// When pass `index`'s moon is born, and how long it takes: as the next pass starts, or the last one in the finish (quickly).
    private func birth(of index: Int, _ moment: UltraSceneMoment) -> (time: TimeInterval, length: TimeInterval)? {
        if index == moment.timeline.count - 1 { return finish.map { ($0, 0.45) } }
        return moment.timeline.moonBirth(of: index).map { ($0, UltraWaitTimeline.hold) }
    }

    /// Each born moon's orbit, a fine line in its colour: fainter where it runs behind the star, brighter in front. It draws itself in as the
    /// moon flies out to it, and shrinks into the star at the finish.
    private func drawOrbits(in canvas: inout GraphicsContext, _ moment: UltraSceneMoment) {
        let scale = 1 - Self.ease(moment.fall)
        let steps = 96
        for flight in flights(moment) {
            let birth = flight.birth, orbit = flight.orbit
            guard moment.time >= birth.time else { continue }
            let shown = (still ? 1 : Self.ease(min(1, (moment.time - birth.time) / birth.length))) * (1 - moment.fall)
            var path = Path()
            var joined = false
            for step in 0..<steps {
                let from = 2 * .pi * Double(step) / Double(steps)
                let to = 2 * .pi * Double(step + 1) / Double(steps)
                guard belongs(depth: sin((from + to) / 2)) else {
                    joined = false
                    continue
                }
                if !joined { path.move(to: moonPoint(orbit, from, scale: scale)) }
                path.addLine(to: moonPoint(orbit, to, scale: scale))
                joined = true
            }
            let strength = layer == .front ? 0.32 : 0.17
            canvas.stroke(path, with: .color(flight.colour.opacity(strength * shown)), lineWidth: 0.9)
        }
    }

    private func drawMoons(in canvas: inout GraphicsContext, _ moment: UltraSceneMoment) {
        let scale = 1 - Self.ease(moment.fall)
        for flight in flights(moment) {
            let birth = flight.birth, orbit = flight.orbit
            guard moment.time >= birth.time else { continue }
            let age = moment.time - birth.time
            let born = still ? 1 : min(1, age / birth.length)
            let angle = Self.moonPhase[orbit] + (still ? 0 : Self.moonSpeed[orbit] * age) + 7 * moment.fall * moment.fall
            let depth = sin(angle)
            // Leaving its node it is over the ring; on its orbit it goes behind the star and in front of it.
            guard born < 1 ? layer == .front : belongs(depth: depth) else { continue }
            let colour = flight.colour
            let node = flight.from
            let onOrbit = moonPoint(orbit, angle, scale: scale)
            let travel = Self.ease(born)
            let point = CGPoint(x: node.x + (onOrbit.x - node.x) * travel, y: node.y + (onOrbit.y - node.y) * travel)
            let near = born < 1 ? 1 : (depth + 1) / 2
            // It pops out of the node and settles.
            let swell = still ? 1 : (0.4 + 0.6 * min(1, born / 0.25)) * (1 + 0.4 * sin(.pi * born))
            let size = (0.8 + 0.2 * near) * swell
            let opacity = (0.7 + 0.3 * near) * (still ? min(1, age / 0.3) : 1) * (1 - Self.smooth(0.85, 1, moment.fall))
            if !still, born < 1 {
                // A ring of light runs out of the node (or the star) as the moon leaves it.
                let ring = 4 + 32 * Self.ease(born)
                canvas.stroke(Self.circle(node, ring), with: .color(colour.opacity(0.85 * (1 - born))), lineWidth: 1.3)
            }
            if !still, born >= 1 {
                // A streak along its orbit, fading behind it.
                for step in 0..<8 {
                    var segment = Path()
                    segment.move(to: moonPoint(orbit, angle - 0.1 * Double(step), scale: scale))
                    segment.addLine(to: moonPoint(orbit, angle - 0.1 * Double(step + 1), scale: scale))
                    canvas.stroke(
                        segment, with: .color(colour.opacity(0.5 * opacity * (1 - Double(step) / 8))),
                        style: StrokeStyle(lineWidth: 2 * size, lineCap: .butt)
                    )
                }
            }
            let halo = 18 * size
            canvas.fill(
                Self.circle(point, halo),
                with: .radialGradient(Gradient(colors: [colour.opacity(0.42 * opacity), colour.opacity(0)]), center: point, startRadius: 0, endRadius: halo)
            )
            // A small world, lit on the side that faces the star.
            let body = 5.4 * size
            let toStar = CGPoint(x: centre.x - point.x, y: centre.y - point.y)
            let distance = max(0.001, hypot(toStar.x, toStar.y))
            let light = CGPoint(x: point.x + toStar.x / distance * body * 0.45, y: point.y + toStar.y / distance * body * 0.45)
            canvas.fill(
                Self.circle(point, body),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(opacity), colour.mix(with: .white, by: 0.25).opacity(opacity), colour.mix(with: .black, by: 0.45).opacity(opacity),
                    ]),
                    center: light, startRadius: 0, endRadius: body * 1.5
                )
            )
        }
    }

    // MARK: - The sky

    /// Where the sky is drawn: outside the ring (with a margin) and above the words under the scene, so nothing crosses the galaxy or the text.
    private func skyRegion(_ size: CGSize) -> Path {
        var region = Path(CGRect(x: 0, y: 0, width: size.width, height: centre.y + radius * Self.ringShare + Self.wordsGap - 6))
        let ring = radius * Self.ringShare + 10
        region.addEllipse(in: CGRect(x: centre.x - ring, y: centre.y - ring, width: ring * 2, height: ring * 2))
        return region
    }

    /// The space outside the ring: a field of faint stars turning slowly, shooting stars, meteor showers, comets passing, and a long chapter's
    /// comet low over the galaxy. It fades as the finish begins.
    private func drawSky(in canvas: inout GraphicsContext, size: CGSize, _ moment: UltraSceneMoment) {
        var sky = canvas
        sky.clip(to: skyRegion(size), style: FillStyle(eoFill: true))
        sky.opacity = 1 - moment.fall
        drawField(in: &sky, size: size, moment)
        guard !still else { return }
        let starts = UltraWaitTimeline.shootingStars(since: began, until: moment.time)
        for (number, start) in starts.enumerated().reversed() {
            let progress = (moment.time - start) / UltraWaitTimeline.shootingStarFlight
            guard progress < 1 else { break }
            drawShootingStar(in: &sky, size: size, seed: Double(number), progress: progress)
        }
        let showers = UltraWaitTimeline.showers(since: began, until: moment.time)
        for (number, start) in showers.enumerated().reversed() {
            let since = moment.time - start
            guard since < UltraWaitTimeline.showerFlight else { break }
            drawShower(in: &sky, size: size, seed: Double(number), since: since)
        }
        let comets = UltraWaitTimeline.passingComets(since: began, until: moment.time)
        for (number, start) in comets.enumerated().reversed() {
            let progress = (moment.time - start) / UltraWaitTimeline.passingCometFlight
            guard progress < 1 else { break }
            drawPassingComet(in: &sky, size: size, number: number, progress: progress)
        }
        for start in moment.comets {
            drawComet(in: &sky, size: size, start: start, progress: (moment.time - start) / UltraWaitTimeline.cometFlight)
        }
    }

    private static let fieldCount = 70

    /// Faint stars all round the scene, turning slowly about the star as the night sky does, twinkling; a few brighter ones glint.
    private func drawField(in sky: inout GraphicsContext, size: CGSize, _ moment: UltraSceneMoment) {
        let unit = UltraWaitTimeline.unit
        let reach = hypot(max(centre.x, size.width - centre.x), max(centre.y, size.height - centre.y))
        let inner = radius * Self.ringShare + 14
        let turn = still ? 0 : 0.012 * (moment.time - began)
        let shown = still ? 1 : min(1, max(0, (moment.time - began) / 1.5))
        for index in 0..<Self.fieldCount {
            let seed = Double(index) + 100
            let distance = inner + (reach - inner) * sqrt(unit(seed * 1.9))
            let angle = 2 * .pi * unit(seed * 2.3) + turn
            let point = CGPoint(x: centre.x + distance * cos(angle), y: centre.y + distance * sin(angle))
            let twinkle = still ? 1 : 0.55 + 0.45 * sin(moment.time * (0.5 + 1.5 * unit(seed * 3.1)) + seed)
            let opacity = (0.35 + 0.5 * unit(seed * 5.7)) * twinkle * shown
            let colour = index % 6 == 0 ? Palette.World.skyStarYou : (index % 3 == 0 ? Palette.Scripts.ultraDust[1] : Color.white)
            let dot = 0.55 + 0.8 * unit(seed * 4.4)
            if unit(seed * 6.3) > 0.88 {
                sky.fill(SparkShape.path(center: point, radius: dot * 3.4, waist: 0.18), with: .color(colour.opacity(0.55 * opacity)))
            }
            sky.fill(Self.circle(point, dot), with: .color(colour.opacity(opacity)))
        }
    }

    /// A meteor: a bright head `travel` points along `direction` from `start`, its tail fading behind it, at `progress` 0…1 of its flight.
    private func drawMeteor(
        in sky: inout GraphicsContext, from start: CGPoint, direction: CGPoint, travel: CGFloat, length: CGFloat, progress: Double, colour: Color
    ) {
        let along = travel * (1 - pow(1 - progress, 1.6))
        let head = CGPoint(x: start.x + direction.x * along, y: start.y + direction.y * along)
        let tailLength = length * min(1, progress / 0.2)
        let tail = CGPoint(x: head.x - direction.x * tailLength, y: head.y - direction.y * tailLength)
        let opacity = progress < 0.12 ? progress / 0.12 : pow(1 - (progress - 0.12) / 0.88, 1.3)
        var streak = Path()
        streak.move(to: tail)
        streak.addLine(to: head)
        sky.stroke(
            streak, with: .linearGradient(Gradient(colors: [colour.opacity(0), colour.opacity(0.85 * opacity)]), startPoint: tail, endPoint: head),
            style: StrokeStyle(lineWidth: 1.3, lineCap: .round)
        )
        sky.fill(
            Self.circle(head, 4),
            with: .radialGradient(Gradient(colors: [colour.opacity(0.45 * opacity), .clear]), center: head, startRadius: 0, endRadius: 4)
        )
        sky.fill(Self.circle(head, 1.3), with: .color(.white.opacity(opacity)))
    }

    /// A shooting star: one meteor down across the sky, from a place and at a slope of its own.
    private func drawShootingStar(in sky: inout GraphicsContext, size: CGSize, seed: Double, progress: Double) {
        let unit = UltraWaitTimeline.unit
        let rightward = unit(seed * 3.3) > 0.5
        let top = size.height * 0.06
        let bottom = max(top + 20, centre.y)
        let start = CGPoint(
            x: size.width * (rightward ? 0.02 + 0.4 * unit(seed * 2.2) : 0.98 - 0.4 * unit(seed * 2.2)),
            y: top + unit(seed * 5.1) * (bottom - top) * 0.6
        )
        let slope = 0.3 + 0.25 * unit(seed * 6.7)
        let direction = CGPoint(x: (rightward ? 1 : -1) * cos(slope), y: sin(slope))
        drawMeteor(in: &sky, from: start, direction: direction, travel: size.width * 0.42, length: 70, progress: progress, colour: .white)
    }

    /// A meteor shower: five meteors one after the other, in parallel from the same corner of the sky, white and lilac.
    private func drawShower(in sky: inout GraphicsContext, size: CGSize, seed: Double, since: TimeInterval) {
        let unit = UltraWaitTimeline.unit
        let rightward = unit(seed * 3.7) > 0.5
        let slope = 0.45 + 0.15 * unit(seed * 1.3)
        let direction = CGPoint(x: (rightward ? 1 : -1) * cos(slope), y: sin(slope))
        let top = size.height * 0.04
        for meteor in 0..<5 {
            let key = seed * 7 + Double(meteor)
            let delay = 0.22 * Double(meteor) + 0.1 * unit(key * 2.1)
            let flight = 0.75 + 0.25 * unit(key * 3.3)
            let progress = (since - delay) / flight
            guard progress > 0, progress < 1 else { continue }
            let across = size.width * (0.1 + 0.8 * unit(key * 4.7))
            let start = CGPoint(x: rightward ? across * 0.6 : size.width - across * 0.6, y: top + unit(key * 5.9) * (centre.y - top) * 0.55)
            let colour = meteor.isMultiple(of: 2) ? Color.white : Palette.Scripts.ultraDust[1]
            drawMeteor(
                in: &sky, from: start, direction: direction, travel: size.width * (0.3 + 0.12 * unit(key * 6.1)),
                length: 45 + 45 * unit(key * 7.3), progress: progress, colour: colour
            )
        }
    }

    /// A comet passing high outside the ring, gold, lilac or icy blue in turn: a glowing head, a curved dust tail behind it and a fine,
    /// straight ion tail pointing away from the star, as a comet's points away from its sun.
    private func drawPassingComet(in sky: inout GraphicsContext, size: CGSize, number: Int, progress: Double) {
        let unit = UltraWaitTimeline.unit
        let seed = Double(number)
        let colour = Palette.Scripts.ultraComets[number % Palette.Scripts.ultraComets.count]
        let rightward = unit(seed * 5.9) > 0.5
        let top = size.height * 0.06
        let low = max(top + 30, centre.y - radius * Self.ringShare - 40)
        let height = top + unit(seed * 6.1) * (low - top) * 0.8
        func place(_ along: Double) -> CGPoint {
            let eased = min(1, max(0, along))
            let x = -80 + (size.width + 160) * eased
            return CGPoint(x: rightward ? x : size.width - x, y: height + 40 * eased + 16 * sin(.pi * eased))
        }
        let head = place(progress)
        let opacity = min(1, progress / 0.08, (1 - progress) / 0.08)
        var tail = Path()
        tail.move(to: head)
        for step in 1...8 { tail.addLine(to: place(progress - 0.03 * Double(step))) }
        let end = place(progress - 0.24)
        for (width, strength) in [(7.0, 0.16), (1.6, 0.7)] {
            sky.stroke(
                tail, with: .linearGradient(Gradient(colors: [colour.opacity(strength * opacity), colour.opacity(0)]), startPoint: head, endPoint: end),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )
        }
        let away = CGPoint(x: head.x - centre.x, y: head.y - centre.y)
        let distance = max(1, hypot(away.x, away.y))
        let ionEnd = CGPoint(x: head.x + away.x / distance * 64, y: head.y + away.y / distance * 64)
        var ion = Path()
        ion.move(to: head)
        ion.addLine(to: ionEnd)
        sky.stroke(
            ion, with: .linearGradient(
                Gradient(colors: [Palette.Scripts.ultraComets[2].opacity(0.35 * opacity), .clear]), startPoint: head, endPoint: ionEnd
            ),
            lineWidth: 0.8
        )
        let glow = Gradient(colors: [.white.opacity(opacity), colour.opacity(0.5 * opacity), .clear])
        sky.fill(Self.circle(head, 10), with: .radialGradient(glow, center: head, startRadius: 0, endRadius: 10))
    }

    /// A long chapter's comet: a gold head and a long tail crossing the whole screen low over the galaxy, dipping as it passes.
    private func drawComet(in canvas: inout GraphicsContext, size: CGSize, start: TimeInterval, progress: Double) {
        let rightward = UltraWaitTimeline.unit(start) > 0.5
        let gold = Palette.World.skyStarYou
        func place(_ along: Double) -> CGPoint {
            let eased = Self.ease(min(1, max(0, along)))
            let x = -60 + (size.width + 120) * eased
            return CGPoint(x: rightward ? x : size.width - x, y: centre.y - radius * 0.98 + 22 * sin(.pi * eased))
        }
        let head = place(progress)
        var tail = Path()
        tail.move(to: head)
        for step in 1...6 { tail.addLine(to: place(progress - 0.035 * Double(step))) }
        let end = place(progress - 0.21)
        let opacity = min(1, progress / 0.1, (1 - progress) / 0.1)
        for (width, strength) in [(6.0, 0.2), (1.8, 0.75)] {
            canvas.stroke(
                tail, with: .linearGradient(Gradient(colors: [gold.opacity(strength * opacity), gold.opacity(0)]), startPoint: head, endPoint: end),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )
        }
        canvas.fill(
            Self.circle(head, 9),
            with: .radialGradient(Gradient(colors: [.white.opacity(opacity), gold.opacity(0.5 * opacity), .clear]), center: head, startRadius: 0, endRadius: 9)
        )
    }

    // MARK: - The finish

    /// The flash as everything has fallen into the star, and a wave of gold light running out along the galaxy's plane.
    private func drawWave(in canvas: inout GraphicsContext, _ moment: UltraSceneMoment) {
        guard !still, let wave = moment.wave else { return }
        let grow = 1 - pow(1 - wave, 2.2)
        let flash = radius * (0.35 + 0.5 * grow)
        canvas.fill(
            Self.circle(centre, flash),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.9 * pow(1 - wave, 1.5)), Palette.Scripts.ultraStarGlow.opacity(0.4 * (1 - wave)), .clear]),
                center: centre, startRadius: 0, endRadius: flash
            )
        )
        let reach = radius * (0.15 + 1.75 * grow)
        var ring = Path()
        for step in 0...72 {
            let point = plane(reach, 2 * .pi * Double(step) / 72)
            if step == 0 { ring.move(to: point) } else { ring.addLine(to: point) }
        }
        canvas.stroke(ring, with: .color(Palette.World.skyStarYou.opacity(0.75 * (1 - wave))), lineWidth: 0.6 + 2.6 * (1 - wave))
    }

    // MARK: - Helpers

    private static func circle(_ centre: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    }

    /// Ease in and out, 0…1.
    private static func ease(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    /// 0 below `low`, 1 above `high`, eased between.
    private static func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
        ease(min(1, max(0, (value - low) / (high - low))))
    }

    /// An angle brought into −π…π.
    private static func wrapped(_ angle: Double) -> Double {
        let turned = (angle + .pi).truncatingRemainder(dividingBy: 2 * .pi)
        return (turned < 0 ? turned + 2 * .pi : turned) - .pi
    }
}
