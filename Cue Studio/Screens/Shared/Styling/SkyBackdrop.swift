//
//  SkyBackdrop.swift
//  Cue Studio
//

import SwiftUI

/// The night and its stars, from the creator's Starry sky setting: the glow (`BgWash`) and the stars (`StarfieldView`), as `skyBackground()`
/// draws them behind a screen.
struct SkyBackdrop: View {
    /// The night glow and the colour under it: nil is the browse screens' (`BgWash.navigation` over `bg`, or the interstellar night at
    /// Interstellar), otherwise the one a board of the stories draws.
    var lights: [BgWash.Light]?
    var base: Color?

    @Environment(PersonalizationService.self) private var personalization

    var body: some View {
        let sky = personalization.sky
        ZStack {
            // The night glow (v29): a violet light from the top left, the same on every browse screen, sky on or off.
            BgWash(lights: lights ?? BgWash.browse(sky), base: base ?? BgWash.browseBase(sky))
            StarfieldView(density: sky)
        }
        .ignoresSafeArea()
    }
}
