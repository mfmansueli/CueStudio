//
//  SurfaceCard.swift
//  Cue Studio
//

import SwiftUI

/// Rounded card on the surface color, the basic container of the app.
struct SurfaceCard: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    var color: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func surfaceCard(
        padding: CGFloat = 16,
        radius: CGFloat = Metrics.cardRadius,
        color: Color = Palette.surface
    ) -> some View {
        modifier(SurfaceCard(padding: padding, radius: radius, color: color))
    }
}
