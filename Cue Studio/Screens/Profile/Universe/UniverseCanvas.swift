//
//  UniverseCanvas.swift
//  Cue Studio
//

import SwiftUI

/// The creator's universe in one picture: the animated core "YOU" in the middle (no photo, no initial), an orbit for each topic with a dot for every video
/// shared from it, and the platforms as stars at the edges, joined to the middle by dashed routes. The newest video
/// is a yellow star that pulses. Slow orbits; still under Reduce Motion.
struct UniverseMap: View {
    let snapshot: UniverseSnapshot
    var animates = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where each platform's star sits, as a fraction of the picture.
    static func place(_ platform: Platform) -> CGPoint {
        switch platform {
        case .tiktok: CGPoint(x: 0.82, y: 0.1)
        case .reels: CGPoint(x: 0.12, y: 0.92)
        case .shorts: CGPoint(x: 0.88, y: 0.92)
        case .youtube: CGPoint(x: 0.1, y: 0.1)
        case .linkedin: CGPoint(x: 0.5, y: 0.02)
        case .stories: CGPoint(x: 0.5, y: 0.98)
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !animates)) { context in
            Canvas { canvas, size in
                draw(in: &canvas, size: size, time: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Your universe"))
        .accessibilityValue(Text("\(snapshot.total) videos shared"))
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        drawRoutes(in: &canvas, size: size, center: center)
        for (index, entry) in snapshot.topics.enumerated() { drawOrbit(entry, index: index, in: &canvas, center: center, size: size, time: time) }
        drawYou(in: &canvas, center: center, time: time)
        for item in snapshot.platforms { drawPlatform(item.platform, count: item.count, in: &canvas, size: size) }
        drawNewest(in: &canvas, center: center, size: size, time: time)
    }

    private func drawRoutes(in canvas: inout GraphicsContext, size: CGSize, center: CGPoint) {
        for item in snapshot.platforms {
            let unit = Self.place(item.platform)
            var route = Path()
            route.move(to: center)
            route.addLine(to: CGPoint(x: size.width * unit.x, y: size.height * unit.y))
            canvas.stroke(route, with: .color(item.platform.tint.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
    }

    private func drawOrbit(
        _ entry: UniverseSnapshot.TopicCount, index: Int, in canvas: inout GraphicsContext, center: CGPoint, size: CGSize, time: TimeInterval
    ) {
        let color = OnboardingTopic.color(at: index)
        let radius = min(size.width, size.height) * (0.2 + 0.09 * CGFloat(index))
        canvas.stroke(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(color.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [2, 5])
        )
        // One dot per video (up to 30 drawn), spread around the orbit and turning slowly.
        let dots = min(entry.count, 30)
        for dot in 0..<dots {
            let angle = Double(dot) / Double(max(1, dots)) * 2 * .pi + Double(index) * 1.3 + time * (0.04 + 0.015 * Double(index))
            let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
            canvas.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(color))
        }
    }

    /// The core: a soft violet glow that breathes (4 s), a gradient ring and a small star that circles it (12 s).
    private func drawYou(in canvas: inout GraphicsContext, center: CGPoint, time: TimeInterval) {
        let breath = 1 + 0.08 * sin(time * 2 * .pi / 4)
        let glow = 60 * breath
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
            with: .radialGradient(Gradient(colors: [Color(hex: 0x9D8CFF).opacity(0.5), .clear]), center: center, startRadius: 0, endRadius: glow)
        )
        let core = 26 * breath
        let disc = CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2)
        canvas.fill(Path(ellipseIn: disc), with: .radialGradient(
            Gradient(colors: [Palette.acc, Palette.aiText.opacity(0.9)]), center: center, startRadius: 0, endRadius: core
        ))
        let ring = CGRect(x: center.x - 38, y: center.y - 38, width: 76, height: 76)
        canvas.stroke(Path(ellipseIn: ring), with: .color(Palette.aiText.opacity(0.5)), lineWidth: 1)
        let angle = time * 2 * .pi / 12
        let star = CGPoint(x: center.x + 38 * CGFloat(cos(angle)), y: center.y + 38 * CGFloat(sin(angle)))
        canvas.fill(Path(ellipseIn: CGRect(x: star.x - 3, y: star.y - 3, width: 6, height: 6)), with: .color(.white))
        canvas.draw(
            Text("YOU").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.ink2),
            at: CGPoint(x: center.x, y: center.y + 54)
        )
    }

    private func drawPlatform(_ platform: Platform, count: Int, in canvas: inout GraphicsContext, size: CGSize) {
        let unit = Self.place(platform)
        let point = CGPoint(x: size.width * unit.x, y: size.height * unit.y)
        canvas.fill(Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)), with: .color(platform.tint.opacity(0.25)))
        canvas.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(platform.tint))
        let onLeft = unit.x < 0.5
        let label = Text("\(platform.label.uppercased()) · \(count)").font(.system(size: 11, weight: .bold, design: .monospaced))
        canvas.draw(
            label.foregroundStyle(Palette.ink2),
            at: CGPoint(x: point.x + (onLeft ? 14 : -14), y: point.y + (unit.y > 0.5 ? 20 : -20)), anchor: onLeft ? .leading : .trailing
        )
    }

    private func drawNewest(in canvas: inout GraphicsContext, center: CGPoint, size: CGSize, time: TimeInterval) {
        guard snapshot.newest != nil else { return }
        let point = CGPoint(x: center.x + size.width * 0.27, y: center.y - size.height * 0.1)
        let pulse = 1 + 0.2 * sin(time * 2.4)
        let halo = CGRect(x: point.x - 14 * pulse, y: point.y - 14 * pulse, width: 28 * pulse, height: 28 * pulse)
        canvas.fill(Path(ellipseIn: halo), with: .color(Palette.acc.opacity(0.22)))
        canvas.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(Palette.acc))
        canvas.draw(
            Text("NEW").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.accText),
            at: CGPoint(x: point.x + 22, y: point.y - 14)
        )
    }
}
