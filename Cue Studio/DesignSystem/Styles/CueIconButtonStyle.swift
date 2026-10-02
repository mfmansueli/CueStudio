//
//  CueIconButtonStyle.swift
//  Cue Studio
//

import SwiftUI

/// Round icon buttons: camera toolbars, prompter controls, close buttons.
struct CueIconButtonStyle: ButtonStyle {
    enum Variant {
        /// Liquid Glass, for controls floating over the camera feed.
        case glass
        /// Translucent white, for controls inside a glass panel.
        case overlay
        /// Neutral surface, for controls inside sheets and cards.
        case surface
        /// Soft yellow with a yellow icon.
        case tinted
        /// Solid yellow with a black icon (an active toggle or the main play button).
        case accent
        /// White with a black icon: play in a tool panel, next to the screen's yellow action.
        case light
        /// Soft red with a red icon: delete, when there is something to delete.
        case danger
    }

    var variant: Variant
    var diameter: CGFloat = Metrics.hitTarget

    func makeBody(configuration: Configuration) -> some View {
        let shape = Circle()
        configuration.label
            .font(.system(size: diameter * 0.4, weight: .semibold))
            .frame(width: diameter, height: diameter)
            .foregroundStyle(foreground)
            .background {
                if variant != .glass { shape.fill(background) }
            }
            .glassEffect(variant == .glass ? .regular.interactive() : .identity, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            // Keeps the touch target at 44pt even for smaller visuals.
            .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
    }

    private var foreground: Color {
        switch variant {
        case .accent: Palette.accInk
        case .tinted: Palette.accText
        case .glass, .overlay, .surface: Palette.ink
        case .light: Palette.bg
        case .danger: Palette.dangerText
        }
    }

    private var background: Color {
        switch variant {
        case .glass: .clear
        case .overlay: Palette.overlayFill
        case .surface: Palette.surface2
        case .tinted: Palette.accSoft
        case .accent: Palette.acc
        case .light: Palette.ink
        case .danger: Palette.dangerSoft
        }
    }
}

extension ButtonStyle where Self == CueIconButtonStyle {
    static func cueIcon(_ variant: CueIconButtonStyle.Variant, diameter: CGFloat = Metrics.hitTarget) -> CueIconButtonStyle {
        CueIconButtonStyle(variant: variant, diameter: diameter)
    }
}
