//
//  GlassIconButton.swift
//  Cue Studio
//

import SwiftUI

extension View {
    /// A round icon button in the system's Liquid Glass (`.glass`), at the large size: the recorder's bars, over the camera or the words.
    func glassIconButton() -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
    }
}
