//
//  TextEffectPlayback.swift
//  Cue Studio
//

import CoreImage
import Foundation

/// A text's effect as the compositor draws it (`FrameOverlay.effect`): what it is painted from, how long the text shows, and
/// whether it plays its own way in and out (not when a ready-made Motion moves the text instead, nor when it is still). Its
/// painting is found in (or put back into) the cache when a frame asks, so a long video doesn't hold every text's layers.
nonisolated struct TextEffectPlayback: @unchecked Sendable {
    let request: TextEffectRequest
    let length: TimeInterval
    let animates: Bool

    /// The drawing `time` seconds into the text.
    func image(at time: TimeInterval) -> CIImage? {
        guard let sprites = TextEffectCache.shared.sprites(for: request) else { return nil }
        guard animates else { return sprites.rest() }
        return TextEffectComposer.image(sprites, effect: request.effect, time: time, length: length)
    }
}
