//
//  UniverseCanvas.swift
//  Cue Studio
//

import SwiftUI

/// The creator's universe in one picture (v30 · 9.2), drawn on the board's 358 × 320 grid and scaled to fit: "YOU" in the middle (the animated core, no
/// photo), a violet glow behind it, two elliptical orbits (70 × 60 and a dashed 122 × 105), one still dot for every video shared, coloured by its
/// topic and scattered along the orbits, the platforms as stars at the edges joined to the middle by dashed curves, and the newest video as a
/// yellow star that pulses (2.6 s). Only the core and that pulse move; both stop with Reduce Motion.
struct UniverseMap: View {
    let snapshot: UniverseSnapshot
    var animates = true
    /// The core's colour (Settings › Personalize).
    var coreColor: CoreColor = .gold

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The board's size and its centre.
    static let board = CGSize(width: 358, height: 320)
    static let center = CGPoint(x: 179, y: 165)

    /// Where each platform's star sits on the board, with the point its dashed route bends toward and which way its label reads.
    struct Node {
        let point: CGPoint
        let control: CGPoint
        let labelAnchor: UnitPoint
        let labelOffset: CGPoint
    }

    static func node(_ platform: Platform) -> Node {
        switch platform {
        case .tiktok: Node(point: CGPoint(x: 326, y: 26), control: CGPoint(x: 260, y: 70), labelAnchor: .trailing, labelOffset: CGPoint(x: -12, y: 4))
        case .reels: Node(point: CGPoint(x: 24, y: 300), control: CGPoint(x: 70, y: 210), labelAnchor: .leading, labelOffset: CGPoint(x: 12, y: 4))
        case .shorts: Node(point: CGPoint(x: 334, y: 300), control: CGPoint(x: 290, y: 220), labelAnchor: .trailing, labelOffset: CGPoint(x: -12, y: 4))
        case .youtube: Node(point: CGPoint(x: 32, y: 26), control: CGPoint(x: 98, y: 70), labelAnchor: .leading, labelOffset: CGPoint(x: 12, y: 4))
        case .linkedin: Node(point: CGPoint(x: 179, y: 14), control: CGPoint(x: 150, y: 90), labelAnchor: .leading, labelOffset: CGPoint(x: 12, y: 4))
        case .stories: Node(point: CGPoint(x: 179, y: 312), control: CGPoint(x: 210, y: 240), labelAnchor: .leading, labelOffset: CGPoint(x: 12, y: 4))
        }
    }

    /// The newest video's star.
    static let newestPoint = CGPoint(x: 292, y: 118)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / Self.board.width, proxy.size.height / Self.board.height)
            let origin = CGPoint(
                x: (proxy.size.width - Self.board.width * scale) / 2, y: (proxy.size.height - Self.board.height * scale) / 2
            )
            let center = CGPoint(x: origin.x + Self.center.x * scale, y: origin.y + Self.center.y * scale)
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !animates || snapshot.newest == nil)) { context in
                    Canvas { canvas, _ in
                        var layer = canvas
                        layer.translateBy(x: origin.x, y: origin.y)
                        layer.scaleBy(x: scale, y: scale)
                        draw(in: &layer, time: reduceMotion || !animates ? 0 : context.date.timeIntervalSinceReferenceDate)
                    }
                }
                UniverseCore(color: coreColor, style: .full, animates: animates)
                    .scaleEffect(scale)
                    .position(center)
                Text("YOU")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .position(x: center.x, y: center.y + 44 * scale)
            }
        }
        .aspectRatio(snapshot.total == 0 ? nil : Self.board.width / Self.board.height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Your universe"))
        .accessibilityValue(Text("\(snapshot.total) videos shared"))
    }

    // MARK: - Drawing (board coordinates)

    private func draw(in canvas: inout GraphicsContext, time: TimeInterval) {
        let center = Self.center
        // The glow behind everything: `#9D8CFF` at 45%, gone at 74 pt.
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - 74, y: center.y - 74, width: 148, height: 148)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0x9D8CFF, opacity: 0.45), Color(hex: 0x9D8CFF, opacity: 0)]),
                center: center, startRadius: 0, endRadius: 74
            )
        )
        guard snapshot.total > 0 else { return }
        drawOrbits(in: &canvas)
        for item in snapshot.platforms { drawRoute(to: item.platform, in: &canvas) }
        drawVideos(in: &canvas)
        for item in snapshot.platforms { drawPlatform(item.platform, count: item.count, in: &canvas) }
        drawNewest(in: &canvas, time: time)
    }

    /// Two elliptical orbits: 70 × 60 (solid, 14%) and 122 × 105 (dashed 2·5, 10%).
    private func drawOrbits(in canvas: inout GraphicsContext) {
        let c = Self.center
        let ink = Color(hex: 0xE4DEFF)
        canvas.stroke(
            Path(ellipseIn: CGRect(x: c.x - 70, y: c.y - 60, width: 140, height: 120)), with: .color(ink.opacity(0.14)), lineWidth: 1
        )
        canvas.stroke(
            Path(ellipseIn: CGRect(x: c.x - 122, y: c.y - 105, width: 244, height: 210)), with: .color(ink.opacity(0.1)),
            style: StrokeStyle(lineWidth: 1, dash: [2, 5])
        )
    }

    /// A dashed (2·4) curve from the middle to a platform's star, in its colour at 35%.
    private func drawRoute(to platform: Platform, in canvas: inout GraphicsContext) {
        let node = Self.node(platform)
        var route = Path()
        route.move(to: Self.center)
        route.addQuadCurve(to: node.point, control: node.control)
        canvas.stroke(route, with: .color(platform.tint.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
    }

    /// One still dot for each video (up to 40 drawn), in its topic's colour: 1.6 to 2.4 pt, along the inner and outer orbits.
    private func drawVideos(in canvas: inout GraphicsContext) {
        let c = Self.center
        var drawn = 0
        for (index, entry) in snapshot.topics.enumerated() {
            let colour = OnboardingTopic.color(at: index)
            for dot in 0..<entry.count where drawn < 40 {
                let place = Self.videoSpot(topic: index, dot: dot, drawn: drawn)
                let radius = place.radius
                canvas.fill(
                    Path(ellipseIn: CGRect(x: c.x + place.offset.x - radius, y: c.y + place.offset.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(colour)
                )
                drawn += 1
            }
        }
    }

    /// Where a video sits: alternately near the inner and the outer orbit, spread by golden-ratio turns, a little off the line. The same every
    /// time, so the picture never shuffles.
    static func videoSpot(topic: Int, dot: Int, drawn: Int) -> (offset: CGPoint, radius: CGFloat) {
        let golden = 0.618_033_988_75
        let turn = (Double(drawn) * golden + Double(topic) * 0.21).truncatingRemainder(dividingBy: 1)
        let angle = turn * 2 * .pi
        let outer = drawn % 2 == 0
        let jitter = 0.9 + 0.2 * ((Double(drawn) * 0.754_877_666).truncatingRemainder(dividingBy: 1))
        let rx = (outer ? 122.0 : 70.0) * jitter
        let ry = (outer ? 105.0 : 60.0) * jitter
        let size = 1.6 + 0.8 * ((Double(drawn + dot) * 0.569_840_29).truncatingRemainder(dividingBy: 1))
        return (CGPoint(x: rx * cos(angle), y: ry * sin(angle)), CGFloat(size))
    }

    /// A star for a platform: a 4 pt dot in a 10 pt halo at 18%, and "TIKTOK · 12" beside it.
    private func drawPlatform(_ platform: Platform, count: Int, in canvas: inout GraphicsContext) {
        let node = Self.node(platform)
        let p = node.point
        canvas.fill(Path(ellipseIn: CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20)), with: .color(platform.tint.opacity(0.18)))
        canvas.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(platform.tint))
        let label = Text("\(platform.label.uppercased()) · \(count)").font(.system(size: 9.5, weight: .semibold, design: .monospaced))
        canvas.draw(
            label.foregroundStyle(Palette.ink.opacity(0.7)), at: CGPoint(x: p.x + node.labelOffset.x, y: p.y + node.labelOffset.y),
            anchor: node.labelAnchor
        )
    }

    /// The newest video: a yellow star (2.4 → 3.6 → 2.4 pt over 2.6 s) in a 9 pt halo at 20%, and "NEW".
    private func drawNewest(in canvas: inout GraphicsContext, time: TimeInterval) {
        guard snapshot.newest != nil else { return }
        let p = Self.newestPoint
        let pulse = 0.5 - 0.5 * cos(time * 2 * .pi / 2.6)
        let radius = 2.4 + 1.2 * pulse
        canvas.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(Palette.acc.opacity(0.2)))
        canvas.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)), with: .color(Palette.acc))
        canvas.draw(
            Text("NEW").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.acc),
            at: CGPoint(x: p.x + 8, y: p.y - 6), anchor: .leading
        )
    }
}
