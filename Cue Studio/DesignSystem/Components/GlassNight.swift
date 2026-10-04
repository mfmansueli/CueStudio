//
//  GlassNight.swift
//  Cue Studio
//

import SwiftUI

/// The surface of bars and floating controls in v26: night glass with a 0.5 pt rim (violet in dark,
/// gray in light). Over video it is thinner (`Density`); in the light appearance it is always the
/// 94% white of `Palette.glassFill`.
struct GlassNight<S: InsettableShape>: ViewModifier {
    /// How much of the video shows through: 60%, 72% or 88% of night glass in dark.
    enum Density {
        case thin, regular, solid

        var darkOpacity: Double {
            switch self {
            case .thin: 0.6
            case .regular: 0.72
            case .solid: 0.88
            }
        }
    }

    var shape: S
    var density: Density = .regular

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
    }

    private var fill: Color {
        colorScheme == .dark && density != .regular ? Palette.glassBase.opacity(density.darkOpacity) : Palette.glassFill
    }
}

extension View {
    /// Night glass behind a bar or a floating control, in `shape` (a capsule by default).
    func glassNight<S: InsettableShape>(in shape: S, density: GlassNight<S>.Density = .regular) -> some View {
        modifier(GlassNight(shape: shape, density: density))
    }

    func glassNight(density: GlassNight<Capsule>.Density = .regular) -> some View {
        glassNight(in: Capsule(), density: density)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        Text("Thin").padding().glassNight(density: .thin)
        Text("Regular").padding().glassNight()
        Text("Solid").padding(20).glassNight(in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous), density: .solid)
    }
    .foregroundStyle(Palette.ink)
    .padding(40)
    .background(LinearGradient(colors: [.orange, .purple], startPoint: .top, endPoint: .bottom))
}
#endif
