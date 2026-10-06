//
//  SkyBackground.swift
//  Cue Studio
//

import SwiftUI

/// The sky behind a browse screen (or a story, with its board's glow), from the creator's Starry sky setting. Every screen draws its own,
/// and they all read the app's clock (`StarfieldView`), so moving between tabs shows the same sky, never one starting over.
struct SkyBackground: ViewModifier {
    /// The night glow and the colour under it: nil is the browse screens', otherwise the one a board of the stories draws.
    var lights: [BgWash.Light]?
    var base: Color?

    func body(content: Content) -> some View {
        content.background { SkyBackdrop(lights: lights, base: base) }
    }
}

extension View {
    /// The night and its stars behind this screen. Only on browse screens: never over the camera, a
    /// take or the editor.
    func skyBackground() -> some View {
        modifier(SkyBackground())
    }

    /// The night and its stars with the glow of one board (`BgWash.sendOff`…), over `base`.
    func skyBackground(wash lights: [BgWash.Light], base: Color = Palette.bg) -> some View {
        modifier(SkyBackground(lights: lights, base: base))
    }
}
