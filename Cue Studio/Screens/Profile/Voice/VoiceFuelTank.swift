//
//  VoiceFuelTank.swift
//  Cue Studio
//

import SwiftUI

/// My Cue Voice's meter as a spaceship's fuel tank (9.3, the owner, 03/11/2026): when the page opens, and whenever what Cue knows grows, the
/// sky's spaceship (wider than the tube) runs along a glass tube pouring yellow plasma up to the level, then crouches, launches along an arc,
/// turns its nose to the screen and comes at whoever is looking until it passes the glass (`VoiceShipFlight`), all with one haptic pattern in
/// time (`HapticPatterns.voiceFuel`). With Reduce Motion the tube is simply full to its level, without the ship. Drawn by `VoiceFuelPainter`;
/// VoiceOver reads the meter's value (`VoiceMeter`).
struct VoiceFuelTank: View {
    let strength: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launch: Date?

    private var level: Double { Double(min(100, max(0, strength))) / 100 }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let elapsed = reduceMotion ? nil : launch.map { timeline.date.timeIntervalSince($0) } ?? 0
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                VoiceFuelPainter.drawTank(level: level, elapsed: elapsed, time: time, size: size, in: &context)
            }
            .frame(height: VoiceFuelPainter.tankHeight)
            // The ship pouring the plasma, wider than the tube, on its own lane over it.
            .overlay {
                if let elapsed, elapsed <= VoiceFuelPainter.runSeconds {
                    Canvas { context, size in
                        VoiceFuelPainter.drawRunShip(level: level, elapsed: elapsed, time: time, size: size, in: &context)
                    }
                    .frame(height: VoiceFuelPainter.shipLane)
                }
            }
            // The flight is drawn over the page, on a taller canvas that exists only while the ship is out of the tank.
            .overlay(alignment: .bottom) {
                if let elapsed, elapsed > VoiceFuelPainter.runSeconds, VoiceFuelPainter.isFlying(elapsed) {
                    Canvas { context, size in
                        VoiceFuelPainter.drawFlight(level: level, elapsed: elapsed, time: time, size: size, in: &context)
                    }
                    .frame(height: VoiceFuelPainter.flightHeight)
                    .padding(.horizontal, -VoiceFuelPainter.flightInset)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { takeOff() }
        // Only when Cue knows more: clearing the answers just empties the tank.
        .onChange(of: strength) { old, new in
            if new > old { takeOff() }
        }
    }

    private func takeOff() {
        guard !reduceMotion else { return }
        launch = .now
        HapticPatterns.playVoiceFuel()
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 40) {
        VoiceFuelTank(strength: 65)
        VoiceFuelTank(strength: 20)
    }
    .padding()
    .background(Palette.surface2)
}
#endif
