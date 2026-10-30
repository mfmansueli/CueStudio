//
//  UltraPassOrbit.swift
//  Cue Studio
//

import SwiftUI

/// An Ultra AI script's orbit round the star while it waits (`StarTransitionOverlay`, in place of `ProgressOrbit`): one arc for each of Ultra
/// AI's passes (the draft, its claims checked, the polish in the creator's voice; `WritingPass`), in Cue's violet and gold
/// (`Palette.Scripts.ultraGlow`). The arc of the pass on now fills as its words come; a node in the gap after each arc lights as its pass
/// ends, and the node the pass on now will light glows in its moon's colour, a little more as its words come (its moon is forming,
/// `UltraWaitScene`). When the script is there (`gathered` 0 → 1) the arcs go and the nodes run into the star. Decorative: the phrase under
/// the star says which pass it is.
struct UltraPassOrbit: View {
    let meter: WritingProgressMeter
    var gathered: CGFloat = 0
    /// The ring's size: in the star's transition, Ultra AI's scene's (`UltraWaitScene.ringShare`), larger than Apple Intelligence's orbit.
    var diameter: CGFloat = ProgressOrbit.diameter

    /// The gap between two arcs, where a node sits, in turns.
    private static let gap = 0.045

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let radius = diameter / 2
        // Thicker on a larger ring.
        let weight = max(1, min(1.4, diameter / ProgressOrbit.diameter * 0.6))
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: meter.isFinished)) { _ in
            let count = max(1, meter.pass?.count ?? UltraFlow.checked.calls)
            let done = meter.isFinished ? count : (meter.pass?.index ?? 0)
            let current = meter.isFinished ? 1 : meter.passFraction
            ZStack {
                ZStack {
                    ForEach(0..<count, id: \.self) { arc in
                        let start = Double(arc) / Double(count) + Self.gap / 2
                        let end = Double(arc + 1) / Double(count) - Self.gap / 2
                        let filled = arc < done ? 1 : (arc == done ? current : 0)
                        Circle()
                            .trim(from: start, to: end)
                            .stroke(Palette.Scripts.transitionOrbitTrack, lineWidth: 1.5 * weight)
                        Circle()
                            .trim(from: start, to: start + (end - start) * filled)
                            .stroke(
                                AngularGradient(colors: Palette.Scripts.ultraGlow, center: .center),
                                style: StrokeStyle(lineWidth: 2.2 * weight, lineCap: .round)
                            )
                    }
                }
                .rotationEffect(.degrees(-90))
                .opacity(1 - gathered)
                ForEach(0..<count, id: \.self) { arc in
                    node(lit: arc < done, forming: arc == done ? current : 0, colour: UltraWaitScene.moonColour(of: arc, count: count))
                        .offset(y: -radius * (reduceMotion ? 1 : 1 - gathered))
                        .rotationEffect(.degrees(360 * Double(arc + 1) / Double(count)))
                        .opacity(1 - gathered * gathered)
                }
            }
            .frame(width: diameter, height: diameter)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: current)
        }
        .accessibilityHidden(true)
    }

    /// A pass's node: a faint point, glowing in its moon's colour as its pass comes (`forming`, 0…1), then a white light in a gold and violet
    /// glow that pops as it lights.
    private func node(lit: Bool, forming: Double, colour: Color) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [colour.opacity(0.7), colour.opacity(0)], center: .center, startRadius: 0, endRadius: 11))
                .frame(width: 22, height: 22)
                .scaleEffect(0.5 + 0.6 * forming)
                .opacity(lit || forming == 0 ? 0 : 0.2 + 0.6 * forming)
            Circle()
                .fill(RadialGradient(
                    colors: [Palette.World.skyStarYou.opacity(0.8), Palette.Scripts.ultraStarGlow.opacity(0.35), .clear],
                    center: .center, startRadius: 0, endRadius: 8
                ))
                .frame(width: 16, height: 16)
                .opacity(lit ? 1 : 0)
            Circle()
                .fill(lit ? Color.white : Palette.Scripts.transitionOrbitTrack)
                .frame(width: lit ? 5 : 4, height: lit ? 5 : 4)
        }
        .scaleEffect(lit ? 1 : 0.8)
        .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.55), value: lit)
    }
}
