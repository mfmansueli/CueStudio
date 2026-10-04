//
//  OrbThumb.swift
//  Cue Studio
//

import SwiftUI

/// The planet of an orb control: a golden sphere (a radial gradient with its highlight at the top left),
/// a dark hairline so it reads on any background and a soft glow. While held it grows 14%.
struct OrbThumb: View {
    var diameter: CGFloat = 26
    var isHeld = false
    var isEnabled = true

    var body: some View {
        Circle()
            .fill(isEnabled ? gold : grey)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.55), lineWidth: 1))
            .frame(width: diameter, height: diameter)
            .shadow(color: isEnabled ? Palette.acc.opacity(isHeld ? 0.7 : 0.5) : .clear, radius: isHeld ? 14 : 12)
            .scaleEffect(isHeld ? 1.14 : 1)
    }

    private var gold: RadialGradient {
        RadialGradient(
            stops: [
                .init(color: Color(hex: 0xFFFDF2), location: 0),
                .init(color: Color(hex: 0xFFE680), location: 0.28),
                .init(color: Color(hex: 0xF2C200), location: 0.62),
                .init(color: Color(hex: 0x8A6400), location: 1),
            ],
            center: UnitPoint(x: 0.34, y: 0.3), startRadius: 0, endRadius: diameter * 0.75
        )
    }

    private var grey: RadialGradient {
        RadialGradient(
            colors: [Color(hex: 0xB8BAC8), Color(hex: 0x6C6F82)],
            center: UnitPoint(x: 0.34, y: 0.3), startRadius: 0, endRadius: diameter * 0.75
        )
    }
}

/// The ring that appears around the orb while it is held: an ellipse, tilted, whose light turns once
/// every four seconds. Still under Reduce Motion.
struct OrbitRing: View {
    var orbDiameter: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let width = orbDiameter + 22
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let turn = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate / CueMotion.Duration.orbitTurn
            Ellipse()
                .strokeBorder(
                    AngularGradient(
                        colors: [Palette.acc.opacity(0.1), Palette.acc.opacity(0.9), Palette.acc.opacity(0.1)],
                        center: .center, angle: .degrees(turn * 360)
                    ),
                    lineWidth: 1.2
                )
                .frame(width: width, height: width * 0.38)
                .rotationEffect(.degrees(-18))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A four-point star: the step marks under a stepped rail and the "this is the Cue star" glyph.
nonisolated struct FourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.28
        var path = Path()
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4 - .pi / 2
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
