//
//  UniverseMap.swift
//  Cue Studio
//

import SwiftUI

/// The creator's universe in one picture (v30 · 9.2), drawn on a 358 × 320 grid and scaled to fit, seen from above at a slant: "YOU" is a lit gold
/// sphere lifted over the middle of the disc (`UniverseSphere`), a violet haze under it, two elliptical orbits (70 × 43 and a dashed 122 × 80,
/// radii), one round dot for every video shared, coloured by its topic, on the disc that turns around the sphere once in 140 s (the far half dimmer
/// and smaller, the near half brighter), the platforms as planets at the edges (their size grows with the videos, `PlanetSize`) joined to the sphere
/// by dashed curves, and the newest video as a yellow star that pulses (2.6 s). Refined for depth (the owner, 04/11/2026): the dots grow and brighten
/// as they come round to the front and fade and shrink behind, the disc is a faint plane whose near edge catches the light, the routes arc up out of
/// the plane from YOU's edge to each planet, the planets are lit by YOU (a day side, a night side, a line of air, a surface that turns), "YOU" sits
/// on a small plate under the sphere and the newest star sends out a ring and says which network it went to. On Your universe the whole map answers
/// the iPhone's tilt, each layer by its depth (`UniverseParallax`, `UniverseTilt`). On top of the board (the owner's pass, the Pro planet's
/// language): on Your universe the map builds itself as it opens (`UniverseOpening`), and YOU is a real body (soft bands, storms turning slowly with
/// it, the limb, a line of air); the dots are crisp, with no halo (the owner's call: clean and sharp, few motions). Everything stops with Reduce
/// Motion. A sealed year (`isSealed`) is dimmer and still. Planets, dots and the core are buttons when `onOpen…` is given.
struct UniverseMap: View {
    let snapshot: UniverseSnapshot
    var animates = true
    /// The core's colour (Settings › Personalize).
    var coreColor: CoreColor = .gold
    /// A year that is over: saturation .75, brightness .92, nothing moves.
    var isSealed = false
    /// The year before, very faint behind this one.
    var ghost: UniverseSnapshot?
    /// "Your universe starts with your first share.": said on the map while it is empty.
    var caption: String?
    /// How many videos each planet had when the screen was last seen: the planets grow from there (0.6 s spring).
    var previousCounts: [Platform: Int] = [:]
    /// A picture for the video of "Share my universe": the map at this second, building up over `buildDuration`; nil is the live map.
    var frozenTime: TimeInterval?
    var buildDuration: TimeInterval = 4.5
    /// Seconds before the planets start to grow (the send-off waits for the comets).
    var growthDelay: TimeInterval = 0
    /// Taps: the core, a planet (with its popover) and a video's dot. Nil makes the map just a picture.
    var onCore: (() -> Void)?
    var onSeeInTakes: ((Platform) -> Void)?
    var onDot: ((UUID) -> Void)?
    /// "TIKTOK · 12" or just "TIKTOK" (a card shared without the numbers).
    var showsCounts = true
    /// The newest video's dash; the send-off lights it itself.
    var showsNewest = true
    /// The map builds itself as it appears (`UniverseOpening`): Your universe, not its pictures.
    var playsOpening = false
    /// The map answers the iPhone's tilt (`UniverseParallax`): Your universe, not its pictures.
    var respondsToTilt = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.playsUniverseOpening) private var openingAllowed
    @State private var appearedAt = Date.now
    @State private var openPlanet: Platform?
    @State private var tilt = UniverseTilt()

    /// The planets grow in 0.6 s with `cubic-bezier(.3, 1.4, .5, 1)`.
    private static let growth = UnitCurve.css(0.3, 1.4, 0.5, 1)
    private static let growthDuration = 0.6

    /// The board's size and its centre.
    static let board = CGSize(width: 358, height: 320)
    static let center = CGPoint(x: 179, y: 165)

    /// Where each platform's planet sits on the board and which way its label reads.
    struct Node {
        let point: CGPoint
        let labelAnchor: UnitPoint
    }

    static func node(_ platform: Platform) -> Node {
        switch platform {
        case .tiktok: Node(point: CGPoint(x: 326, y: 26), labelAnchor: .trailing)
        case .reels: Node(point: CGPoint(x: 24, y: 300), labelAnchor: .leading)
        case .shorts: Node(point: CGPoint(x: 334, y: 300), labelAnchor: .trailing)
        case .youtube: Node(point: CGPoint(x: 32, y: 26), labelAnchor: .leading)
        case .linkedin: Node(point: CGPoint(x: 179, y: 14), labelAnchor: .leading)
        case .stories: Node(point: CGPoint(x: 179, y: 312), labelAnchor: .leading)
        }
    }

    /// The newest video's star, on the right of the outer orbit.
    static let newestPoint = CGPoint(x: 301, y: 161)

    /// The disc is seen at a slant: the orbits are 70 × 43 and 122 × 80 (radii), the sphere floats 26 pt over its middle, and the disc of videos turns
    /// once in 140 s.
    static let innerOrbit = CGSize(width: 70, height: 43)
    static let outerOrbit = CGSize(width: 122, height: 80)
    static let coreLift: CGFloat = 26
    static let spinPeriod = 140.0

    /// The sphere's centre on the board.
    static var corePoint: CGPoint { CGPoint(x: center.x, y: center.y - coreLift) }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / Self.board.width, proxy.size.height / Self.board.height)
            let origin = CGPoint(
                x: (proxy.size.width - Self.board.width * scale) / 2, y: (proxy.size.height - Self.board.height * scale) / 2
            )
            let still = isStill
            ZStack {
                TimelineView(.animation(minimumInterval: tilts ? 1.0 / 60 : 1.0 / 30, paused: still && frozenTime == nil && !isGrowing)) { context in
                    Canvas { canvas, _ in
                        var layer = canvas
                        layer.translateBy(x: origin.x, y: origin.y)
                        layer.scaleBy(x: scale, y: scale)
                        let time = frozenTime ?? (still ? 0 : context.date.timeIntervalSinceReferenceDate)
                        draw(in: &layer, time: time, now: context.date, parallax: tilts ? UniverseParallax(tilt: tilt.tilt) : .still)
                    }
                }
                if onDot != nil { dotTaps(scale: scale, origin: origin) }
                if let caption { captionText(caption, scale: scale, origin: origin) }
                if onCore != nil || onSeeInTakes != nil || onDot != nil {
                    taps(scale: scale, origin: origin, center: CGPoint(x: origin.x + Self.corePoint.x * scale, y: origin.y + Self.corePoint.y * scale))
                }
                popover(scale: scale, origin: origin, size: proxy.size)
            }
        }
        .aspectRatio(Self.board.width / Self.board.height, contentMode: .fit)
        .saturation(isSealed ? 0.75 : 1)
        .brightness(isSealed ? -0.08 : 0)
        .accessibilityElement(children: onCore == nil && onSeeInTakes == nil ? .ignore : .contain)
        .accessibilityLabel(Text("Your universe"))
        .accessibilityValue(Text("\(snapshot.total) videos shared"))
        .task { await openingHaptics() }
        .onAppear { if tilts { tilt.start() } }
        .onDisappear { tilt.stop() }
    }

    /// The map follows the tilt only where it moves at all.
    private var tilts: Bool { respondsToTilt && !isStill }

    // MARK: - The opening

    private var opens: Bool { playsOpening && openingAllowed && !isStill }

    /// Seconds into the opening; past its end when there is none.
    private func openingAge(now: Date) -> Double { opens ? now.timeIntervalSince(appearedAt) : UniverseOpening.duration + 1 }

    private func openingHaptics() async {
        guard opens, snapshot.total > 0 else { return }
        for beat in UniverseOpening.beats(planets: snapshot.platforms.count) {
            let wait = beat.second - Date.now.timeIntervalSince(appearedAt)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if Task.isCancelled { return }
            if beat.isPlanet { Haptics.light() } else { Haptics.soft() }
        }
    }

    /// The line under YOU while nothing is shared: lower and narrower (two lines) when last year's ghost is behind it.
    private func captionText(_ text: String, scale: CGFloat, origin: CGPoint) -> some View {
        let hasGhost = ghost != nil
        return Text(text)
            .font(.fixed(16, weight: .medium))
            .foregroundStyle(Palette.inkSoft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: (hasGhost ? 220 : 330) * scale)
            .position(x: origin.x + Self.center.x * scale, y: origin.y + (Self.center.y + (hasGhost ? 121 : 74)) * scale)
            .accessibilityIdentifier("universe.caption")
    }

    // MARK: - Taps

    /// Buttons over the picture: the core (its sheet) and each planet (its popover).
    @ViewBuilder
    private func taps(scale: CGFloat, origin: CGPoint, center: CGPoint) -> some View {
        if let onCore {
            Button(action: onCore) { Color.clear.frame(width: 84, height: 84).contentShape(Circle()) }
                .position(center)
                .accessibilityLabel(Text("Your core"))
                .accessibilityValue(Text("\(snapshot.total) videos shared"))
                .accessibilityIdentifier("universe.core")
        }
        if onSeeInTakes != nil {
            ForEach(snapshot.platforms, id: \.platform) { item in
                let node = Self.node(item.platform)
                Button {
                    Haptics.apply()
                    withAnimation(.easeOut(duration: 0.3)) { openPlanet = openPlanet == item.platform ? nil : item.platform }
                } label: {
                    Color.clear.frame(width: 48, height: 48).contentShape(Circle())
                }
                    .position(x: origin.x + node.point.x * scale, y: origin.y + node.point.y * scale)
                    .accessibilityLabel(Text("\(item.platform.label), \(item.count) videos in \(String(snapshot.year))"))
                    .accessibilityIdentifier("universe.planet.\(item.platform.rawValue)")
            }
        }
    }

    /// A tap on a video's dot opens that take. The dots are turning, so the tap looks for the nearest one where it is now; VoiceOver reaches the takes
    /// from Takes.
    private func dotTaps(scale: CGFloat, origin: CGPoint) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { tap in
                let board = CGPoint(x: (tap.location.x - origin.x) / scale, y: (tap.location.y - origin.y) / scale)
                let spin = isStill ? 0 : Date.now.timeIntervalSinceReferenceDate * 2 * .pi / Self.spinPeriod
                let hit = snapshot.dots.filter(\.hasTake).min { distance($0, to: board, spin: spin) < distance($1, to: board, spin: spin) }
                if let hit, distance(hit, to: board, spin: spin) < 16 { onDot?(hit.videoID) }
            })
            .accessibilityHidden(true)
    }

    private func distance(_ dot: UniverseSnapshot.Dot, to point: CGPoint, spin: Double) -> CGFloat {
        let at = Self.videoSpot(topic: dot.topicIndex, dot: dot.slot, drawn: dot.slot).point(spin: spin)
        return hypot(Self.center.x + at.x - point.x, Self.center.y + at.y - point.y)
    }

    // MARK: - Popover

    /// A planet's card (9.2, 218 pt wide): under the planet and lined up with its right edge, over a layer that closes it with a tap. The system's popover
    /// has an arrow and its own sizes; the board's card has neither, so this one is Cue's.
    @ViewBuilder
    private func popover(scale: CGFloat, origin: CGPoint, size: CGSize) -> some View {
        if let platform = openPlanet, let item = snapshot.platforms.first(where: { $0.platform == platform }), let onSeeInTakes {
            let node = Self.node(platform)
            let point = CGPoint(x: origin.x + node.point.x * scale, y: origin.y + node.point.y * scale)
            let width: CGFloat = 218
            let x = min(max(point.x + 36 - width / 2, width / 2 + 4), size.width - width / 2 - 4)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { openPlanet = nil } }
                .frame(width: size.width + 80, height: size.height + 400)
                .position(x: size.width / 2, y: size.height / 2 + 100)
                .accessibilityHidden(true)
            PlanetPopover(platform: platform, count: item.count, year: snapshot.year, isLive: !isSealed) {
                openPlanet = nil
                onSeeInTakes(platform)
            }
            .frame(width: width)
            .position(x: x, y: point.y + 22 + 54)
            .transition(.scale(scale: 0.94, anchor: .top).combined(with: .opacity))
        }
    }

    // MARK: - Growth

    private var isGrowing: Bool { !previousCounts.isEmpty && Date.now.timeIntervalSince(appearedAt) < delay + Self.growthDuration + 0.1 }

    /// The planets grow once they are born, when the map builds itself.
    private var delay: TimeInterval { opens ? max(growthDelay, UniverseOpening.duration) : growthDelay }

    /// 0 → 1 (past 1 with the spring) since the screen opened; 1 when nothing is growing.
    private func growthProgress(now: Date) -> Double {
        guard !previousCounts.isEmpty, !reduceMotion, animates, !isSealed, frozenTime == nil else { return 1 }
        let t = min(1, max(0, (now.timeIntervalSince(appearedAt) - delay) / Self.growthDuration))
        return Self.growth.value(at: t)
    }

    private var isStill: Bool { reduceMotion || !animates || isSealed || frozenTime != nil }

    /// How many of the dots (and when the planets and the newest star) have appeared: 1 for the live map, 0 → 1 while a video builds it.
    private var build: Double { frozenTime.map { min(1, max(0, $0 / buildDuration)) } ?? 1 }

    // MARK: - Drawing (board coordinates)

    private func draw(in canvas: inout GraphicsContext, time: TimeInterval, now: Date, parallax: UniverseParallax) {
        let disc = parallax.moved(Self.center, .disc)
        let core = parallax.moved(Self.corePoint, .core)
        let spin = frozenTime == nil ? time * 2 * .pi / Self.spinPeriod : 0
        let hasVideos = snapshot.total > 0
        let age = openingAge(now: now)
        let space = Space(disc: disc, core: core, parallax: parallax)
        drawHaze(in: &canvas, at: parallax.moved(Self.center, .haze), flatten: parallax.flatten)
        drawPlane(in: &canvas, space: space, opacity: hasVideos ? 1 : 0.6)
        drawOrbits(in: &canvas, space: space, opacity: !hasVideos && ghost == nil ? 0.55 : 1, age: age)
        if let ghost {
            // Last year, very faint behind this one: its routes and planets, with no labels and no dots (they clouded the disc).
            for item in ghost.platforms { drawRoute(to: item.platform, space: space, opacity: 0.35, in: &canvas) }
            for item in ghost.platforms {
                drawPlanet(item, previous: item.count, progress: 1, opacity: 0.2, labeled: false, space: space, in: &canvas)
            }
        }
        let visible = Int((Double(snapshot.dots.count) * min(1, build / 0.8)).rounded(.up))
        let motion = DotMotion(spin: spin, age: age)
        if hasVideos {
            for (index, item) in snapshot.platforms.enumerated() where build >= 0.15 {
                drawRoute(to: item.platform, space: space, opacity: 1, drawn: UniverseOpening.routeLight(index: index, at: age), in: &canvas)
            }
            drawVideos(of: snapshot, visible: visible, motion: motion, front: false, space: space, in: &canvas)
        } else if ghost == nil {
            // Nothing shared yet: the routes to where the first star will go, very faint.
            for platform in [Platform.tiktok, .reels, .shorts] { drawRoute(to: platform, space: space, opacity: 0.45, in: &canvas) }
        }
        drawCore(in: &canvas, at: core, time: time, age: age)
        if hasVideos { drawVideos(of: snapshot, visible: visible, motion: motion, front: true, space: space, in: &canvas) }
        drawYou(in: &canvas, under: core, age: age)
        guard hasVideos else { return }
        for (index, item) in snapshot.platforms.enumerated() where age < UniverseOpening.duration {
            drawRouteLight(to: item.platform, progress: UniverseOpening.routeLight(index: index, at: age), at: age, space: space, in: &canvas)
        }
        let progress = growthProgress(now: now)
        for (index, item) in snapshot.platforms.enumerated() where build >= 0.2 + 0.1 * Double(index) {
            let previous = previousCounts[item.platform] ?? item.count
            let birth = UniverseOpening.planet(index: index, at: age)
            guard birth.scale > 0.001 else { continue }
            let look = PlanetLook(scale: birth.scale, white: birth.white, time: isStill ? nil : time)
            drawPlanet(item, previous: previous, progress: progress, opacity: 1, labeled: true, look: look, space: space, in: &canvas)
            let sparks = UniverseOpening.planetSparks(index: index, at: age)
            drawPlanetSparks(at: space.planet(item.platform), tint: item.platform.tint, sparks: sparks, in: &canvas)
        }
        if showsNewest, build >= 0.95 { drawNewest(in: &canvas, time: time, age: age, space: space) }
    }

    /// Where things are at this moment of the tilt: the disc's middle, YOU, how open the disc is, and each planet.
    private struct Space {
        var disc: CGPoint
        var core: CGPoint
        var parallax: UniverseParallax

        func planet(_ platform: Platform) -> CGPoint { parallax.moved(UniverseMap.node(platform).point, .planet) }

        /// A point of the disc given as its offset from the disc's middle at rest.
        func onDisc(_ offset: CGPoint) -> CGPoint { CGPoint(x: disc.x + offset.x, y: disc.y + offset.y * parallax.flatten) }
    }

    /// YOU: its glow, its rings and the ball, born white-hot in a bloom on the opening and cooling to its colour; a rim of light and a glint on the
    /// live map.
    private func drawCore(in canvas: inout GraphicsContext, at core: CGPoint, time: TimeInterval, age: Double) {
        let bloom = UniverseOpening.bloom.pose(at: age)
        if bloom.opacity > 0.01 {
            let reach = 90 * bloom.scale
            canvas.fill(
                LightFX.disc(core, reach),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(bloom.opacity), Palette.acc.opacity(0.4 * bloom.opacity), Palette.acc.opacity(0)]),
                    center: core, startRadius: 0, endRadius: reach
                )
            )
        }
        let birth = UniverseOpening.core.pose(at: age)
        guard birth.opacity > 0.01 else { return }
        var layer = canvas
        layer.opacity = birth.opacity
        layer.translateBy(x: core.x, y: core.y)
        layer.scaleBy(x: birth.scale, y: birth.scale)
        layer.translateBy(x: -core.x, y: -core.y)
        let swell = UniverseSphere.swell(at: time)
        UniverseSphere.drawGlow(&layer, at: core, color: coreColor, swell: swell)
        UniverseSphere.drawBack(&layer, at: core, time: time)
        UniverseSphere.drawBall(&layer, at: core, color: coreColor, swell: swell)
        UniverseSphere.drawSurface(&layer, at: core, color: coreColor, swell: swell, time: isStill ? nil : time)
        let white = UniverseOpening.coreWhite.pose(at: age).opacity
        if white > 0.01 {
            let radius = UniverseSphere.diameter / 2
            layer.drawLayer { hot in
                hot.addFilter(.shadow(color: .white.opacity(white), radius: 14))
                hot.fill(LightFX.disc(core, radius), with: .color(.white.opacity(white)))
            }
        }
        UniverseSphere.drawFront(&layer, at: core, time: time)
    }

    /// The haze under the sphere: violet, on the disc (wider than tall), and gone at the edge of the outer orbit.
    private func drawHaze(in canvas: inout GraphicsContext, at center: CGPoint, flatten: CGFloat) {
        var layer = canvas
        layer.translateBy(x: center.x, y: center.y)
        layer.scaleBy(x: 1, y: Self.outerOrbit.height / Self.outerOrbit.width * flatten)
        layer.fill(
            LightFX.disc(.zero, 112),
            with: .radialGradient(
                Gradient(colors: [
                    Palette.Universe.nightViolet.opacity(0.34), Palette.Universe.nightViolet.opacity(0.12), Palette.Universe.nightViolet.opacity(0),
                ]),
                center: .zero, startRadius: 0, endRadius: 112
            )
        )
    }

    /// The disc as a faint plane a little wider than the outer orbit: clear at its far edge, a breath of violet toward the viewer, and its near rim
    /// catching the light, so the dots read as lying on something seen at a slant.
    private func drawPlane(in canvas: inout GraphicsContext, space: Space, opacity: Double) {
        let rx = Self.outerOrbit.width * 1.22
        let ry = Self.outerOrbit.height * 1.22 * space.parallax.flatten
        let plane = Path(ellipseIn: CGRect(x: space.disc.x - rx, y: space.disc.y - ry, width: rx * 2, height: ry * 2))
        canvas.fill(plane, with: .linearGradient(
            Gradient(colors: [Palette.Universe.nightViolet.opacity(0), Palette.Universe.nightViolet.opacity(0.13 * opacity)]),
            startPoint: CGPoint(x: space.disc.x, y: space.disc.y - ry), endPoint: CGPoint(x: space.disc.x, y: space.disc.y + ry)
        ))
        canvas.stroke(plane, with: .linearGradient(
            Gradient(colors: [Palette.Universe.starLilac.opacity(0), Palette.Universe.starLilac.opacity(0.16 * opacity)]),
            startPoint: CGPoint(x: space.disc.x, y: space.disc.y), endPoint: CGPoint(x: space.disc.x, y: space.disc.y + ry)
        ), lineWidth: 0.8)
    }

    /// Two elliptical orbits: 70 × 43 (solid) and 122 × 80 (dashed 2·4), each fainter at its far side and brighter toward the viewer; `opacity`
    /// dims them (a new account: 55%). On the opening they draw round YOU, the inner one first.
    private func drawOrbits(in canvas: inout GraphicsContext, space: Space, opacity: Double, age: Double) {
        let c = space.disc
        let flatten = space.parallax.flatten
        func ellipse(_ size: CGSize) -> Path {
            Path(ellipseIn: CGRect(x: c.x - size.width, y: c.y - size.height * flatten, width: size.width * 2, height: size.height * 2 * flatten))
        }
        func shade(_ size: CGSize, _ strength: Double) -> GraphicsContext.Shading {
            .linearGradient(
                Gradient(colors: [
                    Palette.Universe.starLilac.opacity(strength * 0.45 * opacity), Palette.Universe.starLilac.opacity(strength * 1.35 * opacity),
                ]),
                startPoint: CGPoint(x: c.x, y: c.y - size.height * flatten), endPoint: CGPoint(x: c.x, y: c.y + size.height * flatten)
            )
        }
        let inner = UniverseOpening.innerOrbit.pose(at: age).scale
        let outer = UniverseOpening.outerOrbit.pose(at: age).scale
        canvas.stroke(ellipse(Self.innerOrbit).trimmedPath(from: 0, to: inner), with: shade(Self.innerOrbit, 0.22), lineWidth: 0.8)
        canvas.stroke(
            ellipse(Self.outerOrbit).trimmedPath(from: 0, to: outer), with: shade(Self.outerOrbit, 0.16), style: StrokeStyle(lineWidth: 0.8, dash: [2, 4])
        )
    }

    /// A route from YOU to a platform's planet: it leaves from the sphere's edge toward the planet, arcs up out of the plane of the disc and comes
    /// down onto the planet (a cubic), so it reads as a path through space and not a line across the dots.
    private static func route(to platform: Platform, space: Space) -> (start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) {
        let core = space.core
        let end = space.planet(platform)
        let length = max(1, hypot(end.x - core.x, end.y - core.y))
        let direction = CGVector(dx: (end.x - core.x) / length, dy: (end.y - core.y) / length)
        return (
            CGPoint(x: core.x + direction.dx * 23, y: core.y + direction.dy * 23),
            CGPoint(x: core.x + direction.dx * 62, y: core.y + direction.dy * 62 - 40),
            CGPoint(x: end.x - direction.dx * 48, y: end.y - direction.dy * 48 - 22),
            end
        )
    }

    /// The route as a dashed (2·4) line in the platform's colour at 35%, drawn as far as `drawn` (the opening's light draws it).
    private func drawRoute(to platform: Platform, space: Space, opacity: Double, drawn: Double = 1, in canvas: inout GraphicsContext) {
        guard drawn > 0.001 else { return }
        let curve = Self.route(to: platform, space: space)
        var route = Path()
        route.move(to: curve.start)
        route.addCurve(to: curve.end, control1: curve.control1, control2: curve.control2)
        canvas.stroke(
            route.trimmedPath(from: 0, to: drawn), with: .color(platform.tint.opacity(0.35 * opacity)), style: StrokeStyle(lineWidth: 1, dash: [2, 4])
        )
    }

    /// The point `t` (0...1) of the way along the route to a platform.
    private static func routePoint(to platform: Platform, at t: Double, space: Space) -> CGPoint {
        let curve = route(to: platform, space: space)
        let u = 1 - t
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return CGPoint(
            x: a * curve.start.x + b * curve.control1.x + c * curve.control2.x + d * curve.end.x,
            y: a * curve.start.y + b * curve.control1.y + c * curve.control2.y + d * curve.end.y
        )
    }

    /// On the opening, the light that runs out along a route to where its planet is born, with the first flight's trail.
    private func drawRouteLight(to platform: Platform, progress: Double, at age: Double, space: Space, in canvas: inout GraphicsContext) {
        guard progress > 0, progress < 1 else { return }
        let index = snapshot.platforms.firstIndex { $0.platform == platform } ?? 0
        let trail = StarRibbon.trail(at: age, length: 0.22) { second in
            let along = UniverseOpening.routeLight(index: index, at: second)
            return (Self.routePoint(to: platform, at: along, space: space), along > 0 && along < 1 ? 1 : 0)
        }
        StarRibbon.draw(trail, colors: [.white, platform.tint.mix(with: .white, by: 0.4), platform.tint], width: 3, in: &canvas)
        StarRibbon.head(at: Self.routePoint(to: platform, at: progress, space: space), opacity: 1, spin: age, radius: 2.4, halo: platform.tint, in: &canvas)
    }

    /// The sparks a planet's birth throws out.
    private func drawPlanetSparks(at center: CGPoint, tint: Color, sparks: (reach: Double, opacity: Double), in canvas: inout GraphicsContext) {
        guard sparks.opacity > 0.01 else { return }
        for index in 0..<10 {
            let angle = Double(index) / 10 * 2 * .pi + 0.4
            let reach = 8 + (14 + Double((index * 29) % 12)) * sparks.reach
            let point = CGPoint(x: center.x + cos(angle) * reach, y: center.y + sin(angle) * reach)
            let color = index.isMultiple(of: 2) ? Color.white : tint.mix(with: .white, by: 0.4)
            canvas.fill(LightFX.disc(point, 1.3 * (1 - 0.6 * sparks.reach) + 0.3), with: .color(color.opacity(sparks.opacity)))
        }
    }

    /// One round dot for each video (up to 40 drawn), in its topic's colour, on the disc that has turned `spin` radians. The far half (`front: false`) is
    /// smaller and dimmer than the near half.
    /// On the opening each dot flies out of YOU to its place and lands with a small ring (`age`).
    /// How the dots move: how far the disc has turned and the opening's second (nil: none).
    private struct DotMotion {
        var spin: Double
        var age: Double?
    }

    private func drawVideos(
        of snapshot: UniverseSnapshot, visible: Int, motion: DotMotion, front: Bool, space: Space, in canvas: inout GraphicsContext
    ) {
        let spin = motion.spin
        let age = motion.age
        let count = min(visible, snapshot.dots.count)
        for (index, dot) in snapshot.dots.prefix(visible).enumerated() {
            let spot = Self.videoSpot(topic: dot.topicIndex, dot: dot.slot, drawn: dot.slot)
            let nearness = sin(spot.angle + spin)
            if front != (nearness >= 0) { continue }
            let place = space.onDisc(spot.point(spin: spin))
            let flight = age.map { UniverseOpening.dotFlight(index: index, count: count, at: $0) } ?? 1
            guard flight > 0 else { continue }
            let core = space.core
            let point = CGPoint(x: core.x + (place.x - core.x) * flight, y: core.y + (place.y - core.y) * flight)
            // Depth: 0 at the far side of the disc, 1 nearest the viewer; bigger and brighter as it comes round.
            let depth = (nearness + 1) / 2
            let radius = spot.radius * CGFloat(0.72 + 0.5 * depth)
            let color = OnboardingTopic.color(at: dot.topicIndex)
            if let age, let ring = UniverseOpening.dotLanding(index: index, count: count, at: age) {
                canvas.stroke(LightFX.disc(point, radius + 7 * ring), with: .color(color.opacity(0.8 * (1 - ring))), lineWidth: 0.8)
            }
            canvas.fill(LightFX.disc(point, radius), with: .color(color.opacity(0.42 + 0.58 * depth)))
        }
    }

    /// Where a video sits: alternately near the inner and the outer orbit, spread by golden-ratio turns, a little off the line. The same every
    /// time, so the picture never shuffles.
    struct Spot {
        /// Where it is on its orbit when the disc is at rest (radians).
        let angle: Double
        let rx: Double
        let ry: Double
        let radius: CGFloat

        /// Its offset from the middle of the disc once the disc has turned `spin` radians.
        func point(spin: Double) -> CGPoint { CGPoint(x: rx * cos(angle + spin), y: ry * sin(angle + spin)) }
    }

    static func videoSpot(topic: Int, dot: Int, drawn: Int) -> Spot {
        let golden = 0.618_033_988_75
        let turn = (Double(drawn) * golden + Double(topic) * 0.21).truncatingRemainder(dividingBy: 1)
        let outer = drawn % 2 == 0
        let jitter = 0.78 + 0.34 * ((Double(drawn) * 0.754_877_666).truncatingRemainder(dividingBy: 1))
        let orbit = outer ? Self.outerOrbit : Self.innerOrbit
        let size = 1.9 + 1.0 * ((Double(drawn + dot) * 0.569_840_29).truncatingRemainder(dividingBy: 1))
        return Spot(angle: turn * 2 * .pi, rx: Double(orbit.width) * jitter, ry: Double(orbit.height) * jitter, radius: CGFloat(size))
    }

    /// A platform's planet and "TIKTOK · 12" beside it, 6 pt beyond the planet (beyond its ring), moving outward as it grows. A planet that just
    /// grew goes from its old size to the new one, and flashes when it wins a detail.
    /// How a planet looks at this moment besides its size: how far it is born (× its size) and how white it still is (the opening).
    private struct PlanetLook {
        var scale = 1.0
        var white = 0.0
        /// The second its surface has turned to (nil: still).
        var time: Double?
    }

    private func drawPlanet(
        _ item: (platform: Platform, count: Int), previous: Int, progress: Double, opacity: Double, labeled: Bool, look: PlanetLook = PlanetLook(),
        space: Space, in canvas: inout GraphicsContext
    ) {
        let platform = item.platform
        let count = item.count
        let birth = look
        let node = Self.node(platform)
        let point = space.planet(platform)
        let toCore = CGVector(dx: space.core.x - point.x, dy: space.core.y - point.y)
        let reach = max(1, hypot(toCore.dx, toCore.dy))
        let from = PlanetSize.diameter(videos: previous)
        let to = PlanetSize.diameter(videos: count)
        let diameter = max(0, from + (to - from) * CGFloat(progress)) * birth.scale
        let detail = PlanetSize.detail(videos: count)
        let gainedDetail = PlanetSize.detail(videos: previous) < detail
        let flash = gainedDetail ? max(0, 1 - abs(progress - 1) * 4) : 0
        PlanetPainter.draw(
            in: &canvas, center: point, diameter: diameter, detail: detail,
            look: PlanetPainter.Look(
                tint: platform.tint, opacity: opacity, flash: flash, white: birth.white,
                light: CGVector(dx: toCore.dx / reach, dy: toCore.dy / reach), time: birth.time
            )
        )
        guard labeled else { return }
        let distance = PlanetPainter.labelDistance(diameter: diameter, detail: detail)
        let side: CGFloat = node.labelAnchor == .trailing ? -1 : 1
        let name = showsCounts ? "\(platform.label.uppercased()) · \(count)" : platform.label.uppercased()
        let label = Text(name).font(.mono(size: 9.5, weight: .semibold, locale: canvas.environment.locale))
        var named = canvas
        named.opacity = min(1, birth.scale)
        named.draw(
            label.foregroundStyle(Palette.inkSoft), at: CGPoint(x: point.x + side * distance, y: point.y + 4), anchor: node.labelAnchor
        )
    }

    /// The newest video, on the right of the outer orbit: a small four-point yellow star in a soft halo that sends out a fine ring every 2.6 s,
    /// and under it, quietly, "NEW · REELS" (the network it went to); on the opening it ignites last.
    private func drawNewest(in canvas: inout GraphicsContext, time: TimeInterval, age: Double, space: Space) {
        guard let newest = snapshot.newest else { return }
        let ignite = UniverseOpening.newest.pose(at: age)
        guard ignite.opacity > 0.01 else { return }
        var layer = canvas
        layer.opacity = ignite.opacity
        let p = space.onDisc(CGPoint(x: Self.newestPoint.x - Self.center.x, y: Self.newestPoint.y - Self.center.y))
        let cycle = (time / 2.6).truncatingRemainder(dividingBy: 1)
        let ping = 4 + 14 * CGFloat(1 - pow(1 - cycle, 2))
        layer.stroke(LightFX.disc(p, ping * ignite.scale), with: .color(Palette.acc.opacity(0.55 * (1 - cycle))), lineWidth: 0.8)
        layer.fill(
            LightFX.disc(p, 9 * ignite.scale),
            with: .radialGradient(Gradient(colors: [Palette.acc.opacity(0.5), Palette.acc.opacity(0)]), center: p, startRadius: 0, endRadius: 9 * ignite.scale)
        )
        let breath = 0.5 - 0.5 * cos(time * 2 * .pi / 2.6)
        layer.fill(Self.sparkle(at: p, radius: (4.6 + 0.8 * breath) * ignite.scale), with: .color(Palette.acc))
        layer.fill(LightFX.disc(p, 1.2 * ignite.scale), with: .color(.white))
        // A year that is over has no "new": its last star stays, unnamed.
        guard !isSealed else { return }
        var name = String(localized: "NEW")
        if let platform = newest.platforms.first { name += " · \(platform.label.uppercased())" }
        let text = Text(name).font(.mono(size: 9, weight: .semibold, locale: canvas.environment.locale))
        let label = layer.resolve(text.foregroundStyle(Palette.inkSoft))
        let size = label.measure(in: CGSize(width: 200, height: 40))
        drawPlate(in: &layer, around: CGPoint(x: p.x, y: p.y + 17), size: size)
        layer.draw(label, at: CGPoint(x: p.x, y: p.y + 17), anchor: .center)
    }

    /// The small plate a label of the disc sits on ("YOU", "NEW · REELS"): the night, nearly opaque, with a fine gold edge, so it reads over
    /// any dot passing under it.
    private func drawPlate(in canvas: inout GraphicsContext, around centre: CGPoint, size: CGSize) {
        let plate = CGRect(x: centre.x - size.width / 2 - 7, y: centre.y - 7.5, width: size.width + 14, height: 15)
        canvas.fill(Path(roundedRect: plate, cornerRadius: 7.5), with: .color(Palette.Universe.youPlate))
        canvas.stroke(Path(roundedRect: plate, cornerRadius: 7.5), with: .color(Palette.Universe.starGold.opacity(0.28)), lineWidth: 0.6)
    }

    private static func sparkle(at centre: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let waist = radius * 0.24
        path.move(to: CGPoint(x: centre.x, y: centre.y - radius))
        path.addQuadCurve(to: CGPoint(x: centre.x + radius, y: centre.y), control: CGPoint(x: centre.x + waist, y: centre.y - waist))
        path.addQuadCurve(to: CGPoint(x: centre.x, y: centre.y + radius), control: CGPoint(x: centre.x + waist, y: centre.y + waist))
        path.addQuadCurve(to: CGPoint(x: centre.x - radius, y: centre.y), control: CGPoint(x: centre.x - waist, y: centre.y + waist))
        path.addQuadCurve(to: CGPoint(x: centre.x, y: centre.y - radius), control: CGPoint(x: centre.x - waist, y: centre.y - waist))
        path.closeSubpath()
        return path
    }

    /// "YOU" on a small plate just under the sphere, over the dots passing in front, so it never collides with an orbit or a dot; it comes in
    /// with the core on the opening.
    private func drawYou(in canvas: inout GraphicsContext, under core: CGPoint, age: Double) {
        let birth = UniverseOpening.core.pose(at: age)
        guard birth.opacity > 0.01 else { return }
        var layer = canvas
        layer.opacity = birth.opacity
        let centre = CGPoint(x: core.x, y: core.y + 31.5)
        let text = Text("YOU").font(.mono(size: 9, weight: .semibold, locale: canvas.environment.locale)).tracking(0.9)
        let label = layer.resolve(text.foregroundStyle(Palette.inkSoft))
        drawPlate(in: &layer, around: centre, size: CGSize(width: max(22, label.measure(in: CGSize(width: 100, height: 40)).width), height: 12))
        layer.draw(label, at: centre, anchor: .center)
    }
}
