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
}
