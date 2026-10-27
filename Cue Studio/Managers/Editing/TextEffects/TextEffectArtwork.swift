//
//  TextEffectArtwork.swift
//  Cue Studio
//

import CoreGraphics

/// What a text effect's recipe paints once for a text (`TextEffectPainter`): its layers, one image per piece each, and the
/// pieces the composer adds as it plays: a band of light, a sparkle and where the sparkles show, the bands behind Headline's
/// lines and the room its words rise in.
nonisolated struct TextEffectArtwork: @unchecked Sendable {
    var layers: [TextEffectLayer] = []
    /// A band of light, upright and centered on the origin, that the composer turns and moves across the faces.
    var sweep: TextEffectSprite?
    /// A sparkle centered on the origin, `sparkleSize` pixels wide.
    var sparkle: TextEffectSprite?
    var sparkleSize: CGFloat = 1
    var sparkles: [TextEffectSparkle] = []
    /// Headline: each line's band as it rests, its color, and the room its words come in through.
    var bands: [CGRect] = []
    var bandColor: TextEffectInk = .white
    var clips: [CGRect] = []
    /// What its images weigh, for the cache.
    var bytes = 0
}
