//
//  CuePressButtonStyle.swift
//  Cue Studio
//

import SwiftUI

/// For a button that draws itself (a chip, a card): the label as it is, with the press of the solid buttons (`PressResponse`) in place of
/// `.plain`'s fade. A chip sinks like a compact button; a card only 1.5%, since on a 300 pt card more would be a lurch, not an answer.
/// Disabled, it dims as the capsule buttons do.
struct CuePressButtonStyle: ButtonStyle {
    var depth: CGFloat = PressResponse.compactDepth

    func makeBody(configuration: Configuration) -> some View {
        PressedLabel(configuration: configuration, depth: depth)
    }

    private struct PressedLabel: View {
        let configuration: ButtonStyleConfiguration
        let depth: CGFloat
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .pressResponse(configuration.isPressed, depth: depth)
                .opacity(isEnabled ? 1 : 0.4)
        }
    }
}

extension ButtonStyle where Self == CuePressButtonStyle {
    /// A chip or a small tile.
    static var cuePress: CuePressButtonStyle { CuePressButtonStyle() }
    /// A card that is one button.
    static var cuePressCard: CuePressButtonStyle { CuePressButtonStyle(depth: PressResponse.cardDepth) }
}
