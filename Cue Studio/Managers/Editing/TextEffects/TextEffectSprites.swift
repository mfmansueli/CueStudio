//
//  TextEffectSprites.swift
//  Cue Studio
//

import CoreGraphics
import CoreImage
import Foundation

/// A text's effect painted once (`TextEffectPainter`) and kept while it shows (`TextEffectCache`): its layout, the layers'
/// images and the pieces the composer adds, and the still drawing, flattened the first time it is asked for, that every
/// frame at rest shows. Drawing a frame only places these images (`TextEffectComposer`): nothing is laid out or painted
/// again while it plays.
nonisolated final class TextEffectSprites: @unchecked Sendable {
    let request: TextEffectRequest
    let layout: TextEffectLayout
    let artwork: TextEffectArtwork
    private let lock = NSLock()
    private var flattened: CIImage?

    private init(request: TextEffectRequest, layout: TextEffectLayout, artwork: TextEffectArtwork) {
        self.request = request
        self.layout = layout
        self.artwork = artwork
    }

    /// Lays out and paints `request`; nil when there is nothing to draw.
    static func make(_ request: TextEffectRequest) -> TextEffectSprites? {
        guard let layout = TextEffectLayout.make(
            request.string, maxWidth: request.maxWidth, padding: request.padding, room: request.room, byWords: request.byWords
        ) else { return nil }
        return make(request, layout: layout)
    }

    /// Paints `request` as `layout` laid it out.
    static func make(_ request: TextEffectRequest, layout: TextEffectLayout) -> TextEffectSprites? {
        TextEffectSprites(request: request, layout: layout, artwork: TextEffectPainter.artwork(layout, request))
    }

    /// What it weighs in memory: its images, and the still drawing once flattened.
    var bytes: Int {
        let size = layout.drawingSize
        return artwork.bytes + Int(size.width * size.height * 4)
    }

    /// The drawing at rest, flattened into one image the first time (the same drawing as the composed one, so the way in
    /// lands on it without a jump).
    func rest() -> CIImage {
        lock.lock()
        defer { lock.unlock() }
        if let flattened { return flattened }
        let state = TextEffectChoreography.state(request.effect, layout: layout, sparkles: artwork.sparkles, time: 0, length: 0)
        let composed = TextEffectComposer.compose(self, state: state)
        let extent = CGRect(origin: .zero, size: layout.drawingSize)
        let image = TextEffectComposer.context.createCGImage(
            composed, from: extent, format: .RGBA8, colorSpace: TextEffectPainter.colorSpace
        ).map { CIImage(cgImage: $0) } ?? composed
        flattened = image
        return image
    }
}
