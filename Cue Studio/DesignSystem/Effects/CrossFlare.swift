//
//  CrossFlare.swift
//  Cue Studio
//

import SwiftUI

/// The cross of light of a phone-camera star: two thin lines whose ends fade to nothing, with a glow. The scene opens it and closes it with
/// `.motion(pose)` (the boards: ×0 → 1.15 → 0.2 and a turn of 45° → 0 → −20° in half a second).
struct CrossFlare: View {
    let length: CGFloat
    var color: Color = .white
    var thickness: CGFloat = 1.8
    /// The vertical line is shorter on the boards (0.7 of the horizontal).
    var verticalRatio: CGFloat = 0.7

    var body: some View {
        ZStack {
            line(length: length, vertical: false)
            line(length: length * verticalRatio, vertical: true)
        }
        .frame(width: length, height: length)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func line(length: CGFloat, vertical: Bool) -> some View {
        Capsule()
            .fill(LinearGradient(
                stops: [
                    .init(color: color.opacity(0), location: 0), .init(color: color.opacity(0.45), location: 0.3),
                    .init(color: color, location: 0.5), .init(color: color.opacity(0.45), location: 0.7), .init(color: color.opacity(0), location: 1),
                ],
                startPoint: vertical ? .top : .leading, endPoint: vertical ? .bottom : .trailing
            ))
            .frame(width: vertical ? thickness : length, height: vertical ? length : thickness)
            .shadow(color: color.opacity(0.8), radius: 6)
    }
}
