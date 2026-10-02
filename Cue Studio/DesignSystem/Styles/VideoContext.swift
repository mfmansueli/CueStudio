//
//  VideoContext.swift
//  Cue Studio
//

import SwiftUI

/// The camera, the prompter, the take review and the editor are looked at while a video plays or
/// is about to be recorded, on black: they stay dark in any appearance, and the dynamic tokens
/// (`Palette.ink`, `Palette.surface`…) resolve to their dark values inside them. Apply it where a
/// full-screen cover for one of those screens is presented.
struct VideoContext: ViewModifier {
    func body(content: Content) -> some View {
        content.preferredColorScheme(.dark)
    }
}

extension View {
    func videoContext() -> some View {
        modifier(VideoContext())
    }
}
