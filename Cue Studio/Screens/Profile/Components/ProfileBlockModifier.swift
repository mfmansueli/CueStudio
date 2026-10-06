//
//  ProfileBlockModifier.swift
//  Cue Studio
//

import SwiftUI

extension View {
    /// A Profile block: `surface`, 22 pt radius and the faint violet edge.
    func profileBlock() -> some View {
        profileBlock(glow: Color.clear)
    }

    /// The same block with a soft light behind its content (a radial gradient from one corner).
    func profileBlock(glow: some ShapeStyle) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.profileBlockRadius, style: .continuous)
        return background {
            ZStack {
                Palette.surface
                Rectangle().fill(glow)
            }
            .clipShape(shape)
        }
        .overlay(shape.strokeBorder(Palette.glassBorder.opacity(0.7), lineWidth: 0.5))
    }
}
