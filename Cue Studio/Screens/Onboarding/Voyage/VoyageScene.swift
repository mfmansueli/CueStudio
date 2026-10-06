//
//  VoyageScene.swift
//  Cue Studio
//

import SwiftUI

/// The picture of 1.3 (09 §15, the board's `1.3_voyage`): the camera starts on the creator's own galaxy ("YOU", 3.8 times its final size, in
/// the middle of the screen), pulls back while the galaxy glides to the bottom left, and the five platforms' galaxies are born as it does,
/// each from a point with a ring and its name. A pick sends a light along a route from "YOU" to the chosen galaxy, which lights up on arrival.
///
/// It draws in the board's 390 × 844 coordinates, from the screen's top left (centred if the screen is wider), and every moving thing reads
/// its pose from a layer of the board (`MotionClip`) at the second of the opening (`time.clock`) or, for what a pick sets off, at the
/// board's own second of that moment (`pickClock` + the age of the pick).
struct VoyageScene: View {
    let time: MotionTime
    let picked: Platform?
    /// Seconds since the pick; nil while nothing is picked.
    let pickAge: Double?
    let onTapGalaxy: (Platform) -> Void

    /// Where this view sits on the screen: the board's origin is the screen's top left, not this view's (it starts below the progress bar).
    @State private var frame = CGRect(x: 0, y: 0, width: Self.boardWidth, height: 844)

    private static let clip = MotionLibrary.clip("1.3_voyage")
    private static let boardWidth: CGFloat = 390
    /// The camera pulls back about the creator's galaxy at its final place.
    private static let cameraOrigin = CGPoint(x: 78, y: 477)
    /// The creator's galaxy is drawn at the middle of its 360 pt box, which is where it opens.
    private static let heroOrigin = CGPoint(x: 195, y: 366)
    /// The second of the board at which its demo taps the galaxy: what a pick sets off is read from there.
    static let pickClock = 3.4

    private var clock: Double { time.clock }
    private var pickedAt: Double? { pickAge.map { $0 + Self.pickClock } }

    var body: some View {
        Canvas { context, size in
            var board = context
            board.translateBy(x: (size.width - Self.boardWidth) / 2 - frame.minX, y: -frame.minY)
            drawSocial(in: &board)
            drawHero(in: &board)
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { tap in
            let point = CGPoint(x: tap.location.x - (frame.width - Self.boardWidth) / 2, y: tap.location.y + frame.minY)
            let nearest = VoyageGalaxy.all.min { distance($0.centre, point) < distance($1.centre, point) }
            if let nearest, distance(nearest.centre, point) < 38 { onTapGalaxy(nearest.platform) }
        })
        .accessibilityHidden(true)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private func pose(_ layer: String, at second: Double? = nil) -> MotionPose { Self.clip.pose(of: layer, at: second ?? clock) }

    // MARK: - The platforms' galaxies (under the camera)

    private func drawSocial(in context: inout GraphicsContext) {
        guard let art = GalaxyLibrary.art else { return }
        let camera = pose("L5")
        var layer = context
        layer.translateBy(x: Self.cameraOrigin.x + camera.tx, y: Self.cameraOrigin.y + camera.ty)
        layer.scaleBy(x: camera.sx, y: camera.sy)
        layer.translateBy(x: -Self.cameraOrigin.x, y: -Self.cameraOrigin.y)
        for galaxy in VoyageGalaxy.all {
            guard let social = art.socials[galaxy.key] else { continue }
            let birth = pose(galaxy.birth)
            guard birth.opacity > 0.005, birth.sx > 0.001 else { continue }
            let standing = standing(of: galaxy)
            var drawn = layer
            drawn.opacity = birth.opacity * standing.opacity
            GalaxyPainter.drawSocial(social, in: &drawn, spin: time.ambient / social.spin * 360, scale: birth.sx * standing.scale)
        }
        drawRoute(in: &layer)
        drawBirthRings(in: &layer)
        drawNames(in: &layer)
    }

    /// How a galaxy stands: before a pick they are all a little dim (TikTok, the biggest, a little smaller too); a pick lights the chosen one and
    /// grows it (×1.14, then settles, and swells again on arrival) while the others dim to 42%.
    private func standing(of galaxy: VoyageGalaxy) -> (scale: Double, opacity: Double) {
        let isTikTok = galaxy.platform == .tiktok
        guard let pickedAt else { return isTikTok ? (0.9, 0.8) : (1, 0.85) }
        if galaxy.platform == picked {
            let lit = pose("L15", at: pickedAt)
            return (isTikTok ? lit.sx : lit.sx + 0.1, max(lit.opacity, 0.85))
        }
        let dimmed = pose("L6", at: pickedAt).opacity
        return (isTikTok ? 0.9 : 1, isTikTok ? dimmed * 0.8 / 0.85 : dimmed)
    }

    private func drawBirthRings(in context: inout GraphicsContext) {
        for galaxy in VoyageGalaxy.all {
            LightFX.ring(pose(galaxy.ring), at: galaxy.centre, radius: 22, color: Palette.Universe.starCream, lineWidth: 1.2, in: &context)
        }
    }

    /// Each galaxy's name fades in a little after it is born; the chosen one's turns bright in its own colour.
    private func drawNames(in context: inout GraphicsContext) {
        for galaxy in VoyageGalaxy.all {
            let visible = pose(galaxy.name).opacity
            guard visible > 0.01 else { continue }
            var layer = context
            layer.opacity = visible
            layer.draw(
                Text(galaxy.platform.label.uppercased()).font(.system(size: galaxy.nameSize, weight: .semibold, design: .monospaced))
                    .tracking(galaxy.nameSize * 0.12).foregroundStyle(nameColor(of: galaxy)),
                at: galaxy.nameCentre
            )
        }
    }

    /// A name is quiet (TikTok's in its own colour at 55%, the others a pale grey) until its galaxy is the destination.
    private func nameColor(of galaxy: VoyageGalaxy) -> Color {
        if galaxy.platform == picked { return galaxy.platform.tint }
        if galaxy.platform == .tiktok { return galaxy.platform.tint.opacity(0.55) }
        return Palette.Flight.ink.opacity(galaxy.platform == .youtube ? 0.4 : 0.45)
    }

    // MARK: - The route, the light and the arrival

    private func drawRoute(in context: inout GraphicsContext) {
        let target = VoyageGalaxy.of(picked ?? .tiktok)
        guard let target else { return }
        let route = VoyageRoute(to: target.centre)
        // The dotted way, a hint of where a pick would go (it is there from 2.3 s, before any pick).
        let hint = pickedAt == nil ? pose("L19").opacity : 1
        if hint > 0.01 {
            context.stroke(
                route.path, with: .color(Palette.Universe.starLilac.opacity(0.2 * hint)),
                style: StrokeStyle(lineWidth: 1, lineCap: .butt, dash: [2, 5])
            )
        }
        guard let pickedAt, let picked, let galaxy = VoyageGalaxy.of(picked) else { return }
        drawLight(along: route, at: pickedAt, in: &context)
        drawArrival(at: galaxy, second: pickedAt, in: &context)
    }

    /// The light: a yellow line that draws behind it (`#FFD60A`, 1.6 pt), a bright stretch at its tail, the head with its dots, and four glints.
    private func drawLight(along route: VoyageRoute, at second: Double, in context: inout GraphicsContext) {
        let line = pose("L20", at: second)
        if line.opacity > 0.01 {
            context.drawLayer { layer in
                layer.opacity = line.opacity
                layer.addFilter(.shadow(color: Palette.acc.opacity(0.8), radius: 4))
                layer.stroke(
                    route.path.trimmedPath(from: 0, to: line.drawn), with: .color(Palette.acc), style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                )
            }
        }
        let tail = pose("L21", at: second)
        if tail.opacity > 0.01, let dash = tail.dash {
            let start = max(0, -dash / 100), end = min(1, (14 - dash) / 100)
            if end > start {
                context.drawLayer { layer in
                    layer.opacity = tail.opacity
                    layer.addFilter(.shadow(color: Palette.acc.opacity(0.95), radius: 6))
                    layer.stroke(
                        route.path.trimmedPath(from: start, to: end), with: .color(Palette.Universe.starCream),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                }
            }
        }
        let sizes: [CGFloat] = [5, 7, 9, 11, 13, 16]
        for (index, id) in ["L43", "L42", "L41", "L40", "L39", "L38"].enumerated() {
            let dot = pose(id, at: second)
            guard dot.opacity > 0.01, let along = dot.along else { continue }
            let fade = dot.opacity * (0.3 + 0.12 * Double(index))
            context.fill(LightFX.disc(route.point(atLength: along), sizes[index] / 2 * 0.65), with: .color(Palette.Universe.starCream.opacity(fade)))
        }
        let head = pose("L23", at: second)
        if head.opacity > 0.01, let along = head.along {
            let point = route.point(atLength: along)
            context.fill(
                LightFX.disc(point, 13),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Palette.Universe.starCream.opacity(head.opacity), location: 0),
                        .init(color: Palette.Universe.starCream.opacity(head.opacity), location: 0.16 / 0.7),
                        .init(color: Palette.acc.opacity(0.6 * head.opacity), location: 0.32 / 0.7), .init(color: Palette.acc.opacity(0), location: 1),
                    ]),
                    center: point, startRadius: 0, endRadius: 13
                )
            )
        }
        let glints: [(layer: String, parameter: Double, size: CGFloat)] = [
            ("L44", 0.218, 14), ("L45", 0.414, 10), ("L46", 0.608, 14), ("L47", 0.799, 10),
        ]
        for glint in glints {
            LightFX.cross(
                at: route.point(at: glint.parameter), size: glint.size, thickness: 1, verticalRatio: 1, pose: pose(glint.layer, at: second),
                color: Palette.Universe.starGold, in: &context
            )
        }
    }

    /// The arrival: a flash and a cross of light, two rings, ten streaks and nine sparks on the galaxy, and then its ring that goes on pulsing.
    private func drawArrival(at galaxy: VoyageGalaxy, second: Double, in context: inout GraphicsContext) {
        let tint = galaxy.platform.tint
        let centre = galaxy.centre
        let flash = pose("L18", at: second)
        if flash.opacity > 0.01 {
            context.drawLayer { layer in
                layer.opacity = flash.opacity
                layer.fill(
                    LightFX.disc(centre, 34 * flash.sx),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: .white, location: 0), .init(color: Palette.Flight.ice.opacity(0.8), location: 0.35),
                            .init(color: tint.opacity(0), location: 1),
                        ]),
                        center: centre, startRadius: 0, endRadius: 34 * flash.sx
                    )
                )
            }
        }
        LightFX.cross(
            at: centre, size: 120, thickness: 1.8, verticalRatio: 0.7, pose: pose("L22", at: second),
            color: tint.mix(with: .white, by: 0.7), glow: tint.opacity(0.9), in: &context
        )
        LightFX.ring(pose("L24", at: second), at: centre, radius: 22, color: tint, in: &context)
        LightFX.ring(pose("L25", at: second), at: centre, radius: 22, color: Palette.Flight.ice.opacity(0.8), lineWidth: 1, in: &context)
        for index in 0..<10 { LightFX.streak(pose("L\(48 + index)", at: second), at: centre, from: tint, in: &context) }
        let sizes: [CGFloat] = [3, 2, 2.5]
        for index in 0..<9 {
            let colors: [Color] = [Palette.Flight.ice, .white, tint]
            LightFX.spark(pose("L\(58 + index)", at: second), at: centre, size: sizes[index % 3], color: colors[index % 3], in: &context)
        }
        // The chosen galaxy's ring: it opens and fades again and again.
        let chosen = pose("L26", at: second).opacity
        if chosen > 0.01 {
            var halo = Self.clip.pose(of: "L27", at: time.ambient, loops: true)
            halo.opacity *= chosen
            LightFX.ring(halo, at: centre, radius: 18, color: tint, in: &context)
        }
    }

    // MARK: - The creator's galaxy

    private func drawHero(in context: inout GraphicsContext) {
        guard let art = GalaxyLibrary.art else { return }
        let hero = pose("L67")
        guard hero.opacity > 0.001 else { return }
        var layer = context
        layer.opacity = hero.opacity
        layer.translateBy(x: Self.heroOrigin.x + hero.tx, y: Self.heroOrigin.y + hero.ty)
        layer.scaleBy(x: hero.sx, y: hero.sy)
        let disc = HeroDiscCache.image.map { context.resolve(Image(uiImage: $0)) }
        GalaxyPainter.drawHero(art.hero, in: &layer, time: time.ambient, disc: disc)
        drawYou(in: &layer)
    }

    /// "YOU" under the galaxy: 38 pt mono that shrinks with it to 10 pt. Its letters leave from the middle outward (O first, then Y and U), each
    /// stretched across and blurred, settling while the tracking closes from 0.95 em to 0.16 em, with a lavender glow and a yellow glint.
    private func drawYou(in context: inout GraphicsContext) {
        let spacing = (pose("L73").letterSpacingEm ?? 0.16) * 38
        let step = 38 * 0.6 + spacing
        for (index, id) in ["L74", "L75", "L76"].enumerated() {
            let letter = pose(id)
            guard letter.opacity > 0.01 else { continue }
            var layer = context
            layer.opacity = letter.opacity
            layer.translateBy(x: CGFloat(index - 1) * step, y: 159.5)
            layer.scaleBy(x: letter.sx, y: letter.sy)
            if letter.blur > 0.1 { layer.addFilter(.blur(radius: letter.blur)) }
            if letter.glowRadius > 0.1, let glow = letter.glow { layer.addFilter(.shadow(color: glow, radius: letter.glowRadius)) }
            layer.draw(
                Text(["Y", "O", "U"][index]).font(.system(size: 38, weight: .bold, design: .monospaced))
                    .foregroundStyle(letter.color ?? Palette.Universe.starLilac),
                at: .zero
            )
        }
    }
}
