//
//  UniverseCanvas.swift
//  Cue Studio
//

import SwiftUI

/// The creator's universe in one picture (v30 · 9.2), drawn on a 358 × 320 grid and scaled to fit, seen from above at a slant: "YOU" is a lit gold sphere
/// lifted over the middle of the disc (`UniverseSphere`), a violet haze under it, two elliptical orbits (70 × 43 and a dashed 122 × 80, radii), one round
/// dot for every video shared, coloured by its topic, on the disc that turns around the sphere once in 140 s (the far half dimmer and smaller, the near half
/// brighter), the platforms as planets at the edges (their size grows with the videos, `PlanetSize`) joined to the sphere by dashed curves, and the newest
/// video as a yellow star that pulses (2.6 s). Everything stops with Reduce Motion. A sealed year (`isSealed`) is dimmer and still. Planets, dots and the
/// core are buttons when `onOpen…` is given.
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appearedAt = Date.now
    @State private var openPlanet: Platform?

    /// The planets grow in 0.6 s with `cubic-bezier(.3, 1.4, .5, 1)`.
    private static let growth = UnitCurve.css(0.3, 1.4, 0.5, 1)
    private static let growthDuration = 0.6

    /// The board's size and its centre.
    static let board = CGSize(width: 358, height: 320)
    static let center = CGPoint(x: 179, y: 165)

    /// Where each platform's star sits on the board, with the point its dashed route bends toward and which way its label reads.
    struct Node {
        let point: CGPoint
        let control: CGPoint
        let labelAnchor: UnitPoint
    }

    static func node(_ platform: Platform) -> Node {
        switch platform {
        case .tiktok: Node(point: CGPoint(x: 326, y: 26), control: CGPoint(x: 260, y: 70), labelAnchor: .trailing)
        case .reels: Node(point: CGPoint(x: 24, y: 300), control: CGPoint(x: 70, y: 210), labelAnchor: .leading)
        case .shorts: Node(point: CGPoint(x: 334, y: 300), control: CGPoint(x: 290, y: 220), labelAnchor: .trailing)
        case .youtube: Node(point: CGPoint(x: 32, y: 26), control: CGPoint(x: 98, y: 70), labelAnchor: .leading)
        case .linkedin: Node(point: CGPoint(x: 179, y: 14), control: CGPoint(x: 150, y: 90), labelAnchor: .leading)
        case .stories: Node(point: CGPoint(x: 179, y: 312), control: CGPoint(x: 210, y: 240), labelAnchor: .leading)
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
            let center = CGPoint(x: origin.x + Self.center.x * scale, y: origin.y + Self.center.y * scale)
            let still = isStill
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still && frozenTime == nil && !isGrowing)) { context in
                    Canvas { canvas, _ in
                        var layer = canvas
                        layer.translateBy(x: origin.x, y: origin.y)
                        layer.scaleBy(x: scale, y: scale)
                        draw(in: &layer, time: frozenTime ?? (still ? 0 : context.date.timeIntervalSinceReferenceDate), now: context.date)
                    }
                }
                if onDot != nil { dotTaps(scale: scale, origin: origin) }
                if let caption { captionText(caption, scale: scale, origin: origin) }
                Text("YOU")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .position(x: center.x, y: center.y + 40 * scale)
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
    }

    /// The line under YOU while nothing is shared: lower and narrower (two lines) when last year's ghost is behind it.
    private func captionText(_ text: String, scale: CGFloat, origin: CGPoint) -> some View {
        let hasGhost = ghost != nil
        return Text(text)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Palette.ink.opacity(0.85))
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

    private var isGrowing: Bool { !previousCounts.isEmpty && Date.now.timeIntervalSince(appearedAt) < growthDelay + Self.growthDuration + 0.1 }

    /// 0 → 1 (past 1 with the spring) since the screen opened; 1 when nothing is growing.
    private func growthProgress(now: Date) -> Double {
        guard !previousCounts.isEmpty, !reduceMotion, animates, !isSealed, frozenTime == nil else { return 1 }
        let t = min(1, max(0, (now.timeIntervalSince(appearedAt) - growthDelay) / Self.growthDuration))
        return Self.growth.value(at: t)
    }

    private var isStill: Bool { reduceMotion || !animates || isSealed || frozenTime != nil }

    /// How many of the dots (and when the planets and the newest star) have appeared: 1 for the live map, 0 → 1 while a video builds it.
    private var build: Double { frozenTime.map { min(1, max(0, $0 / buildDuration)) } ?? 1 }

    // MARK: - Drawing (board coordinates)

    private func draw(in canvas: inout GraphicsContext, time: TimeInterval, now: Date) {
        let center = Self.center
        let core = Self.corePoint
        let spin = frozenTime == nil ? time * 2 * .pi / Self.spinPeriod : 0
        let hasVideos = snapshot.total > 0
        drawHaze(in: &canvas, at: center)
        drawOrbits(in: &canvas, opacity: !hasVideos && ghost == nil ? 0.55 : 1)
        if let ghost {
            // Last year, very faint behind this one: its routes, dots and planets, with no labels.
            for item in ghost.platforms { drawRoute(to: item.platform, opacity: 0.35, in: &canvas) }
            drawVideos(of: ghost, visible: ghost.dots.count, opacity: 0.18, spin: 0, front: nil, in: &canvas)
            for item in ghost.platforms {
                drawPlanet(item.platform, count: item.count, previous: item.count, progress: 1, opacity: 0.2, labeled: false, in: &canvas)
            }
        }
        let visible = Int((Double(snapshot.dots.count) * min(1, build / 0.8)).rounded(.up))
        if hasVideos {
            drawDust(in: &canvas)
            for item in snapshot.platforms where build >= 0.15 { drawRoute(to: item.platform, opacity: 1, in: &canvas) }
            drawVideos(of: snapshot, visible: visible, opacity: 1, spin: spin, front: false, in: &canvas)
        } else if ghost == nil {
            // Nothing shared yet: the routes to where the first star will go, very faint.
            for platform in [Platform.tiktok, .reels, .shorts] { drawRoute(to: platform, opacity: 0.45, in: &canvas) }
        }
        let swell = UniverseSphere.swell(at: time)
        UniverseSphere.drawGlow(&canvas, at: core, color: coreColor, swell: swell)
        UniverseSphere.drawBack(&canvas, at: core, time: time)
        UniverseSphere.drawBall(&canvas, at: core, color: coreColor, swell: swell)
        UniverseSphere.drawFront(&canvas, at: core, time: time)
        guard hasVideos else { return }
        drawVideos(of: snapshot, visible: visible, opacity: 1, spin: spin, front: true, in: &canvas)
        let progress = growthProgress(now: now)
        for (index, item) in snapshot.platforms.enumerated() where build >= 0.2 + 0.1 * Double(index) {
            let previous = previousCounts[item.platform] ?? item.count
            drawPlanet(item.platform, count: item.count, previous: previous, progress: progress, opacity: 1, labeled: true, in: &canvas)
        }
        if showsNewest, build >= 0.95 { drawNewest(in: &canvas, time: time) }
    }

    /// The haze under the sphere: violet, on the disc (wider than tall), and gone at the edge of the outer orbit.
    private func drawHaze(in canvas: inout GraphicsContext, at center: CGPoint) {
        var layer = canvas
        layer.translateBy(x: center.x, y: center.y)
        layer.scaleBy(x: 1, y: Self.outerOrbit.height / Self.outerOrbit.width)
        layer.fill(
            Self.disc(.zero, 112),
            with: .radialGradient(
                Gradient(colors: [
                    Palette.Universe.nightViolet.opacity(0.34), Palette.Universe.nightViolet.opacity(0.12), Palette.Universe.nightViolet.opacity(0),
                ]),
                center: .zero, startRadius: 0, endRadius: 112
            )
        )
    }

    /// Two elliptical orbits: 70 × 43 (solid, 22%) and 122 × 80 (dashed 2·4, 16%); `opacity` dims them (a new account: 55%).
    private func drawOrbits(in canvas: inout GraphicsContext, opacity: Double) {
        let c = Self.center
        func ellipse(_ size: CGSize) -> Path {
            Path(ellipseIn: CGRect(x: c.x - size.width, y: c.y - size.height, width: size.width * 2, height: size.height * 2))
        }
        canvas.stroke(ellipse(Self.innerOrbit), with: .color(Palette.Universe.starLilac.opacity(0.22 * opacity)), lineWidth: 0.8)
        canvas.stroke(
            ellipse(Self.outerOrbit), with: .color(Palette.Universe.starLilac.opacity(0.16 * opacity)),
            style: StrokeStyle(lineWidth: 0.8, dash: [2, 4])
        )
    }

    /// Soft grey specks of depth scattered on the disc, still: the dust the prototype leaves between the videos.
    private func drawDust(in canvas: inout GraphicsContext) {
        let c = Self.center
        for index in 0..<16 {
            let angle = Double(index) * 2.399_963
            let reach = (Double(index) + 0.5).squareRoot() / 4 * 1.04
            let size = 2 + 2.5 * (Double(index) * 0.618_034).truncatingRemainder(dividingBy: 1)
            let fade = 0.1 + 0.08 * (Double(index) * 0.37).truncatingRemainder(dividingBy: 1)
            let point = CGPoint(x: c.x + Self.outerOrbit.width * reach * cos(angle), y: c.y + Self.outerOrbit.height * reach * sin(angle))
            canvas.fill(Self.disc(point, size), with: .color(Palette.ink2.opacity(fade)))
        }
    }

    /// A dashed (2·4) curve from the sphere to a platform's planet, in its colour at 35%.
    private func drawRoute(to platform: Platform, opacity: Double, in canvas: inout GraphicsContext) {
        let node = Self.node(platform)
        var route = Path()
        route.move(to: Self.corePoint)
        route.addQuadCurve(to: node.point, control: node.control)
        canvas.stroke(route, with: .color(platform.tint.opacity(0.35 * opacity)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
    }

    /// One round dot for each video (up to 40 drawn), in its topic's colour, on the disc that has turned `spin` radians. The far half (`front: false`) is
    /// smaller and dimmer than the near half; nil draws both (last year's ghost).
    private func drawVideos(of snapshot: UniverseSnapshot, visible: Int, opacity: Double, spin: Double, front: Bool?, in canvas: inout GraphicsContext) {
        let c = Self.center
        for dot in snapshot.dots.prefix(visible) {
            let spot = Self.videoSpot(topic: dot.topicIndex, dot: dot.slot, drawn: dot.slot)
            let isFront = sin(spot.angle + spin) >= 0
            if let front, front != isFront { continue }
            let offset = spot.point(spin: spin)
            let point = CGPoint(x: c.x + offset.x, y: c.y + offset.y)
            let radius = spot.radius * (isFront ? 1.1 : 0.8)
            let color = OnboardingTopic.color(at: dot.topicIndex)
            let halo = Gradient(colors: [color.opacity(0.28 * opacity), color.opacity(0)])
            canvas.fill(Self.disc(point, radius * 2.6), with: .radialGradient(halo, center: point, startRadius: 0, endRadius: radius * 2.6))
            canvas.fill(Self.disc(point, radius), with: .color(color.opacity((isFront ? 1 : 0.6) * opacity)))
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

        var offset: CGPoint { point(spin: 0) }
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
    private func drawPlanet(
        _ platform: Platform, count: Int, previous: Int, progress: Double, opacity: Double, labeled: Bool, in canvas: inout GraphicsContext
    ) {
        let node = Self.node(platform)
        let from = PlanetSize.diameter(videos: previous)
        let to = PlanetSize.diameter(videos: count)
        let diameter = max(0, from + (to - from) * CGFloat(progress))
        let detail = PlanetSize.detail(videos: count)
        let gainedDetail = PlanetSize.detail(videos: previous) < detail
        let flash = gainedDetail ? max(0, 1 - abs(progress - 1) * 4) : 0
        PlanetPainter.draw(in: &canvas, center: node.point, diameter: diameter, detail: detail, tint: platform.tint, opacity: opacity, flash: flash)
        guard labeled else { return }
        let distance = PlanetPainter.labelDistance(diameter: diameter, detail: detail)
        let side: CGFloat = node.labelAnchor == .trailing ? -1 : 1
        let name = showsCounts ? "\(platform.label.uppercased()) · \(count)" : platform.label.uppercased()
        let label = Text(name).font(.system(size: 9.5, weight: .semibold, design: .monospaced))
        canvas.draw(
            label.foregroundStyle(Palette.ink.opacity(0.7)), at: CGPoint(x: node.point.x + side * distance, y: node.point.y + 4), anchor: node.labelAnchor
        )
    }

    /// The newest video: a bright yellow dot (3.6 pt) in a halo that breathes (2.6 s), on the right of the outer orbit.
    private func drawNewest(in canvas: inout GraphicsContext, time: TimeInterval) {
        guard snapshot.newest != nil else { return }
        let p = Self.newestPoint
        let pulse = 0.5 - 0.5 * cos(time * 2 * .pi / 2.6)
        let halo = 9 + 4 * pulse
        canvas.fill(
            Self.disc(p, halo),
            with: .radialGradient(Gradient(colors: [Palette.acc.opacity(0.55), Palette.acc.opacity(0)]), center: p, startRadius: 0, endRadius: halo)
        )
        canvas.fill(Self.disc(p, 2.4 + 1.2 * pulse), with: .color(Palette.acc))
    }

    private static func disc(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
