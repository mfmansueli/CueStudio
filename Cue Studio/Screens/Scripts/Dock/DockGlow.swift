//
//  DockGlow.swift
//  Cue Studio
//

import SwiftUI

/// Apple Intelligence's light on the Scripts dock: a thin rim of colour (`Palette.Scripts.dockGlow`) turning round the glass, with a soft
/// halo round it. While a dictation listens it stays, turning slowly, and breathes with the voice (`level`); when an idea is sent it runs
/// once round the dock, fast, as the star leaves the arrow (`sendTurn`). The halo is thin and fades within a few points of the edge, clear
/// of the dock's words.
/// Reduce Motion: the light doesn't turn; it fades in and out. Decorative.
struct DockGlow: View {
    /// A dictation is listening.
    var isListening: Bool
    /// The voice's level, 0…1, while listening.
    var level: Double
    /// Goes up with each idea sent: each value runs the light round once.
    var sendTurn: Int

    /// One run round the dock for a sent idea, about the star's rise (`IdeaTransitionService.riseDuration`).
    private static let sendDuration: TimeInterval = 1.2
    /// One slow turn while listening.
    private static let listeningTurn: TimeInterval = 5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sentAt: Date?

    var body: some View {
        ZStack {
            if isListening || sentAt != nil {
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
        // Only a new send runs it: `onChange`, not a task keyed on the count, which would run again each time the dock comes back on screen
        // (back from the script's page) and light it for nothing.
        .onChange(of: sendTurn) {
            let started = Date.now
            sentAt = started
            Task {
                try? await Task.sleep(for: .seconds(Self.sendDuration))
                if sentAt == started { sentAt = nil }
            }
        }
    }

    /// Where the colours are round the rim, and how strong the light is now.
    private func light(at date: Date) -> (angle: Angle, strength: Double) {
        if let sentAt {
            let progress = min(1, date.timeIntervalSince(sentAt) / Self.sendDuration)
            // Up fast, a full turn eased out, gone as it ends.
            let strength = sin(.pi * pow(progress, 0.6))
            let turn = reduceMotion ? 0 : 360 * (1 - pow(1 - progress, 2.2))
            return (.degrees(turn - 90), strength)
        }
        let turn = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.listeningTurn) / Self.listeningTurn * 360
        return (.degrees(turn), 0.45 + 0.55 * min(1, max(0, level)))
    }

    /// The rim and its halo, laid out exactly on the dock (a bigger frame changed the dock's own size to the system). The halo is the
    /// same colours, blurred, which spills past the glass without taking room; it is thin, so inside it fades well before the words.
    private func rim(angle: Angle) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.dockRadius, style: .continuous)
        let colors = AngularGradient(colors: Palette.Scripts.dockGlow, center: .center, angle: angle)
        return ZStack {
            // Inside the edge (a stroke on it would reach past the dock's frame); the blur spreads it both ways without taking room.
            shape
                .strokeBorder(colors, lineWidth: 5)
                .blur(radius: 9)
                .opacity(0.85)
            shape
                .strokeBorder(colors, lineWidth: 1.5)
        }
    }
}
