//
//  LayoutDirection+Language.swift
//  Cue Studio
//

import SwiftUI

extension LayoutDirection {
    /// Right to left for Arabic, left to right for every other language Cue has.
    init(rightToLeft: Bool) {
        self = rightToLeft ? .rightToLeft : .leftToRight
    }
}

extension View {
    /// Time, video and camera geometry run left to right in every language: timelines, layer
    /// tracks, the filmstrip, the edit preview and the camera's safe zones never mirror in Arabic.
    func keepsLeftToRight() -> some View {
        environment(\.layoutDirection, .leftToRight)
    }

    /// A label's letter spacing, left out in a language whose letters join or stack (Arabic, Hindi, Thai): added space
    /// breaks their writing apart (`TextShaping`).
    func interfaceTracking(_ value: CGFloat) -> some View {
        modifier(InterfaceTracking(value: value))
    }
}

/// `interfaceTracking(_:)`.
private struct InterfaceTracking: ViewModifier {
    let value: CGFloat
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.tracking(TextShaping.allowsLetterSpacing(in: locale.language) ? value : 0)
    }
}
