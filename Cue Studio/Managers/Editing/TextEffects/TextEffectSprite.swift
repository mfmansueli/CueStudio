//
//  TextEffectSprite.swift
//  Cue Studio
//

import CoreGraphics
import Metal

/// One image a text effect painted (a piece's layer, a band of light, a sparkle), kept on the GPU, and the rect of the
/// drawing it covers (from the bottom left, y up) when nothing moves it.
nonisolated struct TextEffectSprite: @unchecked Sendable {
    let texture: MTLTexture
    let rect: CGRect
}
