//
//  OnboardingPrimaryButton.swift
//  Cue Studio
//

import SwiftUI

/// The yellow pill of the first flight: 54 pt, black text, a shine now and then.
struct OnboardingPrimaryButton: View {
    let title: String
    /// What the button says while it cannot be used ("Pick a topic", "Choose a galaxy"); nil keeps `title`.
    var disabledTitle: String?
    /// How it looks then: the yellow pill dimmed to 20% with white text (the default), or a grey one.
    var disabledStyle = DisabledStyle.dimmed
    var isEnabled = true
    var shines = false
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(!isEnabled ? disabledTitle ?? title : title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isGrey ? Palette.ink3 : isDimmed && disabledTitle != nil ? Palette.Flight.quietInk : Palette.accInk)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(isGrey ? Palette.fill : Palette.acc.opacity(isDimmed ? 0.2 : 1), in: Capsule())
                .modifier(OptionalShine(shines: shines && isEnabled))
                .opacity(isDimmed && disabledTitle == nil ? 0.4 : 1)
        }
        .buttonStyle(PillButtonStyle())
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }

    /// The system dims a disabled button; this one draws its own disabled look (`disabledStyle`) and leaves the label as it is.
    private struct PillButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.pressResponse(configuration.isPressed)
        }
    }

    enum DisabledStyle { case dimmed, grey }

    private var isGrey: Bool { !isEnabled && disabledStyle == .grey }
    private var isDimmed: Bool { !isEnabled && disabledStyle == .dimmed }

    private struct OptionalShine: ViewModifier {
        let shines: Bool
        func body(content: Content) -> some View {
            if shines { content.shineSweep(interval: 5) } else { content }
        }
    }
}
