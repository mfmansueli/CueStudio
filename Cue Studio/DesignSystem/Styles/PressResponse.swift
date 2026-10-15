//
//  PressResponse.swift
//  Cue Studio
//

import SwiftUI

/// How a solid button answers a finger: it sinks (`depth`, a scale) and darkens a touch at once, and springs back when the finger lifts
/// (`CueMotion.pressIn`, `pressRelease`). It never fades: a see-through button looks disabled, not pressed. Small buttons sink a little
/// more than big ones, so the movement is about the same in points. With Reduce Motion only the darkening is left. Liquid Glass buttons
/// don't use it: `.interactive()` glass answers the touch itself, and two answers at once fight.
struct PressResponse: ViewModifier {
    let isPressed: Bool
    var depth: CGFloat = PressResponse.regularDepth

    /// A 50 pt button sinks 3%, a 34 to 44 pt one 5%, an icon 6%, a card 1.5%.
    static let regularDepth: CGFloat = 0.97
    static let compactDepth: CGFloat = 0.95
    static let iconDepth: CGFloat = 0.94
    /// A card that is one button: 1.5%, a few points on a full-width card.
    static let cardDepth: CGFloat = 0.985
    /// How much darker a pressed button is (`brightness`).
    static let darkening = -0.08

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .brightness(isPressed ? Self.darkening : 0)
            .scaleEffect(isPressed && !reduceMotion ? depth : 1)
            .animation(isPressed ? CueMotion.pressIn : CueMotion.pressRelease, value: isPressed)
    }
}

extension View {
    /// The press of a solid button (`PressResponse`).
    func pressResponse(_ isPressed: Bool, depth: CGFloat = PressResponse.regularDepth) -> some View {
        modifier(PressResponse(isPressed: isPressed, depth: depth))
    }
}
