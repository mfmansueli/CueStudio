//
//  CueStudioButtonStyle.swift
//  Cue Studio
//

import SwiftUI

/// Capsule buttons. Screens pick a variant through the static helpers (`.cuePrimary()`) and never
/// build the style by hand. One primary per screen.
struct CueStudioButtonStyle: ButtonStyle {
    enum Variant {
        /// Yellow, black label.
        case primary
        /// Neutral surface.
        case secondary
        /// Soft yellow, yellow label.
        case tinted
        /// Hairline border, no fill.
        case outline
        /// Liquid Glass, for buttons over the camera or video.
        case glass
        /// White, black label: a tool's main action next to the screen's yellow one.
        case light
        /// Red, white label: confirms something that removes.
        case destructive
        /// Soft red, red label: a small remove next to other choices.
        case destructiveTinted
    }

    enum Size {
        case compact, medium, regular, large

        var height: CGFloat {
            switch self {
            case .compact: Metrics.compactButtonHeight
            case .medium: Metrics.mediumButtonHeight
            case .regular: Metrics.buttonHeight
            case .large: Metrics.largeButtonHeight
            }
        }
    }

    var variant: Variant
    var size: Size = .regular
    /// Fills the available width. Compact inline buttons usually hug their label.
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, variant: variant, size: size, expands: expands)
    }

    private struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let variant: Variant
        let size: Size
        let expands: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = Capsule()
            configuration.label
                .font(size == .compact || size == .medium ? .subheadline.weight(.semibold) : .body.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, size == .compact || size == .medium ? 14 : 18)
                .frame(maxWidth: expands ? .infinity : nil, minHeight: size.height)
                .foregroundStyle(foreground)
                .background {
                    if variant != .glass { shape.fill(background) }
                }
                .overlay {
                    if variant == .outline { shape.strokeBorder(Palette.ink3, lineWidth: 1) }
                }
                .glassEffect(variant == .glass ? .regular.interactive() : .identity, in: shape)
                .contentShape(shape)
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }

        private var foreground: Color {
            switch variant {
            case .primary: Palette.accInk
            case .tinted: Palette.accText
            case .secondary, .outline, .glass, .destructive: Palette.ink
            case .light: Palette.bg
            case .destructiveTinted: Palette.dangerText
            }
        }

        private var background: Color {
            switch variant {
            case .primary: Palette.acc
            case .secondary: Palette.surface2
            case .tinted: Palette.accSoft
            case .outline, .glass: .clear
            case .light: Palette.ink
            case .destructive: Palette.dangerFill
            case .destructiveTinted: Palette.dangerSoft
            }
        }
    }
}

extension ButtonStyle where Self == CueStudioButtonStyle {
    static func cuePrimary(_ size: CueStudioButtonStyle.Size = .regular, expands: Bool = true) -> CueStudioButtonStyle {
        CueStudioButtonStyle(variant: .primary, size: size, expands: expands)
    }

    static func cueSecondary(_ size: CueStudioButtonStyle.Size = .regular, expands: Bool = true) -> CueStudioButtonStyle {
        CueStudioButtonStyle(variant: .secondary, size: size, expands: expands)
    }

    static func cueTinted(_ size: CueStudioButtonStyle.Size = .regular, expands: Bool = true) -> CueStudioButtonStyle {
        CueStudioButtonStyle(variant: .tinted, size: size, expands: expands)
    }

    static func cueOutline(_ size: CueStudioButtonStyle.Size = .regular, expands: Bool = true) -> CueStudioButtonStyle {
        CueStudioButtonStyle(variant: .outline, size: size, expands: expands)
    }

    static func cueGlass(_ size: CueStudioButtonStyle.Size = .regular, expands: Bool = true) -> CueStudioButtonStyle {
        CueStudioButtonStyle(variant: .glass, size: size, expands: expands)
    }

    static func cueLight(_ size: CueStudioButtonStyle.Size = .regular, expands: Bool = true) -> CueStudioButtonStyle {
        CueStudioButtonStyle(variant: .light, size: size, expands: expands)
    }

    static func cueDestructive(_ size: CueStudioButtonStyle.Size = .regular, expands: Bool = true) -> CueStudioButtonStyle {
        CueStudioButtonStyle(variant: .destructive, size: size, expands: expands)
    }

    static func cueDestructiveTinted(_ size: CueStudioButtonStyle.Size = .regular, expands: Bool = true) -> CueStudioButtonStyle {
        CueStudioButtonStyle(variant: .destructiveTinted, size: size, expands: expands)
    }
}
