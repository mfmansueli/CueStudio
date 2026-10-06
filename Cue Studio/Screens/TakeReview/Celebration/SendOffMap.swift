//
//  SendOffMap.swift
//  Cue Studio
//

import SwiftUI

/// The universe of the send-off (8.2) on the top 580 pt of the board's frame: two flat orbits round YOU, a planet for each network (the ones just
/// sent to light up and grow by one as their star lands), the stars with their trails, the rings, "+1" and the new star. A pure function of `time`
/// (`SendOffScript`).
struct SendOffMap: View {
    let networks: [ShareDestination]
    /// What each network has this year, with this share in it.
    let counts: [Platform: Int]
    let time: Double

    private var indexes: [Platform: Int] {
        Dictionary(networks.enumerated().map { ($1.platform, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        let indexes = indexes
        ZStack(alignment: .topLeading) {
            orbits
            you
            ForEach(Platform.allCases) { platform in planet(platform, sent: indexes[platform]) }
            light
            ForEach(Array(networks.enumerated()), id: \.element) { index, network in plusOne(for: network, index: index) }
        }
        .frame(width: SendOffLayout.board.width, height: SendOffLayout.mapHeight, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - YOU and the orbits

    /// The board's two circles, flattened to 32% and turned −9° (their rim is an inset 1 pt line, so it thins to 0.3 pt where it is flattened).
    private var orbits: some View {
        Canvas { context, _ in
            for (index, width) in SendOffLayout.orbitWidths.enumerated() {
                var layer = context
                layer.translateBy(x: SendOffLayout.you.x, y: SendOffLayout.you.y)
                layer.rotate(by: .degrees(SendOffLayout.orbitTurn))
                layer.scaleBy(x: 1, y: SendOffLayout.orbitFlatness)
                let radius = width / 2 - 0.5
                layer.stroke(
                    Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
                    with: .color(index == 0 ? Palette.starLilac.opacity(0.16) : Palette.sendOffInnerOrbit), lineWidth: 1
                )
            }
        }
    }

    /// The planet that is you: gold lit from the top left, in a soft glow, with its name under it.
    private var you: some View {
        let diameter = SendOffLayout.youDiameter
        return ZStack {
            Circle().fill(Palette.sendOffYouGlow).frame(width: diameter + 20, height: diameter + 20).blur(radius: 20)
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: Palette.proPlanetLight, location: 0), .init(color: Palette.proPlanetMid, location: 0.3),
                        .init(color: Palette.proPlanetShade, location: 0.66), .init(color: Palette.proPlanetDark, location: 1),
                    ],
                    center: UnitPoint(x: 0.36, y: 0.32), startRadius: 0, endRadius: diameter * 0.934
                ))
                .overlay(Circle().strokeBorder(Palette.sendOffYouRim, lineWidth: 0.8))
                .frame(width: diameter, height: diameter)
        }
        .position(SendOffLayout.you)
        .overlay(alignment: .topLeading) {
            Text("YOU")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.26)
                .foregroundStyle(Palette.sendOffYouName)
                .frame(width: 100)
                .position(x: SendOffLayout.you.x, y: SendOffLayout.you.y - diameter / 2 + 64 + 5.5)
        }
    }

    // MARK: - Planets

    /// A network's planet and its name and count. Dimmed to 38% (desaturated, a small glow) until its star lands; then it lights, pulses and counts one more.
    private func planet(_ platform: Platform, sent index: Int?) -> some View {
        let diameter = SendOffLayout.diameter(of: platform, counts: counts)
        let center = SendOffLayout.center(of: platform)
        let lit = index.map { SendOffScript.lit($0, at: time) } ?? 0
        let pulse = index.map { SendOffScript.planetScale($0, at: time) } ?? 1
        let tint = platform.tint
        let total = counts[platform] ?? 0
        let shown = index.map { SendOffScript.count(final: total, index: $0, at: time) } ?? total
        return ZStack {
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: .white, location: 0), .init(color: tint, location: 0.4), .init(color: tint.mix(with: .black, by: 0.6), location: 1),
                    ],
                    center: UnitPoint(x: 0.34, y: 0.30), startRadius: 0, endRadius: diameter * 0.962
                ))
                .frame(width: diameter, height: diameter)
                .shadow(color: tint.opacity(0.53), radius: 8 + 10 * lit)
                .saturation(1 - 0.4 * (1 - lit))
                .opacity(1 - 0.62 * (1 - lit))
                .scaleEffect(pulse)
                .position(center)
            Text(verbatim: "\(platform.label.uppercased()) · \(shown)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(lit > 0.5 ? Color.white : Palette.sendOffNameDim)
                .fixedSize()
                .position(x: center.x, y: center.y + diameter / 2 + 6 + 5.5)
        }
    }

    // MARK: - Light

    /// The stars and their trails, the rings and the new star.
    private var light: some View {
        Canvas { context, _ in
            for (index, network) in networks.enumerated() {
                let center = SendOffLayout.center(of: network.platform)
                let route = SendOffLayout.arc(to: center)
                for dot in stride(from: SendOffScript.trailDots, through: 1, by: -1) {
                    guard let flight = SendOffScript.star(index, dot: dot, at: time) else { continue }
                    let point = SendOffLayout.point(on: route, at: flight.progress)
                    let radius = 2 * flight.scale
                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(Palette.starGold.opacity(flight.opacity))
                    )
                }
                if let flight = SendOffScript.star(index, at: time) {
                    star(&context, at: SendOffLayout.point(on: route, at: flight.progress), scale: flight.scale, opacity: flight.opacity)
                }
                if let ring = SendOffScript.ring(index, at: time) {
                    let radius = 10.75 * ring.scale
                    context.stroke(
                        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white.opacity(ring.opacity)), lineWidth: 1.5 * ring.scale
                    )
                }
            }
            let newStar = SendOffScript.newStar(at: time)
            if newStar.opacity > 0.01 { glowDot(&context, at: SendOffLayout.newStar, radius: 2.5 * newStar.scale, opacity: newStar.opacity) }
        }
    }

    /// The flying star: a white 10 pt dot in a golden glow (`0 0 14px 5px rgba(255,214,10,.8), 0 0 3px 1px #FFE680`).
    private func star(_ context: inout GraphicsContext, at point: CGPoint, scale: Double, opacity: Double) {
        let halo = 10 * scale, rim = 6 * scale, core = 5 * scale
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 7))
            layer.fill(disc(point, halo), with: .color(Palette.acc.opacity(0.8 * opacity)))
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 1.5))
            layer.fill(disc(point, rim), with: .color(Palette.starGold.opacity(opacity)))
        }
        context.fill(disc(point, core), with: .color(.white.opacity(opacity)))
    }

    /// The new star: a 5 pt dot of `starGold` in a glow (`0 0 8px 2px rgba(255,214,10,.7)`).
    private func glowDot(_ context: inout GraphicsContext, at point: CGPoint, radius: Double, opacity: Double) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 4))
            layer.fill(disc(point, radius + 2), with: .color(Palette.acc.opacity(0.7 * opacity)))
        }
        context.fill(disc(point, radius), with: .color(Palette.starGold.opacity(opacity)))
    }

    private func disc(_ center: CGPoint, _ radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    // MARK: - "+1"

    /// "+1 · TIKTOK" over the first planet, "+1" beside the others, in yellow mono, coming up as each star lands.
    private func plusOne(for network: ShareDestination, index: Int) -> some View {
        let center = SendOffLayout.center(of: network.platform)
        let diameter = SendOffLayout.diameter(of: network.platform, counts: counts)
        let spot = SendOffLayout.plusSpot(index: index, center: center, diameter: diameter)
        let pose = SendOffScript.plus(index, at: time)
        let width: CGFloat = spot.isCentred ? 140 : 40
        return Text(verbatim: index == 0 ? "+1 · \(network.platform.label.uppercased())" : "+1")
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(0.66)
            .foregroundStyle(Palette.acc)
            .frame(width: width, alignment: spot.isCentred ? .center : .leading)
            .opacity(pose.opacity)
            .position(x: spot.isCentred ? spot.point.x : spot.point.x + width / 2, y: spot.point.y + 6.5 + pose.lift)
    }
}
