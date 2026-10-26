//
//  AIGlow.swift
//  Cue Studio
//

import SwiftUI

/// Apple Intelligence's light on a surface that listens: a thin rim of colour (`Palette.Scripts.dockGlow`) turning round `shape`, with a
/// soft halo round it, while a dictation listens, slowly, breathing with the voice (`level`). An idea sent from the surface has the star
/// instead (`StarTransitionOverlay`): the app is held still behind it. The halo is thin and fades within a few points of the edge, clear of
/// the words inside. Used on the Scripts dock (its glass); any shape fits.
/// Reduce Motion: the light doesn't turn; it fades in and out. Decorative.
struct AIGlow<Outline: InsettableShape>: View {
    /// The surface's outline: the light is drawn on it and inside it, never past its frame.
    let shape: Outline
    /// A dictation is listening.
    var isListening: Bool
    /// The voice's level, 0…1, while listening.
    var level: Double

    /// One slow turn while listening.
    private static var listeningTurn: TimeInterval { 5 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isListening {
                TimelineView(.animation) { context in
                    let light = light(at: context.date)
                    rim(angle: light.angle)
                        .opacity(light.strength)
                }
                .transition(.opacity)
            }
        }
        // The voice's level moves the light a little more slowly than it comes (the meter updates in steps).
        .animation(.easeOut(duration: 0.18), value: level)
        .animation(.easeInOut(duration: 0.35), value: isListening)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Where the colours are round the rim, and how strong the light is now.
    private func light(at date: Date) -> (angle: Angle, strength: Double) {
        let turn = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.listeningTurn) / Self.listeningTurn * 360
        return (.degrees(turn), 0.45 + 0.55 * min(1, max(0, level)))
    }

    /// The rim and its halo, laid out exactly on the surface (a bigger frame changed the dock's own size to the system). The halo is the
    /// same colours, blurred, which spills past the edge without taking room; it is thin, so inside it fades well before the words.
    private func rim(angle: Angle) -> some View {
        let colors = AngularGradient(colors: Palette.Scripts.dockGlow, center: .center, angle: angle)
        return ZStack {
            // Inside the edge (a stroke on it would reach past the frame); the blur spreads it both ways without taking room.
            shape
                .strokeBorder(colors, lineWidth: 5)
                .blur(radius: 9)
                .opacity(0.85)
            shape
                .strokeBorder(colors, lineWidth: 1.5)
        }
    }
}
