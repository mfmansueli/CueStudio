//
//  HeroDiscCache.swift
//  Cue Studio
//

import SwiftUI

/// The creator's galaxy disc (1.4 thousand stars and four blurred strokes of gas and light) drawn once into an image: the disc only turns
/// (once in 140 s), so each frame turns the picture instead of drawing the sky again. 360 pt across at 3× so it stays sharp at full size,
/// when the opening of 1.3 pulls the camera back from it.
@MainActor
enum HeroDiscCache {
    private static var cached: UIImage?

    /// The picture; made the first time it is asked for (call `prewarm()` earlier to make that moment a quiet one).
    static var image: UIImage? {
        if cached == nil, let hero = GalaxyLibrary.art?.hero { cached = render(hero) }
        return cached
    }

    static func prewarm() { _ = image }

    private static func render(_ hero: GalaxyArt.Hero) -> UIImage? {
        let content = Canvas { context, _ in
            var centred = context
            centred.translateBy(x: 180, y: 180)
            GalaxyPainter.drawHeroDisc(hero, in: &centred)
        }
        .frame(width: 360, height: 360)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        return renderer.uiImage
    }
}
