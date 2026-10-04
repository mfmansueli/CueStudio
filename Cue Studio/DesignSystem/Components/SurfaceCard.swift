//
//  SurfaceCard.swift
//  Cue Studio
//

import SwiftUI

/// Rounded card on the surface color, the basic container of the app. In the light appearance it
/// has the hairline shadow of a white card.
struct SurfaceCard: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    var color: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(color)
            }
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
