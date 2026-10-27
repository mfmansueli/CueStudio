//
//  TextEffectCache.swift
//  Cue Studio
//

import Foundation

/// The texts' effects painted lately (`TextEffectSprites`), kept within a memory budget: playback asks for the same text on
/// every frame it shows, a long video's other texts are painted again when they come back (the same, being drawn from their
/// words alone), and memory stays bounded however many effects a video has.
nonisolated final class TextEffectCache: @unchecked Sendable {
    static let shared = TextEffectCache()

    private let cache: NSCache<NSString, TextEffectSprites> = {
        let cache = NSCache<NSString, TextEffectSprites>()
        cache.totalCostLimit = 96 * 1024 * 1024
        cache.countLimit = 32
        return cache
    }()

    /// Laid out but not painted: what the editor and the overlays measure, cheap enough for every change.
    private let layouts: NSCache<NSString, TextEffectLayoutBox> = {
        let cache = NSCache<NSString, TextEffectLayoutBox>()
        cache.countLimit = 96
        return cache
    }()

    /// `request` painted: kept from before, or painted now.
    func sprites(for request: TextEffectRequest) -> TextEffectSprites? {
        let key = request.key as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let layout = layout(for: request), let sprites = TextEffectSprites.make(request, layout: layout) else { return nil }
        cache.setObject(sprites, forKey: key, cost: sprites.bytes)
        return sprites
    }

    /// `request` laid out: its box, its room and its pieces.
    func layout(for request: TextEffectRequest) -> TextEffectLayout? {
        let key = request.key as NSString
        if let cached = cache.object(forKey: key) { return cached.layout }
        if let cached = layouts.object(forKey: key) { return cached.layout }
        guard let layout = TextEffectLayout.make(
            request.string, maxWidth: request.maxWidth, padding: request.padding, room: request.room, byWords: request.byWords
        ) else { return nil }
        layouts.setObject(TextEffectLayoutBox(layout), forKey: key)
        return layout
    }

    func removeAll() {
        cache.removeAllObjects()
        layouts.removeAllObjects()
    }
}
